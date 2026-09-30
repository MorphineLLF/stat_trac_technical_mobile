import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/core/theme/app_theme.dart';
import 'package:stat_trac_technical/features/certification/presentation/widgets/result_radio_row.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    TestResult? value,
    required ValueChanged<TestResult>? onSelected,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: SizedBox(
            // The S23 Ultra card's inner width: 384 dp less margins,
            // stripe and padding.
            width: 331,
            child: ResultRadioRow(value: value, onSelected: onSelected),
          ),
        ),
      ),
    );
  }

  testWidgets('shows Pass, Fail and N/A', (tester) async {
    await pump(tester, onSelected: (_) {});
    expect(find.text('Pass'), findsOneWidget);
    expect(find.text('Fail'), findsOneWidget);
    expect(find.text('N/A'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping an option selects it', (tester) async {
    TestResult? got;
    await pump(tester, onSelected: (v) => got = v);
    await tester.tap(find.text('Fail'));
    expect(got, TestResult.fail);
  });

  testWidgets('tapping the chosen option does not clear it', (tester) async {
    var calls = 0;
    await pump(tester, value: TestResult.pass, onSelected: (_) => calls++);
    await tester.tap(find.text('Pass'));
    expect(calls, 0);
  });

  testWidgets('announces which option is chosen', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, value: TestResult.na, onSelected: (_) {});
    expect(
      tester.getSemantics(find.text('N/A')),
      matchesSemantics(
        label: 'N/A',
        isInMutuallyExclusiveGroup: true,
        hasCheckedState: true,
        isChecked: true,
        hasTapAction: true,
        isButton: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('read-only shows the choice and cannot be changed', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, value: TestResult.fail, onSelected: null);
    await tester.tap(find.text('Pass'));
    await tester.pump();
    expect(
      tester.getSemantics(find.text('Fail')),
      matchesSemantics(
        label: 'Fail',
        isInMutuallyExclusiveGroup: true,
        hasCheckedState: true,
        isChecked: true,
      ),
    );
    handle.dispose();
  });
}
