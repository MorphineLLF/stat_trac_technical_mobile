import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/core/theme/app_theme.dart';
import 'package:stat_trac_technical/features/work_orders/presentation/providers/work_order_providers.dart';
import 'package:stat_trac_technical/features/work_orders/presentation/widgets/machine_next.dart';

Future<void> _pump(WidgetTester t, Future<int?> Function() open) async {
  await t.pumpWidget(
    ProviderScope(
      overrides: [openRepairOnAssetProvider(100).overrideWith((ref) => open())],
      child: MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: ListView(children: [MachineNext(assetId: 100, onNext: () {})]),
        ),
      ),
    ),
  );
}

void main() {
  // The user's rule (2026-10-02): a machine with an open work order offers no
  // way on. The server would refuse the capture anyway.
  testWidgets('an open work order: the warning and no Next', (t) async {
    await _pump(t, () async => 3458);
    await t.pumpAndSettle();
    expect(find.textContaining('Work order 3458 is still open'), findsOne);
    expect(find.text('Next'), findsNothing);
  });

  testWidgets('no open work order: Next', (t) async {
    await _pump(t, () async => null);
    await t.pumpAndSettle();
    final next = t.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Next'),
    );
    expect(next.onPressed, isNotNull);
  });

  // A quick tap must not get past a check that has not answered yet.
  testWidgets('still checking: Next is greyed out', (t) async {
    final pending = Completer<int?>();
    await _pump(t, () => pending.future);
    await t.pump();
    final next = t.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Next'),
    );
    expect(next.onPressed, isNull);
    pending.complete(null);
  });

  // The phone's copy is a cache. If it cannot be read, the server decides.
  testWidgets('the check failed: Next, the server decides', (t) async {
    await _pump(t, () async => throw StateError('no such table'));
    await t.pumpAndSettle();
    final next = t.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Next'),
    );
    expect(next.onPressed, isNotNull);
  });
}
