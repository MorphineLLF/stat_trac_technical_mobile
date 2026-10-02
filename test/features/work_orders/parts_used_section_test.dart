import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/core/theme/app_theme.dart';
import 'package:stat_trac_technical/features/work_orders/domain/register_part.dart';
import 'package:stat_trac_technical/features/work_orders/domain/work_order_job.dart';
import 'package:stat_trac_technical/features/work_orders/presentation/widgets/parts_used_section.dart';

Future<List<RegisterPart>> _search(String q) async => [
  for (final p in const [
    RegisterPart(id: 1, number: 'FUSE-5A', description: 'Fuse 5A'),
    RegisterPart(id: 2, number: 'BATT-12', description: 'Battery 12V'),
  ])
    if ('${p.number} ${p.description}'.toLowerCase().contains(q.toLowerCase()))
      p,
];

Future<List<List<PartUsed>>> _pump(
  WidgetTester t, {
  List<PartUsed> parts = const [],
  WorkOrderFieldError? error,
}) async {
  t.view.physicalSize = const Size(1080, 2316);
  t.view.devicePixelRatio = 1080 / 384;
  addTearDown(t.view.reset);
  final changes = <List<PartUsed>>[];
  await t.pumpWidget(
    MaterialApp(
      theme: appTheme,
      home: Scaffold(
        body: StatefulBuilder(
          builder: (c, set) => ListView(
            children: [
              PartsUsedSection(
                parts: changes.isEmpty ? parts : changes.last,
                search: _search,
                error: error,
                onChanged: (p) => set(() => changes.add(p)),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return changes;
}

void main() {
  testWidgets('pick from the register, then a quantity', (t) async {
    final changes = await _pump(t);
    await t.tap(find.text('Add part'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('part-search')), 'fuse');
    await t.pumpAndSettle();
    await t.tap(find.text('FUSE-5A'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('part-qty')), '2');
    await t.pump();
    await t.tap(find.text('Add'));
    await t.pumpAndSettle();

    final p = changes.last.single;
    expect(p.partId, 1);
    expect(p.qty, 2);
    expect(find.text('FUSE-5A — Fuse 5A'), findsOneWidget);
    expect(find.text('× 2'), findsOneWidget);
  });

  testWidgets('type it instead, with a comma quantity', (t) async {
    final changes = await _pump(t);
    await t.tap(find.text('Add part'));
    await t.pumpAndSettle();
    await t.tap(find.text('Type it instead'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('part-desc')), 'Cable tie');
    await t.enterText(find.byKey(const Key('part-qty')), '1,5');
    await t.pump();
    await t.tap(find.text('Add'));
    await t.pumpAndSettle();

    final p = changes.last.single;
    expect(p.picked, isFalse);
    expect(p.description, 'Cable tie');
    expect(p.qty, 1.5);
  });

  testWidgets('a quantity of nought cannot be added', (t) async {
    await _pump(t);
    await t.tap(find.text('Add part'));
    await t.pumpAndSettle();
    await t.tap(find.text('FUSE-5A'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('part-qty')), '0');
    await t.pump();
    expect(
      t.widget<TextButton>(find.widgetWithText(TextButton, 'Add')).onPressed,
      isNull,
    );
  });

  testWidgets('remove a line', (t) async {
    final changes = await _pump(
      t,
      parts: const [PartUsed(description: 'Cable tie', qty: 1)],
    );
    await t.tap(find.byTooltip('Remove'));
    await t.pumpAndSettle();
    expect(changes.last, isEmpty);
  });

  testWidgets('a refusal shows on its line', (t) async {
    await _pump(
      t,
      parts: const [
        PartUsed(description: 'a', qty: 1),
        PartUsed(description: 'b', qty: 1),
      ],
      error: const WorkOrderFieldError('parts[1].qty', 'Too many'),
    );
    expect(find.text('Too many'), findsOneWidget);
  });
}
