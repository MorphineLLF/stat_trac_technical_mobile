import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/core/theme/app_theme.dart';
import 'package:stat_trac_technical/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:stat_trac_technical/features/dashboard/presentation/widgets/sync_summary.dart';

void main() {
  Future<void> pump(WidgetTester tester, DashboardStats stats) async {
    tester.view.physicalSize = const Size(1080, 2316);
    tester.view.devicePixelRatio = 1080 / 384;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(body: SyncSummary(stats: stats)),
      ),
    );
  }

  String countBeside(WidgetTester tester, String label) {
    final row = find.ancestor(of: find.text(label), matching: find.byType(Row));
    final texts = tester
        .widgetList<Text>(
          find.descendant(of: row.first, matching: find.byType(Text)),
        )
        .map((t) => t.data)
        .toList();
    return texts.last!;
  }

  testWidgets('work to sync: each line, the total and the ring', (
    tester,
  ) async {
    await pump(tester, const DashboardStats(woToSync: 2, certsToSync: 1));

    expect(countBeside(tester, 'WO to Sync'), '2');
    expect(countBeside(tester, 'PM WO to Sync'), '0');
    expect(countBeside(tester, 'Certs to Sync'), '1');
    expect(find.text('3'), findsOneWidget);
    expect(find.text('to sync'), findsOneWidget);
    expect(find.byType(PieChart), findsOneWidget);
    expect(find.text('All synced'), findsNothing);
  });

  testWidgets('nothing to sync: a tick and All synced', (tester) async {
    await pump(tester, const DashboardStats(woToSync: 0, certsToSync: 0));

    expect(find.text('All synced'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.text('to sync'), findsNothing);
  });

  // PM work orders are their own module and not on the phone.
  test('PM WO to Sync is never fed from work orders', () {
    expect(const DashboardStats(woToSync: 5, certsToSync: 0).pmWoToSync, 0);
    expect(const DashboardStats(woToSync: 5, certsToSync: 2).total, 7);
  });
}
