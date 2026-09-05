import 'certificate_upload.dart';
import 'sync_upload_client.dart';
import 'sync_upload_result.dart';
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
  });

  final int attempted;
  final int applied;
  final int conflicted;
  final int rejected;
  final int failed;

  /// The run ended early because the server could not be reached. Not a
  /// failure — the work is still queued and will go when there is signal.
  final bool stoppedForSignal;
}

/// Drains the outbox.
///
/// Sends one certificate at a time rather than one large batch: a batch is
/// all-or-nothing server-side, so combining two certificates would mean one
/// technician's bad reading holding another's finished work hostage.
class UploadWorker {
  UploadWorker({
    required UploadQueue queue,
    required SyncUploadClient client,
    required Future<String?> Function() company,
    required Future<String?> Function() deviceToken,
  }) : _queue = queue,
       _client = client,
       _company = company,
       _deviceToken = deviceToken;

  final UploadQueue _queue;
  final SyncUploadClient _client;
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

    for (final entry in pending) {
      attempted++;
      final result = await _client.upload(
        company: company,
        deviceToken: token,
        upload: entry.upload,
      );

      switch (result) {
        case UploadApplied():
          await _queue.markApplied(entry.upload.mobileId);
          applied++;

        case UploadConflict(:final conflicts):
          await _queue.markConflicted(
            entry.upload.mobileId,
            _describeConflict(conflicts),
          );
          conflicted++;

        case UploadRejected(:final rejections):
          final r = rejections.isEmpty ? null : rejections.first;
          await _queue.markRejected(
            entry.upload.mobileId,
            reason: r?.reason ?? 'invalid',
            message: r?.message ?? 'The server refused this certificate.',
          );
          rejected++;

        case UploadClientError(:final message):
          await _queue.markFailed(entry.upload.mobileId, message);
          failed++;

        case UploadTransportError(:final message):
          await _queue.markRetryable(entry.upload.mobileId, message);
          // Stop the run. Signal does not usually return between two
          // certificates, and sending the rest would fail identically while
          // spending a technician's battery.
          return UploadRunResult(
            attempted: attempted,
            applied: applied,
            conflicted: conflicted,
            rejected: rejected,
            failed: failed,
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
