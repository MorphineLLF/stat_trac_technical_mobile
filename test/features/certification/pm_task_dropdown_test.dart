import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/core/theme/app_theme.dart';
import 'package:stat_trac_technical/features/certification/domain/entities/asset_pm_task.dart';
import 'package:stat_trac_technical/features/certification/presentation/widgets/pm_task_dropdown.dart';

// The PM task is chosen from a dropdown that shows the description and
// nothing else — "Annual service", not its interval or dates. A single task
// used to be a greyed, locked box that read as a placeholder.
void main() {
  const service = AssetPmTask(
    pmTaskId: 11621,
    assetId: 12231,
    description: 'Annual service',
    active: true,
    interval: '12',
    intervalType: 'Months',
  );
  const calibration = AssetPmTask(
    pmTaskId: 10160,
    assetId: 12231,
    description: 'Annual calibration check',
    active: true,
    interval: '12',
    intervalType: 'Months',
  );

  Future<void> pump(
    WidgetTester tester, {
    required List<AssetPmTask> tasks,
    int? selectedId,
    ValueChanged<AssetPmTask>? onSelected,
  }) async {
    tester.view.physicalSize = const Size(1080, 2316);
    tester.view.devicePixelRatio = 1080 / 384;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: PmTaskDropdown(
              tasks: tasks,
              selectedId: selectedId,
              onSelected: onSelected ?? (_) {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows the chosen task by its description only', (tester) async {
    await pump(tester, tasks: const [service], selectedId: 11621);

    expect(tester.takeException(), isNull);
    expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);
    expect(find.text('Annual service'), findsOneWidget);
    expect(find.textContaining('12'), findsNothing);
    expect(find.textContaining('Months'), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
  });

  testWidgets('picking a task hands back that task', (tester) async {
    AssetPmTask? picked;
    await pump(
      tester,
      tasks: const [service, calibration],
      onSelected: (t) => picked = t,
    );

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annual calibration check').last);
    await tester.pumpAndSettle();

    expect(picked, calibration);
  });

  // The real screen hands the choice straight back as selectedId. Keying the
  // field on it rebuilt the field under its own open menu, and on the device
  // the menu stayed on screen after the pick.
  testWidgets('the menu closes once the parent takes the pick', (tester) async {
    tester.view.physicalSize = const Size(1080, 2316);
    tester.view.devicePixelRatio = 1080 / 384;
    addTearDown(tester.view.reset);

    int? selectedId;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => PmTaskDropdown(
              tasks: const [service, calibration],
              selectedId: selectedId,
              onSelected: (t) => setState(() => selectedId = t.pmTaskId),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annual service').last);
    await tester.pumpAndSettle();

    expect(selectedId, 11621);
    // Menu gone: only the field's own label remains, and the other task is
    // not on screen at all.
    expect(find.text('Annual service'), findsOneWidget);
    expect(find.text('Annual calibration check'), findsNothing);
  });
}
