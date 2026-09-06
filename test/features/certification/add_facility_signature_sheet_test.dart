import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/core/theme/app_theme.dart';
import 'package:stat_trac_technical/features/certification/presentation/widgets/add_facility_signature_sheet.dart';

void main() {
  // The sheet is laid out under the REAL theme, because the theme is what
  // broke it: filledButtonTheme sets minimumSize Size.fromHeight(48), which
  // is Size(double.infinity, 48). Every FilledButton in this app therefore
  // demands infinite width, and one placed in a Row gets an unbounded
  // constraint and throws — every frame, for ever, which reaches a
  // technician as an app that has hung rather than as an error.
  //
  // A test under a default ThemeData would pass while the app froze.
  testWidgets('opens without a layout exception under the app theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showAddFacilitySignatureSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Facility signature'), findsOneWidget);
    expect(find.text('Save signature'), findsOneWidget);
    expect(find.text('Clear'), findsOneWidget);
  });

  testWidgets('asks for a name before it will save', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showAddFacilitySignatureSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save signature'));
    await tester.pumpAndSettle();

    // Nothing was signed, so that is what it says — and the sheet stays open
    // rather than returning an empty signature.
    expect(find.text('Sign in the box first'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
