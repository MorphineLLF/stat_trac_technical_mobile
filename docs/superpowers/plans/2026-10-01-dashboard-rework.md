# Dashboard Rework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** The dashboard fits one phone screen with no page scroll: a dark sync summary under the app bar, the four module tiles unchanged, and "PM tasks due this week" filling the rest with its own scroll; the bottom bar always shows.

**Architecture:** `_HomeBody` becomes a fixed-height `Column` (no `SingleChildScrollView`): `_SyncSummary` → `DashboardModuleGrid` (untouched) → `Expanded(_PmDueCard)` whose list scrolls inside. Counts come from the outbox as today; PM tasks due come from PowerSync `AssetPmTask` (no joins; asset names fetched separately with a timeout).

**Tech Stack:** Flutter, Riverpod 3 codegen, fl_chart (`PieChart`), sqflite_common_ffi (tests).

**Design (approved by the user 2026-10-01):** mockup https://claude.ai/artifact/QAU4szY1QvvGbreoyVHU7X

## Global Constraints

- The AppBar (greeting, sync status, sync button, log out) and the bottom `NavigationBar` are **not changed**.
- `DashboardModuleGrid` (the four tiles) is **not changed** — same size, same buttons, same enabled states.
- Header colours are the app's own: WO `#1B7EA6` (brandTeal), PM `#2E7D32`, Certs `#00838F`; header background `#0D2B3E` (brandDark).
- Labels exactly: **WO to Sync**, **PM WO to Sync**, **Certs to Sync**. Ring centre: the total and "to sync"; at 0 a green ring (`#2E7D32`), a tick and **All synced**.
- **PM WO to Sync is 0** — PM work orders are a different module, not on the phone. Never fed from work orders.
- Removed by the user's approved design: the three pending cards, the white donut card, the Overdue/Pending/Certs KPI row.
- PM tasks due this week: active tasks (`PmTaskActive = 1`) with `PmTaskScheduleDate` from today to Sunday of this week, earliest first, every synced task (all the technician's hospitals). Rows are not tappable.
- Never join PowerSync tables. Widget tests pump the real `appTheme`. `flutter test` + `flutter analyze` clean. Commit to `master`, trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. A small phone (360 × 640 dp) at text scale 1.15: no overflow, tiles and bottom bar fully on screen, PM card shrinks (Task 3 test).
2. No PM tasks this week: the card says "No PM tasks due this week", not an empty box (Task 3 test).
3. PM read slow or failing: the card says "PM tasks could not be loaded", never spins for ever (Task 1 test).
4. Sunday: "this week" is just today (Task 1 test).
5. Total 0 shows All synced; any count > 0 shows the number (Task 2 test).

---

### Task 1: PM tasks due this week — data

**Files:** Create `lib/features/dashboard/data/pm_due_data_source.dart`; Test `test/features/dashboard/pm_due_data_source_test.dart`

**Produces:** `class PmDueTask { String description; DateTime due; String? equipment; String? hospital; }`, `class PmDueDataSource(SqlRead read, {Duration timeout})` with `.of(PowerSyncDatabase)` and `Future<List<PmDueTask>> dueThisWeek(DateTime today)`; top-level `DateTime endOfWeek(DateTime today)` (Sunday, date only).

- [ ] **Step 1: failing test** — plain SQLite tables `"AssetPmTask"` (`PmTaskID`, `PmAssetID`, `PmTaskDescription`, `PmTaskScheduleDate`, `PmTaskActive`) and `"Asset"` (`AssetID`, `AssetEquipmentType`, `AssetHospital`); read = `(sql, args) => db.rawQuery(sql, args)`. Cases, with today = Wed 2026-09-30:
  - due Thu 2026-10-01 and Sun 2026-10-04 → both, in that order, with equipment/hospital attached;
  - due Mon 2026-10-05 → excluded; due Tue 2026-09-29 → excluded; `PmTaskActive = 0` → excluded;
  - `endOfWeek(DateTime(2026, 10, 4))` (a Sunday) == `DateTime(2026, 10, 4)`;
  - the Asset read delayed past the timeout → tasks still returned, equipment/hospital null (await the slow read before tearDown).
- [ ] **Step 2:** `flutter test test/features/dashboard/pm_due_data_source_test.dart` → FAIL (file missing).
- [ ] **Step 3: implement**

```dart
import 'package:flutter/foundation.dart';
import 'package:powersync/powersync.dart';

import '../../../sync/powersync_types.dart';

typedef SqlRead =
    Future<List<Map<String, Object?>>> Function(String sql, List<Object?> args);

class PmDueTask {
  const PmDueTask({required this.description, required this.due,
      this.equipment, this.hospital});
  final String description;
  final DateTime due;
  final String? equipment;
  final String? hospital;
}

/// Sunday of [today]'s week, date only. On a Sunday, today.
DateTime endOfWeek(DateTime today) {
  final day = DateTime(today.year, today.month, today.day);
  return day.add(Duration(days: DateTime.sunday - day.weekday));
}

/// PM tasks due from today to Sunday. PM is its own module — this reads the
/// PM schedule and has nothing to do with work orders.
///
/// No joins: the tasks first, the machines separately with a timeout, so a
/// slow asset store costs the names, never the list.
class PmDueDataSource {
  PmDueDataSource(this._read, {this.timeout = const Duration(seconds: 5)});

  factory PmDueDataSource.of(PowerSyncDatabase db) =>
      PmDueDataSource((sql, args) => db.getAll(sql, args));

  final SqlRead _read;
  final Duration timeout;

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<List<PmDueTask>> dueThisWeek(DateTime today) async {
    final from = DateTime(today.year, today.month, today.day);
    final rows = await _read(
      'SELECT "PmAssetID", "PmTaskDescription", "PmTaskScheduleDate" '
      'FROM "AssetPmTask" WHERE "PmTaskActive" = 1 '
      'AND date("PmTaskScheduleDate") BETWEEN ? AND ? '
      'ORDER BY "PmTaskScheduleDate", "PmTaskDescription" LIMIT 200',
      [_date(from), _date(endOfWeek(from))],
    ).timeout(timeout);

    final ids = {for (final r in rows) ?psInt(r['PmAssetID'])};
    final assets = <int, ({String? equipment, String? hospital})>{};
    if (ids.isNotEmpty) {
      try {
        final marks = List.filled(ids.length, '?').join(',');
        final found = await _read(
          'SELECT "AssetID", "AssetEquipmentType", "AssetHospital" '
          'FROM "Asset" WHERE "AssetID" IN ($marks)',
          ids.toList(),
        ).timeout(timeout);
        for (final a in found) {
          final id = psInt(a['AssetID']);
          if (id == null) continue;
          assets[id] = (
            equipment: a['AssetEquipmentType'] as String?,
            hospital: a['AssetHospital'] as String?,
          );
        }
      } catch (e) {
        debugPrint('[dashboard] PM task machines unreadable: $e');
      }
    }

    return [
      for (final r in rows)
        if (psDate(r['PmTaskScheduleDate']) case final due?)
          PmDueTask(
            description: (r['PmTaskDescription'] as String? ?? '').trim(),
            due: due,
            equipment: assets[psInt(r['PmAssetID'])]?.equipment,
            hospital: assets[psInt(r['PmAssetID'])]?.hospital,
          ),
    ];
  }
}
```

- [ ] **Step 4:** test → PASS; `flutter analyze` clean.
- [ ] **Step 5:** commit `feat(dashboard): PM tasks due this week, read from the PM schedule`.

---

### Task 2: The sync summary header

**Files:** Create `lib/features/dashboard/presentation/widgets/sync_summary.dart`; Modify `lib/features/dashboard/presentation/providers/dashboard_providers.dart`; Test `test/features/dashboard/sync_summary_test.dart`

**Produces:** `DashboardStats({required int woToSync, required int certsToSync})` with `int get pmWoToSync => 0` and `int get total`; `SyncSummary({required DashboardStats stats})`.

- [ ] **Step 1: failing test** (real `appTheme`, 384 dp): stats (2, 1) → shows "WO to Sync" 2, "PM WO to Sync" 0, "Certs to Sync" 1, centre "3" and "to sync", a `PieChart`; stats (0, 0) → "All synced", tick icon (`Icons.check_rounded`), no "to sync".
- [ ] **Step 2:** run → FAIL.
- [ ] **Step 3: implement.** `DashboardStats` becomes:

```dart
class DashboardStats {
  const DashboardStats({required this.woToSync, required this.certsToSync});

  /// Captured work orders still on the phone.
  final int woToSync;
  final int certsToSync;

  /// PM work orders are their own module and are not on the phone yet.
  int get pmWoToSync => 0;

  int get total => woToSync + pmWoToSync + certsToSync;
}
```

`dashboardStats` returns `DashboardStats(woToSync: await queue.workOrderCount(), certsToSync: await queue.certificateCount())`.

`sync_summary.dart`:

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/dashboard_providers.dart';

const _wo = Color(0xFF1B7EA6);
const _pm = Color(0xFF2E7D32);
const _certs = Color(0xFF00838F);

/// The dark block under the app bar: what is still on the phone.
class SyncSummary extends StatelessWidget {
  const SyncSummary({super.key, required this.stats});
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final allSynced = stats.total == 0;
    final sections = allSynced
        ? [PieChartSectionData(value: 1, color: _pm, radius: 12, title: '')]
        : [
            if (stats.woToSync > 0)
              PieChartSectionData(value: stats.woToSync.toDouble(),
                  color: _wo, radius: 12, title: ''),
            if (stats.pmWoToSync > 0)
              PieChartSectionData(value: stats.pmWoToSync.toDouble(),
                  color: _pm, radius: 12, title: ''),
            if (stats.certsToSync > 0)
              PieChartSectionData(value: stats.certsToSync.toDouble(),
                  color: _certs, radius: 12, title: ''),
          ];
    return Container(
      color: brandDark,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(PieChartData(sections: sections,
                    centerSpaceRadius: 34, sectionsSpace: 0)),
                if (allSynced)
                  const Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_rounded, color: Color(0xFF7CD992), size: 24),
                    Text('All synced',
                        style: TextStyle(color: Color(0xFFC9D6E0), fontSize: 10)),
                  ])
                else
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('${stats.total}', style: const TextStyle(
                        color: Colors.white, fontSize: 22,
                        fontWeight: FontWeight.w700, height: 1)),
                    const Text('to sync', style: TextStyle(
                        color: Color(0xFFC9D6E0), fontSize: 11)),
                  ]),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(children: [
              _Line(color: _wo, label: 'WO to Sync', count: stats.woToSync),
              const SizedBox(height: 8),
              _Line(color: _pm, label: 'PM WO to Sync', count: stats.pmWoToSync),
              const SizedBox(height: 8),
              _Line(color: _certs, label: 'Certs to Sync', count: stats.certsToSync),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.color, required this.label, required this.count});
  final Color color;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 14))),
        Text('$count', style: const TextStyle(color: Colors.white,
            fontSize: 14, fontWeight: FontWeight.w700)),
      ]);
}
```

- [ ] **Step 4:** test → PASS; analyze clean (fix any old `DashboardStats` callers in `dashboard_screen.dart` only as far as compiling needs — Task 3 replaces `_HomeBody`).
- [ ] **Step 5:** commit `feat(dashboard): sync summary header — WO, PM WO and certs to sync`.

---

### Task 3: The new home body

**Files:** Modify `lib/features/dashboard/presentation/screens/dashboard_screen.dart`, `lib/features/dashboard/presentation/providers/dashboard_providers.dart`; Create `lib/features/dashboard/presentation/widgets/pm_due_card.dart`; Test `test/features/dashboard/home_body_fit_test.dart`

**Consumes:** `PmDueDataSource`, `PmDueTask` (Task 1); `SyncSummary`, `DashboardStats` (Task 2); `syncDatabaseProvider`.

**Produces:** `pmDueThisWeekProvider` → `Future<List<PmDueTask>>`; `PmDueCard()`; `@visibleForTesting DashboardHome()` (the new `_HomeBody`, public for the fit test).

- [ ] **Step 1: failing test.** Pump `MaterialApp(theme: appTheme, home: Scaffold(body: DashboardHome(), bottomNavigationBar: NavigationBar(...4 destinations...)))` with `dashboardStatsProvider` and `pmDueThisWeekProvider` overridden, at three sizes: 384 × 832 dp scale 1.15, 412 × 915 dp scale 1.0, 360 × 640 dp scale 1.15. For each: no exception (`tester.takeException()` is null — overflow throws in tests), `find.text('Certificate')` and the 'Home' nav label are hit-testable and inside the screen, `find.byType(SingleChildScrollView)` finds nothing at the page level. Also: empty list → "No PM tasks due this week"; provider error → "PM tasks could not be loaded"; 12 tasks → the card's list is scrollable (`ListView` found) and the tiles do not move.
- [ ] **Step 2:** run → FAIL.
- [ ] **Step 3: implement.** Provider:

```dart
@riverpod
Future<List<PmDueTask>> pmDueThisWeek(Ref ref) async {
  final db = await ref.watch(syncDatabaseProvider.future);
  return PmDueDataSource.of(db).dueThisWeek(DateTime.now());
}
```

`pm_due_card.dart`: a white card (`#DDE3EA` border, 12 radius) with a title row "PM TASKS DUE · THIS WEEK" and the count in `#2E7D32`; body `ref.watch(pmDueThisWeekProvider).when(...)`: loading → a small `LinearProgressIndicator`; error → "PM tasks could not be loaded"; empty → "No PM tasks due this week"; else `ListView.separated` of rows: green dot, description (bold), "equipment · hospital" (skip nulls), due as `EEE d MMM` (intl).

`DashboardHome` (replaces `_HomeBody`):

```dart
@visibleForTesting
class DashboardHome extends ConsumerWidget {
  const DashboardHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider).value ??
        const DashboardStats(woToSync: 0, certsToSync: 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SyncSummary(stats: stats),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: DashboardModuleGrid(),
        ),
        const Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: PmDueCard(),
          ),
        ),
      ],
    );
  }
}
```

Delete `_HomeBody`, `_PendingTasksRow`, `_TaskCountCard`, `_StatsCard`, `_ChartLegend`, `_KpiRow`, `_KpiTile`; `body:` uses `const DashboardHome()`. Where the screen invalidates `dashboardStatsProvider`, also invalidate `pmDueThisWeekProvider` on resume. `DashboardModuleGrid` stays byte-for-byte. Run `dart run build_runner build --delete-conflicting-outputs`.

- [ ] **Step 4:** fit test → PASS at all three sizes; full `flutter test`; `flutter analyze`.
- [ ] **Step 5:** update CLAUDE.md's Dashboard bullets to the new layout; commit `feat(dashboard): one screen — sync summary, tiles, PM tasks due this week`.
- [ ] **Step 6:** run on the emulator for the user to look at.
