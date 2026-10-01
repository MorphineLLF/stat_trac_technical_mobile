import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../database/database_helper.dart';
import '../../../../../sync/sync_notifier.dart';
import '../../../../../sync/upload/upload_queue.dart';
import '../../../../../sync/sync_state.dart';

part 'dashboard_providers.g.dart';

class DashboardStats {
  const DashboardStats({
    required this.pendingWorkOrders,
    required this.pendingCerts,
  });

  /// Captured jobs still on this phone — waiting to send or set aside.
  final int pendingWorkOrders;
  final int pendingCerts;

  // The donut and KPI row. Overdue read the Horse-era work_orders table, which
  // is gone; nothing on the phone tracks a due date yet, so it is 0.
  int get overdue => 0;
  int get pending => pendingWorkOrders;

  int get total => overdue + pending + pendingCerts;
  double get overduePct => total == 0 ? 0 : overdue / total;
  double get pendingPct => total == 0 ? 0 : pending / total;
  double get pendingCertsPct => total == 0 ? 0 : pendingCerts / total;
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
    pendingWorkOrders: await queue.workOrderCount(),
    pendingCerts: await queue.certificateCount(),
  );
}
