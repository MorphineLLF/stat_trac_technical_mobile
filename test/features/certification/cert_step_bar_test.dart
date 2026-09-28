import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/core/theme/app_theme.dart';
import 'package:stat_trac_technical/features/certification/presentation/widgets/cert_step_bar.dart';

// Next lived at the bottom of each wizard step and was cut off on smaller
// phones. It now sits in a bar at the top that does not scroll. Pumped under
// the real appTheme on purpose: its FilledButton is full width, and one in a
// Row demands infinite width — a default ThemeData would hide that hang.
void main() {
  Future<void> pumpBar(
    WidgetTester tester, {
    VoidCallback? onNext,
    String? blockedReason,
  }) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2; // 360 x 640 dp — a small phone
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: MediaQuery.withClampedTextScaling(
          minScaleFactor: 1.3,
          maxScaleFactor: 1.3,
          child: Scaffold(
            body: Column(
              children: [
                CertStepBar(
                  title: 'Certificate Details',
                  onNext: onNext,
                  blockedReason: blockedReason,
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('Next is on screen and pressable on a small phone', (
    tester,
  ) async {
    var pressed = false;
    await pumpBar(tester, onNext: () => pressed = true);

    expect(tester.takeException(), isNull);
    final next = find.widgetWithText(FilledButton, 'Next');
    expect(next, findsOneWidget);

    final rect = tester.getRect(next);
    expect(rect.right, lessThanOrEqualTo(360));
    expect(rect.top, lessThan(100), reason: 'Next belongs at the top');

    await tester.tap(next);
    expect(pressed, isTrue);
  });

  testWidgets('a blocked step says why and cannot be advanced', (tester) async {
    await pumpBar(tester, blockedReason: 'Select a PM task to continue');

    expect(tester.takeException(), isNull);
    expect(find.text('Select a PM task to continue'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Next'),
    );
    expect(button.onPressed, isNull);
  });
}
