import 'work_type.dart';

/// Enough of a machine to name it in a list.
class AssetBrief {
  const AssetBrief({
    required this.id,
    this.equipment,
    this.serial,
    this.hospital,
  });

  final int id;
  final String? equipment;
  final String? serial;
  final String? hospital;
}

enum WorkOrderQueueState { waiting, setAside }

/// One row of the Worklist — a synced captured work order, or a job still on
/// the phone.
class WorkOrderSummary {
  const WorkOrderSummary({
    this.trackId,
    this.mobileId,
    this.dateIn,
    this.assetId,
    this.asset,
    this.workType,
    required this.status,
    this.queueState,
    this.message,
  });

  /// The server's number. Null until the server has it.
  final int? trackId;
  final String? mobileId;
  final DateTime? dateIn;
  final int? assetId;
  final AssetBrief? asset;
  final WorkType? workType;
  final String status;

  /// Null for a synced work order.
  final WorkOrderQueueState? queueState;

  /// The server's refusal, for a job set aside.
  final String? message;

  WorkOrderSummary withAsset(AssetBrief? a) => WorkOrderSummary(
    trackId: trackId,
    mobileId: mobileId,
    dateIn: dateIn,
    assetId: assetId,
    asset: a,
    workType: workType,
    status: status,
    queueState: queueState,
    message: message,
  );
}

/// Jobs on the phone first — they are the newest and the ones that may need
/// the technician — then the synced ones. A queued job whose mobile id has
/// already come back through sync is dropped: the synced row is the truth.
List<WorkOrderSummary> mergeWorklist({
  required List<WorkOrderSummary> queued,
  required List<WorkOrderSummary> synced,
}) {
  final arrived = {for (final s in synced) ?s.mobileId};
  return [
    for (final q in queued)
      if (!arrived.contains(q.mobileId)) q,
    ...synced,
  ];
}
