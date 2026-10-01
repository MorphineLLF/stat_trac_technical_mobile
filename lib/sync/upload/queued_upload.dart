import 'certificate_upload.dart';
import 'sync_upload_batch.dart';

/// Something that waits in the outbox and becomes exactly one batch.
///
/// Certificates were the only kind until work orders. The queue, the archive
/// and the worker speak this, and only the code that needs a kind's details
/// looks past it.
abstract interface class QueuedUpload {
  /// Stored in the payload so the queue can restore the right class.
  String get kind;

  /// The uuid the server names this work by in `assigned`.
  String get mobileId;

  /// The outbox key. Usually [mobileId].
  String get queueKey;

  Map<String, Object?> toJson();

  SyncUploadBatch toBatch();
}

/// Restores a queued payload.
///
/// **No kind means certificate**: every row queued before work orders existed
/// was one, and they are still on technicians' phones.
QueuedUpload fromQueuedJson(Map<String, Object?> j) => switch (j['kind']) {
  null || CertificateUpload.kindName => CertificateUpload.fromJson(j),
  final other => throw FormatException('Unknown queued upload kind: $other'),
};
