import 'queued_upload.dart';
import 'sync_upload_batch.dart';

/// A work order captured on site, waiting to reach the server.
///
/// Becomes exactly one batch — capture, the technician's signature, the
/// client's — and a batch is all or nothing, so a job never lands without its
/// signatures or the signatures without a job.
///
/// [capture] is held already in wire shape (`WorkOrderJob.toWire`). The batch
/// is rebuilt from it at every send, and must come out identical each time: a
/// resend after a lost reply is recognised by the server only if it is the
/// same work under the same mobile id.
class WorkOrderUpload implements QueuedUpload {
  WorkOrderUpload({
    required this.mobileId,
    required this.capture,
    required this.techPng,
    required this.clientPng,
    required this.clientName,
  }) {
    // Both signatures are required for a captured job (the user's rule,
    // 2026-10-01). Checked here as well as on the screen, so nothing can queue
    // a job the server would take without them.
    if (techPng.isEmpty) {
      throw ArgumentError.value(techPng, 'techPng', 'the technician must sign');
    }
    if (clientPng.isEmpty) {
      throw ArgumentError.value(clientPng, 'clientPng', 'the client must sign');
    }
    if (clientName.trim().isEmpty) {
      throw ArgumentError.value(
        clientName,
        'clientName',
        'a client signature must name the person who gave it',
      );
    }
  }

  static const kindName = 'work_order';

  @override
  String get kind => kindName;

  @override
  final String mobileId;

  /// One job per row, so the job's own id is the key.
  @override
  String get queueKey => mobileId;

  final Map<String, Object?> capture;

  /// Standard, padded base64 of each pad's PNG.
  final String techPng;
  final String clientPng;
  final String clientName;

  factory WorkOrderUpload.fromJson(Map<String, Object?> j) => WorkOrderUpload(
    mobileId: j['mobile_id']! as String,
    capture: Map<String, Object?>.from(j['capture']! as Map),
    techPng: j['tech_png']! as String,
    clientPng: j['client_png']! as String,
    clientName: j['client_name']! as String,
  );

  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'mobile_id': mobileId,
    'capture': capture,
    'tech_png': techPng,
    'client_png': clientPng,
    'client_name': clientName,
  };

  @override
  SyncUploadBatch toBatch() => SyncUploadBatch([
    SyncUploadOp.capture(mobileId: mobileId, data: capture),
    SyncUploadOp.sign(
      table: 'Repair',
      mobileId: mobileId,
      which: SignatureSide.tech,
      png: techPng,
    ),
    SyncUploadOp.sign(
      table: 'Repair',
      mobileId: mobileId,
      which: SignatureSide.client,
      png: clientPng,
      clientName: clientName,
    ),
  ]);
}
