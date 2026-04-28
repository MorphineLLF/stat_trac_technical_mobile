import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../database/database_helper.dart';
import '../../../../../sync/sync_notifier.dart';
import '../../../../../sync/sync_state.dart';

part 'dashboard_providers.g.dart';

class DashboardStats {
  const DashboardStats({
    required this.total,
    required this.overdue,
    required this.pending,
    required this.wip,
  });

  final int total;
  final int overdue;
  final int pending;
  final int wip;

  double get overduePct => total == 0 ? 0 : overdue / total;
  double get pendingPct => total == 0 ? 0 : pending / total;
  double get wipPct => total == 0 ? 0 : wip / total;
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

  final rows = await db.rawQuery('''
    SELECT
      COUNT(*) AS total,
      SUM(CASE WHEN sla_due_at IS NOT NULL AND sla_due_at < ?
               AND status NOT IN ('completed','reviewed','closed','cancelled')
               THEN 1 ELSE 0 END) AS overdue,
      SUM(CASE WHEN status IN ('created','assigned','rejected')
               THEN 1 ELSE 0 END) AS pending,
      SUM(CASE WHEN status IN ('accepted','en_route','on_site',
                               'in_progress','paused','awaiting_parts')
               THEN 1 ELSE 0 END) AS wip
    FROM work_orders
    WHERE status NOT IN ('completed','reviewed','closed','cancelled')
  ''', [now]);

  final row = rows.first;
  return DashboardStats(
    total: (row['total'] as int?) ?? 0,
    overdue: (row['overdue'] as int?) ?? 0,
    pending: (row['pending'] as int?) ?? 0,
    wip: (row['wip'] as int?) ?? 0,
  );
}
