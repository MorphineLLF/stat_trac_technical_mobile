import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/core/theme/app_theme.dart';
import 'package:stat_trac_technical/features/certification/presentation/widgets/actual_value_field.dart';

void main() {
  Future<void> pump(WidgetTester tester, {ValueChanged<String>? onChanged}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: Center(
            child: ActualValueField(
              initialValue: null,
              onChanged: onChanged ?? (_) {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('opens the normal keyboard, not the number keypad', (
    tester,
  ) async {
    await pump(tester);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.keyboardType.index, TextInputType.text.index);
  });

  testWidgets('a word is passed on as typed', (tester) async {
    String? got;
    await pump(tester, onChanged: (v) => got = v);
    await tester.enterText(find.byType(TextField), 'Present');
    expect(got, 'Present');
  });

  testWidgets('a number is passed on as typed', (tester) async {
    String? got;
    await pump(tester, onChanged: (v) => got = v);
    await tester.enterText(find.byType(TextField), '-12.5');
    expect(got, '-12.5');
  });
}
