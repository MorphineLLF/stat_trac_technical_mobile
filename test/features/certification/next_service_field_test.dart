import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:stat_trac_technical/core/theme/app_theme.dart';
import 'package:stat_trac_technical/features/certification/presentation/widgets/next_service_field.dart';

void main() {
  // No warning: an empty next service date shows the test date, plainly.
  testWidgets('shows the test date, not a warning, when nothing is chosen', (
    tester,
  ) async {
    final testDate = DateTime(2026, 9, 29);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: NextServiceField(
            testDate: testDate,
            value: null,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Tap to choose a date'), findsNothing);
    expect(
      find.text(DateFormat('dd MMM yyyy').format(testDate)),
      findsOneWidget,
    );
    final icon = tester.widget<Icon>(find.byIcon(Icons.event_outlined));
    expect(icon.color, brandTeal);
  });
}
