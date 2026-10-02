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

Future<List<RegisterPart>> _rates(String q) async => const [
  RegisterPart(
    id: 9,
    number: 'LAB-HR',
    description: 'Labour per hour',
    kind: 2,
  ),
];

Future<List<List<PartUsed>>> _pump(
  WidgetTester t, {
  List<PartUsed> parts = const [],
  WorkOrderFieldError? error,
  bool charged = false,
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
                search: charged ? _rates : _search,
                charged: charged,
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
  // The quantity is set on the list itself, and Add puts the part on the
  // work order — no second screen (the user's call, 2026-10-02).
  testWidgets('a quantity on the list row, then Add', (t) async {
    final changes = await _pump(t);
    await t.tap(find.text('Add part'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('part-search')), 'fuse');
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('pick-qty-1')), '2');
    await t.pump();
    await t.tap(find.byKey(const Key('pick-add-1')));
    await t.pumpAndSettle();

    final p = changes.last.single;
    expect(p.partId, 1);
    expect(p.qty, 2);
    expect(find.byKey(const Key('part-search')), findsNothing);
    expect(find.text('Fuse 5A'), findsOneWidget);
    expect(find.text('FUSE-5A'), findsOneWidget);
    expect(find.byKey(const Key('qty-0')), findsOneWidget);
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

  testWidgets('the list quantity starts at one', (t) async {
    final changes = await _pump(t);
    await t.tap(find.text('Add part'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('pick-add-2')));
    await t.pumpAndSettle();
    expect(changes.last.single.qty, 1);
    expect(changes.last.single.partId, 2);
  });

  testWidgets('a list row at nought cannot be added', (t) async {
    await _pump(t);
    await t.tap(find.text('Add part'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('pick-qty-1')), '0');
    await t.pump();
    expect(
      t.widget<TextButton>(find.byKey(const Key('pick-add-1'))).onPressed,
      isNull,
    );
  });

  testWidgets('a typed line cannot be added at nought', (t) async {
    await _pump(t);
    await t.tap(find.text('Add part'));
    await t.pumpAndSettle();
    await t.tap(find.text('Type it instead'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('part-desc')), 'Cable tie');
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
    await t.tap(find.text('Cable tie'));
    await t.pumpAndSettle();
    await t.tap(find.text('Remove'));
    await t.pumpAndSettle();
    expect(changes.last, isEmpty);
  });

  testWidgets('the heading counts its lines', (t) async {
    await _pump(
      t,
      parts: const [
        PartUsed(description: 'a', qty: 1),
        PartUsed(description: 'b', qty: 1),
        PartUsed(description: 'c', qty: 1, kind: 2),
      ],
    );
    expect(find.text('2'), findsWidgets);
    expect(find.byKey(const Key('count')), findsOneWidget);
    expect(t.widget<Text>(find.byKey(const Key('count'))).data, '2');
  });

  testWidgets('+ and − change the quantity by one, never to nought', (t) async {
    final changes = await _pump(
      t,
      parts: const [PartUsed(description: 'Cable tie', qty: 1.5)],
    );
    await t.tap(find.byTooltip('More'));
    await t.pumpAndSettle();
    expect(changes.last.single.qty, 2.5);
    await t.tap(find.byTooltip('Less'));
    await t.pumpAndSettle();
    expect(changes.last.single.qty, 1.5);
    await t.tap(find.byTooltip('Less'));
    await t.pumpAndSettle();
    expect(changes.last.single.qty, 0.5);
    // Below one it would reach nought: − is off.
    expect(
      t
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.remove))
          .onPressed,
      isNull,
    );
  });

  testWidgets('a typed line opens to edit; Save replaces it', (t) async {
    final changes = await _pump(
      t,
      parts: const [PartUsed(description: 'Cable tie', qty: 1)],
    );
    await t.tap(find.text('Cable tie'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('part-desc')), 'Cable tie 300 mm');
    await t.enterText(find.byKey(const Key('part-qty')), '4');
    await t.pump();
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(changes.last.single.description, 'Cable tie 300 mm');
    expect(changes.last.single.qty, 4);
  });

  // The register owns a picked line's name: only the quantity changes.
  testWidgets('a picked line edits its quantity only', (t) async {
    final changes = await _pump(
      t,
      parts: const [
        PartUsed(partId: 1, partNo: 'FUSE-5A', description: 'Fuse 5A', qty: 1),
      ],
    );
    await t.tap(find.text('Fuse 5A'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('part-desc')), findsNothing);
    await t.enterText(find.byKey(const Key('part-qty')), '3');
    await t.pump();
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(changes.last.single.qty, 3);
    expect(changes.last.single.partId, 1);
  });

  testWidgets('Cancel changes nothing', (t) async {
    final changes = await _pump(
      t,
      parts: const [PartUsed(description: 'Cable tie', qty: 1)],
    );
    await t.tap(find.text('Cable tie'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('part-qty')), '9');
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(changes, isEmpty);
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

  group('charged rates', () {
    const mixed = [
      PartUsed(description: 'Fuse', qty: 1),
      PartUsed(description: 'Travel', qty: 1, kind: 2),
    ];

    testWidgets('shows only its own lines', (t) async {
      await _pump(t, parts: mixed, charged: true);
      expect(find.text('Charged rates'), findsOneWidget);
      expect(find.text('Travel'), findsOneWidget);
      expect(find.text('Fuse'), findsNothing);
    });

    testWidgets('a typed charged rate is kind 2; parts are kept', (t) async {
      final changes = await _pump(t, parts: mixed, charged: true);
      await t.tap(find.text('Add rate'));
      await t.pumpAndSettle();
      await t.tap(find.text('Type it instead'));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('part-desc')), 'Mileage 80 km');
      await t.enterText(find.byKey(const Key('part-qty')), '1');
      await t.pump();
      await t.tap(find.text('Add'));
      await t.pumpAndSettle();

      final all = changes.last;
      expect(all.length, 3);
      expect(all.last.kind, PartUsed.chargedKind);
      expect(all.first.description, 'Fuse');
    });

    testWidgets('a picked rate keeps the register kind', (t) async {
      final changes = await _pump(t, charged: true);
      await t.tap(find.text('Add rate'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('pick-add-9')));
      await t.pumpAndSettle();
      expect(changes.last.single.kind, 2);
      expect(changes.last.single.partId, 9);
    });

    testWidgets('removing a rate leaves the parts alone', (t) async {
      final changes = await _pump(t, parts: mixed, charged: true);
      await t.tap(find.text('Travel'));
      await t.pumpAndSettle();
      await t.tap(find.text('Remove'));
      await t.pumpAndSettle();
      expect(changes.last.single.description, 'Fuse');
    });

    // The server names the line by its place in the whole list.
    testWidgets('a refusal finds its line across both sections', (t) async {
      await _pump(
        t,
        parts: mixed,
        charged: true,
        error: const WorkOrderFieldError('parts[1].qty', 'Too many'),
      );
      expect(find.text('Too many'), findsOneWidget);
    });
  });
}
