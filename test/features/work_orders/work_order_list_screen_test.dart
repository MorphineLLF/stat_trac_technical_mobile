import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/core/theme/app_theme.dart';
import 'package:stat_trac_technical/features/work_orders/domain/work_order_summary.dart';
import 'package:stat_trac_technical/features/work_orders/presentation/providers/work_order_providers.dart';
import 'package:stat_trac_technical/features/work_orders/presentation/screens/work_order_list_screen.dart';

void main() {
  Future<void> pump(WidgetTester tester, Worklist list) async {
    tester.view.physicalSize = const Size(1080, 2316);
    tester.view.devicePixelRatio = 1080 / 384;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [worklistProvider.overrideWith((ref) async => list)],
      child: MaterialApp(theme: appTheme, home: const WorkOrderListScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('a pending job has no number yet', (tester) async {
    await pump(tester, const Worklist([
      WorkOrderSummary(mobileId: 'wo-9', status: 'Waiting to sync',
          queueState: WorkOrderQueueState.waiting),
      WorkOrderSummary(trackId: 1801, mobileId: 'wo-1', status: 'WO Completed'),
    ], syncedComplete: true));

    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('WO 1801'), findsOneWidget);
    expect(find.text('Waiting to sync'), findsOneWidget);
  });

  testWidgets('cards unreadable: says so instead of spinning', (tester) async {
    await pump(tester, const Worklist([], syncedComplete: false));
    expect(find.text('Synced work orders still loading — pull to retry'),
        findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('nothing at all', (tester) async {
    await pump(tester, const Worklist([], syncedComplete: true));
    expect(find.text('No work orders yet'), findsOneWidget);
  });
}
