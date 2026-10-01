import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../database/database_helper.dart';
import '../../../../../sync/powersync_providers.dart';
import '../../../../../sync/sync_notifier.dart';
import '../../../../../sync/upload/upload_queue.dart';
import '../../../../../sync/sync_state.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/auth_state.dart';
// A data class from the work-orders feature, not its provider.
import '../../../work_orders/data/powersync_work_order_data_source.dart';

part 'dashboard_providers.g.dart';

class DashboardStats {
  const DashboardStats({
    required this.pendingWorkOrders,
    required this.pendingCerts,
    required this.capturedThisMonth,
  });

  /// Captured jobs still on this phone — waiting to send or set aside.
  final int pendingWorkOrders;
  final int pendingCerts;

  /// Work orders this technician captured with a job date in the current month.
  final int capturedThisMonth;
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
  // Every watch comes before the first await: a ref.watch after an await
  // throws once the provider has been disposed.
  final auth = ref.watch(authProvider);
  final syncDb = ref.watch(syncDatabaseProvider.future);
  final queue = UploadQueue(await DatabaseHelper.instance.database);

  var captured = 0;
  if (auth is AuthAuthenticated) {
    try {
      final source = PowerSyncWorkOrderDataSource.of(await syncDb);
      final now = DateTime.now();
      final list = await source.capturedBy(auth.user.id);
      captured = list.items
          .where(
            (w) =>
                w.dateIn != null &&
                w.dateIn!.year == now.year &&
                w.dateIn!.month == now.month,
          )
          .length;
    } catch (e) {
      // A count is not worth a broken dashboard.
      debugPrint('[dashboard] captured this month unavailable: $e');
    }
  }

  return DashboardStats(
    pendingWorkOrders: await queue.workOrderCount(),
    pendingCerts: await queue.certificateCount(),
    capturedThisMonth: captured,
  );
}
