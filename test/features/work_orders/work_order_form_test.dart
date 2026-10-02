import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/core/theme/app_theme.dart';
import 'package:stat_trac_technical/features/work_orders/domain/work_order_job.dart';
import 'package:stat_trac_technical/features/work_orders/presentation/widgets/work_order_form.dart';

void main() {
  Future<List<WorkOrderJob>> pump(
    WidgetTester tester, {
    WorkOrderFieldError? serverError,
  }) async {
    tester.view.physicalSize = const Size(1080, 2316);
    tester.view.devicePixelRatio = 1080 / 384;
    addTearDown(tester.view.reset);
    final changes = <WorkOrderJob>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: WorkOrderForm(
            job: WorkOrderJob(
              assetId: 100,
              started: DateTime(2026, 10, 1, 8),
              finished: DateTime(2026, 10, 1, 10),
            ),
            technicianName: 'Athi',
            searchParts: (_) async => const [],
            serverError: serverError,
            onChanged: changes.add,
          ),
        ),
      ),
    );
    return changes;
  }

  testWidgets('PM is not a choice and nothing is chosen', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('wo-work-type')));
    await tester.pumpAndSettle();
    expect(find.text('PM Service'), findsNothing);
    expect(find.text('Installation'), findsWidgets);
  });

  testWidgets('the technician is shown and cannot be edited', (tester) async {
    await pump(tester);
    expect(find.text('Athi'), findsOneWidget);
    expect(
      find.ancestor(of: find.text('Athi'), matching: find.byType(TextField)),
      findsNothing,
    );
  });

  testWidgets('typing a fault reports a new job', (tester) async {
    final changes = await pump(tester);
    await tester.enterText(find.byKey(const Key('wo-fault')), 'Beeps');
    expect(changes.last.fault, 'Beeps');
  });

  testWidgets('a server refusal shows under its box', (tester) async {
    await pump(
      tester,
      serverError: const WorkOrderFieldError('jobfault', 'Too long'),
    );
    expect(find.text('Too long'), findsOneWidget);
  });
}
