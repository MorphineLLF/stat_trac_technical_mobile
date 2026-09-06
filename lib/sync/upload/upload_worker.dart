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

  Future<UploadRunResult> drain() async {
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
      attempted++;
      final result = await _client.upload(
        company: company,
        deviceToken: token,
        upload: entry.upload,
      );

      switch (result) {
        case UploadApplied(applied: final rowsApplied, :final assigned):
          // Checked before anything is called a success. A server that will
          // not promise this may have written the readings attached to
          // nothing, and a 200 looks identical either way.
          if (entry.upload.lines.isNotEmpty && !result.guaranteesCertRef) {
            unguaranteed++;
            debugPrint(
              noGuaranteeNote(
                mobileId: entry.upload.mobileId,
                enforces: result.enforces,
              ),
            );
          }
          // Archived BEFORE the queue row goes. Deleting first is what left
          // the last lost certificate with no record of what was sent.
          await _archive.record(
            upload: entry.upload,
            applied: rowsApplied,
            assigned: assigned,
          );
          final serverId = assigned[entry.upload.mobileId];
          if (serverId != null) {
            await _confirm(entry.upload.mobileId, serverId);
          }
          if (rowsApplied < entry.upload.rowOpCount) {
            shortApplied++;
            debugPrint(
              shortApplyNote(
                mobileId: entry.upload.mobileId,
                opsSent: entry.upload.rowOpCount,
                lines: entry.upload.lines.length,
                applied: rowsApplied,
              ),
            );
          }
          await _queue.markApplied(entry.upload.queueKey);
          applied++;

        case UploadConflict(:final conflicts):
          await _queue.markConflicted(
            entry.upload.queueKey,
            _describeConflict(conflicts),
          );
          conflicted++;

        case UploadRejected(:final rejections):
          final r = rejections.isEmpty ? null : rejections.first;
          final reason = r?.reason ?? UploadRejectionReason.invalid;

          // Already signed, or already issued, means the certificate has what
          // the technician was trying to give it. Holding the row and calling
          // it a rejection would teach them to ignore the queue.
          if (UploadRejectionReason.isBenign(reason)) {
            await _archive.record(
              upload: entry.upload,
              applied: 0,
              assigned: const {},
            );
            await _queue.markApplied(entry.upload.queueKey);
            applied++;
            break;
          }

          await _queue.markRejected(
            entry.upload.queueKey,
            reason: reason,
            message: r?.message ?? 'The server refused this certificate.',
          );
          rejected++;

        case UploadClientError(:final message):
          await _queue.markFailed(entry.upload.queueKey, message);
          failed++;

        // Parked, not retried: the same batch gets the same 413 for ever.
        // The run continues — a batch that is too big says nothing about the
        // certificates behind it, and one fat certificate must not hold up a
        // technician's whole day. Splitting is not yet automatic, so this is
        // where such a certificate stops until it is.
        case UploadTooLarge(:final message):
          await _queue.markFailed(entry.upload.queueKey, message);
          failed++;

        // Kept pending rather than failed: the certificate is not at fault
        // and goes up once somebody signs in. But every batch behind it
        // carries the same dead token, so the run ends here — and it ends
        // saying so, rather than claiming there is no signal.
        case UploadAuthExpired(:final message):
          await _queue.markRetryable(entry.upload.queueKey, message);
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
          await _queue.markRetryable(entry.upload.queueKey, message);
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
