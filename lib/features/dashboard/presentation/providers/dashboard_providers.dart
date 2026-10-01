import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../database/database_helper.dart';
import '../../../../../sync/powersync_providers.dart';
import '../../../../../sync/sync_notifier.dart';
import '../../../../../sync/upload/upload_queue.dart';
import '../../../../../sync/sync_state.dart';

import '../../data/pm_due_data_source.dart';

part 'dashboard_providers.g.dart';

/// What is still on the phone, waiting to reach the server.
class DashboardStats {
  const DashboardStats({required this.woToSync, required this.certsToSync});

  /// Captured work orders still on the phone — waiting or set aside.
  final int woToSync;
  final int certsToSync;

  /// PM work orders are their own module and are not on the phone yet. Never
  /// fed from work orders.
  int get pmWoToSync => 0;

  int get total => woToSync + pmWoToSync + certsToSync;
}

/// Exposes the last successful sync timestamp for the "Last synced" display.
/// Returns null if no sync has completed yet this session.
@riverpod
DateTime? lastSyncedAt(Ref ref) {
  final syncState = ref.watch(syncProvider);
  return switch (syncState) {
    SyncComplete(:final lastSyncedAt) => lastSyncedAt,
    SyncError(:final lastSyncedAt) => lastSyncedAt,
    _ => null,
  };
}

/// Counted from the OUTBOX. A captured work order is completed the moment
/// the server applies it, so nothing synced is pending — what is pending is
/// what has not left the phone.
@riverpod
Future<DashboardStats> dashboardStats(Ref ref) async {
  final queue = UploadQueue(await DatabaseHelper.instance.database);
  return DashboardStats(
    woToSync: await queue.workOrderCount(),
    certsToSync: await queue.certificateCount(),
  );
}

/// PM tasks due from today to Sunday, from the synced PM schedule.
@riverpod
Future<List<PmDueTask>> pmDueThisWeek(Ref ref) async {
  final db = await ref.watch(syncDatabaseProvider.future);
  return PmDueDataSource.of(db).dueThisWeek(DateTime.now());
}
