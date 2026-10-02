import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/core/theme/app_theme.dart';
import 'package:stat_trac_technical/features/dashboard/data/pm_due_data_source.dart';
import 'package:stat_trac_technical/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:stat_trac_technical/features/dashboard/presentation/screens/dashboard_screen.dart';

List<PmDueTask> _tasks(int n) => [
  for (var i = 0; i < n; i++)
    PmDueTask(
      description: 'Annual PM $i',
      due: DateTime(2026, 10, 1 + i % 4),
      equipment: 'Infusion pump',
      hospital: 'Groote Schuur',
    ),
];

// The dashboard is for clients and must fit any phone without scrolling: the
// summary, the four tiles and the bottom bar on screen, the PM list the only
// thing that scrolls, inside its own card.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required Size dp,
    required double scale,
    Future<List<PmDueTask>> Function()? pm,
  }) async {
    tester.view.physicalSize = dp * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardStatsProvider.overrideWith(
            (ref) async => const DashboardStats(woToSync: 2, certsToSync: 1),
          ),
          pmDueThisWeekProvider.overrideWith(
            (ref) => (pm ?? () async => _tasks(3))(),
          ),
        ],
        child: MaterialApp(
          theme: appTheme,
          home: MediaQuery.withClampedTextScaling(
            minScaleFactor: scale,
            maxScaleFactor: scale,
            child: Scaffold(
              appBar: AppBar(title: const Text('Hi, Athi Maphaha')),
              body: const DashboardHome(),
              bottomNavigationBar: NavigationBar(
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
                  NavigationDestination(
                    icon: Icon(Icons.work),
                    label: 'Assets',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.inventory),
                    label: 'Inventory',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.qr_code_scanner),
                    label: 'Barcode',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void expectOnScreen(WidgetTester tester, Finder f, Size dp) {
    final r = tester.getRect(f);
    expect(
      r.top >= 0 && r.bottom <= dp.height,
      isTrue,
      reason:
          '${f.describeMatch(Plurality.one)} at $r on a ${dp.height} dp screen',
    );
  }

  // Heights are the screen less the status bar (the app bar is in the test).
  // Heights are the screen less the status bar; the app bar is in the test.
  for (final (name, dp, scale) in [
    ('S23 at 1.15', const Size(384, 814), 1.15),
    ('Pixel 6', const Size(412, 891), 1.0),
  ]) {
    testWidgets('fits without scrolling — $name', (tester) async {
      await pump(tester, dp: dp, scale: scale);

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsNothing);
      expectOnScreen(tester, find.text('WO to Sync'), dp);
      for (final tile in [
        'Worklist',
        'Work Order',
        'PM Work Order',
        'Certificate',
      ]) {
        expectOnScreen(tester, find.text(tile), dp);
      }
      expectOnScreen(tester, find.text('Create').last, dp);
      expectOnScreen(tester, find.text('PM TASKS DUE · THIS WEEK'), dp);
      expectOnScreen(tester, find.text('Home'), dp);
    });
  }

  // A small phone is too short for the summary and the unchanged tiles: the
  // page scrolls there (the user, 2026-10-01), and nothing overflows.
  testWidgets('a 360 × 640 phone scrolls instead of breaking', (tester) async {
    const dp = Size(360, 616);
    await pump(tester, dp: dp, scale: 1.15);

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expectOnScreen(tester, find.text('Home'), dp);
  });

  testWidgets('a long PM list scrolls inside its card; the tiles stay put', (
    tester,
  ) async {
    const dp = Size(384, 814);
    await pump(tester, dp: dp, scale: 1.15, pm: () async => _tasks(12));
    final before = tester.getRect(find.text('Certificate'));

    expect(find.byType(ListView), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(tester.getRect(find.text('Certificate')), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no PM tasks this week says so', (tester) async {
    await pump(
      tester,
      dp: const Size(384, 832),
      scale: 1.0,
      pm: () async => const [],
    );
    expect(find.text('No PM tasks due this week'), findsOneWidget);
  });

  testWidgets('PM tasks that cannot be read say so, never spin', (
    tester,
  ) async {
    await pump(
      tester,
      dp: const Size(384, 832),
      scale: 1.0,
      pm: () async => throw StateError('no database'),
    );
    expect(find.text('PM tasks could not be loaded'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
