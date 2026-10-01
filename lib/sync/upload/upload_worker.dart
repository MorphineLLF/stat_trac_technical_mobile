import 'package:flutter/foundation.dart';

import 'certificate_upload.dart';
import 'sync_upload_archive_note.dart';
import 'sync_upload_client.dart';
import 'sync_upload_result.dart';
import 'upload_archive.dart';
import 'upload_queue.dart';

/// What one drain did, for the status UI.
class UploadRunResult {
  const UploadRunResult({
    required this.attempted,
    required this.applied,
    required this.conflicted,
    required this.rejected,
    required this.failed,
    required this.stoppedForSignal,
    this.stoppedForAuth = false,
    this.shortApplied = 0,
    this.unguaranteed = 0,
  });

  final int attempted;
  final int applied;
  final int conflicted;
  final int rejected;
  final int failed;

  /// Certificates the server accepted while applying fewer row ops than were
  /// sent — the certificate landed without all of its readings.
  ///
  /// Counted separately from [failed] because the server said 200 and meant
  /// it: nothing here is a transport problem or a refusal, and retrying would
  /// not change the answer. It is counted at all because the alternative is
  /// what happened before — a partial write reported as a clean success.
  final int shortApplied;

  /// Certificates sent to a server that would not promise a reading must name
  /// its certificate.
  ///
  /// Separate from every other count because the upload *succeeded* — the
  /// server said 200 and meant it. What is missing is the guarantee that the
  /// readings landed attached to the certificate rather than to nothing, and
  /// that is not a thing a technician can be left to discover later.
  final int unguaranteed;

  /// The run ended early because the server could not be reached. Not a
  /// failure — the work is still queued and will go when there is signal.
  final bool stoppedForSignal;

  /// The run ended early because the device token is dead.
  ///
  /// Kept apart from [stoppedForSignal] because the two need opposite things
  /// from the technician: signal comes back on its own and asks for nothing,
  /// while this waits for a sign-in that nobody will perform if the app says
  /// it is out of signal. Reporting this as a network problem is how a device
  /// stops uploading for a fortnight without anyone knowing.
  final bool stoppedForAuth;
}

/// Drains the outbox.
///
/// Sends one certificate at a time rather than one large batch: a batch is
/// all-or-nothing server-side, so combining two certificates would mean one
/// technician's bad reading holding another's finished work hostage.
class UploadWorker {
  UploadWorker({
    required UploadQueue queue,
    required UploadArchive archive,
    required SyncUploadClient client,
    required Future<bool> Function(String mobileId, int serverId) confirm,
    required Future<String?> Function() company,
    required Future<String?> Function() deviceToken,
  }) : _queue = queue,
       _archive = archive,
       _client = client,
       _confirm = confirm,
       _company = company,
       _deviceToken = deviceToken;

  final UploadQueue _queue;
  final UploadArchive _archive;
  final SyncUploadClient _client;

  /// Records the server's key against the certificate's mobile id.
  ///
  /// The server answers with `assigned`, which names the certificate by the
  /// UUID it travelled under and by nothing else. Without writing that back
  /// the device can never say whether its own work landed — which is what
  /// left a deleted queue row unrecoverable and a technician with no answer.
  final Future<bool> Function(String mobileId, int serverId) _confirm;
  final Future<String?> Function() _company;
  final Future<String?> Function() _deviceToken;

  /// The run in progress, shared by every worker in the app.
  ///
  /// Static because the provider can hand out more than one worker, and the
  /// queue they drain is the same table. Two runs at once each read the same
  /// pending rows and each sent them: on a phone the automatic send and the
  /// Sync button overlapped and a certificate's signatures went up twice. For
  /// readings that is worse — the second batch is refused already_issued and
  /// parks work that had in fact landed.
  static Future<UploadRunResult>? _running;

  /// Sends what is waiting. A call while a run is already going joins that
  /// run and gets its result, rather than sending the same rows again.
  Future<UploadRunResult> drain() {
    return _running ??= _drain().whenComplete(() => _running = null);
  }

  Future<UploadRunResult> _drain() async {
    final pending = await _queue.pending();
    if (pending.isEmpty) return _empty;

    // Signed out. The work stays queued — it belongs to the technician, not
    // to the session.
    final company = await _company();
    final token = await _deviceToken();
    if (company == null || token == null || company.isEmpty || token.isEmpty) {
      return _empty;
    }

    var attempted = 0, applied = 0, conflicted = 0, rejected = 0, failed = 0;
    var shortApplied = 0, unguaranteed = 0;

    for (final entry in pending) {
      final upload = entry.upload;
      final cert = upload is CertificateUpload ? upload : null;
      attempted++;
      final result = await _client.upload(
        company: company,
        deviceToken: token,
        upload: upload,
      );

      switch (result) {
        case UploadApplied(applied: final rowsApplied, :final assigned):
          // Checked before anything is called a success. A server that will
          // not promise this may have written the readings attached to
          // nothing, and a 200 looks identical either way.
          if (cert != null &&
              cert.lines.isNotEmpty &&
              !result.guaranteesCertRef) {
            unguaranteed++;
            debugPrint(
              noGuaranteeNote(
                mobileId: upload.mobileId,
                enforces: result.enforces,
              ),
            );
          }
          // Archived BEFORE the queue row goes. Deleting first is what left
          // the last lost certificate with no record of what was sent.
          await _archive.record(
            upload: upload,
            applied: rowsApplied,
            assigned: assigned,
          );
          final serverId = assigned[upload.mobileId];
          // Certificates only: the local certificate table is what this
          // writes to. A work order's number arrives with its synced row.
          if (cert != null && serverId != null) {
            await _confirm(upload.mobileId, serverId);
          }
          if (cert != null && rowsApplied < cert.rowOpCount) {
            shortApplied++;
            debugPrint(
              shortApplyNote(
                mobileId: upload.mobileId,
                opsSent: cert.rowOpCount,
                lines: cert.lines.length,
                applied: rowsApplied,
              ),
            );
          }
          await _queue.markApplied(upload.queueKey);
          applied++;

        case UploadConflict(:final conflicts):
          await _queue.markConflicted(
            upload.queueKey,
            _describeConflict(conflicts),
          );
          conflicted++;

        case UploadRejected(:final rejections):
          final r = rejections.isEmpty ? null : rejections.first;
          final reason = r?.reason ?? UploadRejectionReason.invalid;

          // Already signed, or already issued, means the certificate has what
          // the technician was trying to give it. Holding the row and calling
          // it a rejection would teach them to ignore the queue.
          //
          // **But only when nothing was lost with it.** A rejection refuses
          // the WHOLE batch, so an already_issued on a batch that was also
          // carrying the certificate and its readings means none of them
          // landed. Treating that as benign deletes the queue row, marks the
          // work applied, and reports a refusal as done — which is exactly
          // how a certificate reached the server with no readings and nobody
          // was told. The reason code describes the certificate; the batch
          // describes what would be thrown away by believing it.
          // Anything that is not a certificate carries a whole job.
          final carriesWork =
              cert == null ||
              cert.lines.isNotEmpty ||
              cert.certificate.isNotEmpty;

          if (UploadRejectionReason.isBenign(reason) && !carriesWork) {
            await _archive.record(
              upload: upload,
              applied: 0,
              assigned: const {},
            );
            await _queue.markApplied(upload.queueKey);
            applied++;
            break;
          }

          await _queue.markRejected(
            upload.queueKey,
            reason: reason,
            message: r?.message ?? 'The server refused this certificate.',
          );
          rejected++;

        case UploadClientError(:final message):
          await _queue.markFailed(upload.queueKey, message);
          failed++;

        // Parked, not retried: the same batch gets the same 413 for ever.
        // The run continues — a batch that is too big says nothing about the
        // certificates behind it, and one fat certificate must not hold up a
        // technician's whole day. Splitting is not yet automatic, so this is
        // where such a certificate stops until it is.
        case UploadTooLarge(:final message):
          await _queue.markFailed(upload.queueKey, message);
          failed++;

        // Kept pending rather than failed: the certificate is not at fault
        // and goes up once somebody signs in. But every batch behind it
        // carries the same dead token, so the run ends here — and it ends
        // saying so, rather than claiming there is no signal.
        case UploadAuthExpired(:final message):
          await _queue.markRetryable(upload.queueKey, message);
          return UploadRunResult(
            attempted: attempted,
            applied: applied,
            conflicted: conflicted,
            rejected: rejected,
            failed: failed,
            shortApplied: shortApplied,
            unguaranteed: unguaranteed,
            stoppedForSignal: false,
            stoppedForAuth: true,
          );

        case UploadTransportError(:final message):
          await _queue.markRetryable(upload.queueKey, message);
          // Stop the run. Signal does not usually return between two
          // certificates, and sending the rest would fail identically while
          // spending a technician's battery.
          return UploadRunResult(
            attempted: attempted,
            applied: applied,
            conflicted: conflicted,
            rejected: rejected,
            failed: failed,
            shortApplied: shortApplied,
            unguaranteed: unguaranteed,
            stoppedForSignal: true,
          );
      }
    }

    return UploadRunResult(
      attempted: attempted,
      applied: applied,
      conflicted: conflicted,
      rejected: rejected,
      failed: failed,
      shortApplied: shortApplied,
      unguaranteed: unguaranteed,
      stoppedForSignal: false,
    );
  }

  /// A one-line summary for the queue row. The full field-by-field comparison
  /// stays in the response and belongs on the conflict screen — this is only
  /// enough to tell a technician which certificate needs them.
  static String _describeConflict(List<UploadRowConflict> conflicts) {
    final fields = <String>{
      for (final c in conflicts)
        for (final f in c.differingFields) f.field,
    };
    if (fields.isEmpty) return 'This record changed on the server.';
    return 'Changed on the server: ${fields.join(', ')}';
  }

  static const _empty = UploadRunResult(
    attempted: 0,
    applied: 0,
    conflicted: 0,
    rejected: 0,
    failed: 0,
    stoppedForSignal: false,
  );
}

/// Convenience for the caller that has a finished certificate in hand.
extension QueueCertificate on UploadQueue {
  Future<void> queueCertificate(CertificateUpload upload) => enqueue(upload);
}
