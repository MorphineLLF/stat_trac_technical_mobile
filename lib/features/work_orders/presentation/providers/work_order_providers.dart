import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../sync/powersync_providers.dart';
import '../../../../sync/upload/upload_providers.dart';
import '../../../../sync/upload/upload_queue.dart';
import '../../../../sync/upload/work_order_upload.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/auth_state.dart';
import '../../data/powersync_work_order_data_source.dart';
import '../../domain/work_order_job.dart';
import '../../domain/work_order_record.dart';
import '../../domain/work_order_summary.dart';

part 'work_order_providers.g.dart';

@riverpod
Future<PowerSyncWorkOrderDataSource> workOrderSource(Ref ref) async =>
    PowerSyncWorkOrderDataSource.of(await ref.watch(syncDatabaseProvider.future));

class Worklist {
  const Worklist(this.items, {required this.syncedComplete});

  final List<WorkOrderSummary> items;

  /// False when the synced part could not be read — the screen says so.
  final bool syncedComplete;
}

/// The signed-in technician's captured work orders: still on the phone first,
/// then synced.
@riverpod
Future<Worklist> worklist(Ref ref) async {
  final auth = ref.watch(authProvider);
  if (auth is! AuthAuthenticated) return const Worklist([], syncedComplete: true);

  final queueFuture = ref.watch(uploadQueueProvider.future);
  final source = await ref.watch(workOrderSourceProvider.future);
  final queue = await queueFuture;

  final entries = [
    for (final e in await queue.all())
      if (e.upload is WorkOrderUpload) e,
  ];
  final jobs = [
    for (final e in entries)
      WorkOrderJob.fromWire((e.upload as WorkOrderUpload).capture),
  ];
  final assets = await source.assetsByIds({for (final j in jobs) j.assetId});

  final queued = [
    for (var i = 0; i < entries.length; i++)
      WorkOrderSummary(
        mobileId: entries[i].upload.mobileId,
        dateIn: jobs[i].started,
        assetId: jobs[i].assetId,
        asset: assets[jobs[i].assetId],
        workType: jobs[i].workType,
        status: entries[i].status == UploadStatus.pending
            ? 'Waiting to sync'
            : 'Set aside',
        queueState: entries[i].status == UploadStatus.pending
            ? WorkOrderQueueState.waiting
            : WorkOrderQueueState.setAside,
        message: entries[i].lastError,
      ),
  ];

  final synced = await source.capturedBy(auth.user.id);
  return Worklist(
    mergeWorklist(queued: queued, synced: synced.items),
    syncedComplete: synced.complete,
  );
}

@riverpod
Future<int?> openRepairOnAsset(Ref ref, int assetId) async =>
    (await ref.watch(workOrderSourceProvider.future)).openRepairOn(assetId);

@riverpod
Future<WorkOrderRecord?> workOrderRecord(Ref ref, int trackId) async =>
    (await ref.watch(workOrderSourceProvider.future)).record(trackId);

@riverpod
Future<UploadQueueEntry?> queuedWorkOrder(Ref ref, String mobileId) async {
  final queue = await ref.watch(uploadQueueProvider.future);
  for (final e in await queue.all()) {
    if (e.upload is WorkOrderUpload && e.upload.mobileId == mobileId) return e;
  }
  return null;
}

/// The signatures this phone captured for a job — from the queue while it
/// waits, from the archive after it went. Null when this phone never had them
/// (signed elsewhere) or the archive has rolled past it.
@riverpod
Future<WorkOrderUpload?> phoneSignatures(Ref ref, String mobileId) async {
  // Both watched before the first await — a ref.watch after one throws once
  // the provider has been disposed while it waited.
  final queuedFuture = ref.watch(queuedWorkOrderProvider(mobileId).future);
  final archiveFuture = ref.watch(uploadArchiveProvider.future);
  final queued = await queuedFuture;
  if (queued?.upload case final WorkOrderUpload w) return w;
  final archive = await archiveFuture;
  final sent = await archive.latestFor(mobileId);
  return sent is WorkOrderUpload ? sent : null;
}
