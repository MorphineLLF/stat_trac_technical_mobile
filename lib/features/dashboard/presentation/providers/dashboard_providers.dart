import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../database/database_helper.dart';
import '../../../../../sync/sync_notifier.dart';
import '../../../../../sync/upload/upload_queue.dart';
import '../../../../../sync/sync_state.dart';

part 'dashboard_providers.g.dart';

class DashboardStats {
  const DashboardStats({
    required this.overdue,
    required this.pending,
    required this.pendingCerts,
  });

  final int overdue;
  final int pending;
  final int pendingCerts;

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

/// Active WO counts for the dashboard donut chart and KPI row.
/// Active = not completed / reviewed / closed / cancelled.
@riverpod
Future<DashboardStats> dashboardStats(Ref ref) async {
  final db = await DatabaseHelper.instance.database;
  final now = DateTime.now().toIso8601String();

  final rows = await db.rawQuery(
    '''
    SELECT
      SUM(CASE WHEN sla_due_at IS NOT NULL AND sla_due_at < ?
               AND status NOT IN ('completed','reviewed','closed','cancelled')
               THEN 1 ELSE 0 END) AS overdue,
      SUM(CASE WHEN status IN ('created','assigned','rejected')
               THEN 1 ELSE 0 END) AS pending
    FROM work_orders
    WHERE status NOT IN ('completed','reviewed','closed','cancelled')
  ''',
    [now],
  );

  // Counted from the OUTBOX, not from test_certificates.
  //
  // The old query counted rows in the retired Horse table whose sync_status
  // is cleared only by the Horse push path -- which is disabled because its
  // endpoints 404 forever. So it could never reach zero: a certificate saved
  // before this change reads as "to sync" permanently, no matter what
  // actually reaches the server.
  //
  // Worse, it disagreed with the real queue, and two indicators disagreeing
  // is worse than one being wrong: it teaches a technician that neither
  // number means anything.
  final certRows = await db.rawQuery(
    'SELECT COUNT(*) AS cnt FROM ${UploadQueue.table}',
  );

  final row = rows.first;
  return DashboardStats(
    overdue: (row['overdue'] as int?) ?? 0,
    pending: (row['pending'] as int?) ?? 0,
    pendingCerts: (certRows.first['cnt'] as int?) ?? 0,
  );
}
