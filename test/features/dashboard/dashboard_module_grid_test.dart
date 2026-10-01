import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/core/theme/app_theme.dart';
import 'package:stat_trac_technical/features/dashboard/presentation/screens/dashboard_screen.dart';

// This app is designed for phones only. The module grid split each tile's
// width between two icon buttons, so on a Galaxy S23 Ultra (384 dp wide,
// font scale 1.15) "Create" broke mid-word into "Crea / te".
void main() {
  // PM work orders belong to the PM module, which the phone does not do yet.
  testWidgets('work order and certificate actions can be pressed; Worklist and PM cannot', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2316);
    tester.view.devicePixelRatio = 1080 / 384;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: const Scaffold(
          body: SingleChildScrollView(child: DashboardModuleGrid()),
        ),
      ),
    );

    bool pressable(String label, int index) {
      final button = tester.widget<ButtonStyleButton>(
        find
            .ancestor(
              of: find.text(label).at(index),
              matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
            )
            .first,
      );
      return button.onPressed != null;
    }

    // Tree order — View: Worklist, Work Order, PM, Certificate.
    // Create: Work Order, PM, Certificate.
    expect(pressable('View', 0), isFalse, reason: 'Worklist');
    expect(pressable('View', 1), isTrue, reason: 'Work Order');
    expect(pressable('View', 2), isFalse, reason: 'PM Work Order');
    expect(pressable('View', 3), isTrue, reason: 'Certificate');
    expect(pressable('Create', 0), isTrue, reason: 'Work Order');
    expect(pressable('Create', 1), isFalse, reason: 'PM Work Order');
    expect(pressable('Create', 2), isTrue, reason: 'Certificate');
    expect(find.text('Coming soon'), findsNWidgets(2));
  });

  for (final scale in [1.0, 1.15, 1.3]) {
    testWidgets('action labels stay on one line on a phone at text scale '
        '$scale', (tester) async {
      tester.view.physicalSize = const Size(1080, 2316);
      tester.view.devicePixelRatio = 1080 / 384;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: MediaQuery.withClampedTextScaling(
            minScaleFactor: scale,
            maxScaleFactor: scale,
            child: const Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: DashboardModuleGrid(),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);

      for (final label in ['Create', 'View']) {
        for (final element in find.text(label).evaluate()) {
          final height = tester.getSize(find.byWidget(element.widget)).height;
          // Buttons use a 12 px label; two lines would be at least twice that.
          expect(
            height,
            lessThan(12 * scale * 2),
            reason: '"$label" wrapped onto a second line',
          );
        }
      }
    });
  }
}
