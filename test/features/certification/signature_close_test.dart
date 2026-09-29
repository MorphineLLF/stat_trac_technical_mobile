import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/core/theme/app_theme.dart';
import 'package:stat_trac_technical/features/certification/presentation/widgets/cert_signature_step.dart';

// Close sits beside Issue Certificate. The certificate is already saved and
// issued by then, so closing leaves it unsigned — it asks first, and the
// signature can still be added from the certificate afterwards.
void main() {
  Future<void> pump(WidgetTester tester, VoidCallback onClose) async {
    // The reference phone: 384 dp wide. Both buttons are full-width by theme,
    // so side by side is exactly where a layout exception would come from.
    tester.view.physicalSize = const Size(1080, 2316);
    tester.view.devicePixelRatio = 1080 / 384;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: CertSignatureStep(
            requiresCustomerSig: true,
            onSigned: (_) {},
            onClose: onClose,
          ),
        ),
      ),
    );
  }

  testWidgets('sits beside Issue Certificate without a layout exception', (
    tester,
  ) async {
    await pump(tester, () {});
    await tester.ensureVisible(find.text('Close'));

    expect(tester.takeException(), isNull);
    // The buttons, not their labels: an icon shifts a label's position.
    final close = find.ancestor(
      of: find.text('Close'),
      matching: find.byType(OutlinedButton),
    );
    final issue = find.ancestor(
      of: find.text('Issue Certificate'),
      matching: find.byType(FilledButton),
    );
    expect(tester.getCenter(close).dy, closeTo(tester.getCenter(issue).dy, 1));
    expect(tester.getTopRight(close).dx, lessThan(tester.getTopLeft(issue).dx));
  });

  testWidgets('asks before closing, and closes on confirm', (tester) async {
    var closed = false;
    await pump(tester, () => closed = true);

    await tester.ensureVisible(find.text('Close'));
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Close without signing?'), findsOneWidget);
    expect(closed, isFalse);

    await tester.tap(find.text('Close without signing'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
  });

  testWidgets('stays on the step when the confirm is cancelled', (
    tester,
  ) async {
    var closed = false;
    await pump(tester, () => closed = true);

    await tester.ensureVisible(find.text('Close'));
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep signing'));
    await tester.pumpAndSettle();

    expect(closed, isFalse);
    expect(find.text('Issue Certificate'), findsOneWidget);
  });
}
