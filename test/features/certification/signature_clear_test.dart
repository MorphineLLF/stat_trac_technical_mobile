import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signature/signature.dart';
import 'package:stat_trac_technical/core/theme/app_theme.dart';
import 'package:stat_trac_technical/features/certification/presentation/widgets/cert_signature_step.dart';

// A signature could not be taken back — a slip of the pen meant leaving the
// certificate. Each pad now has Clear. And the facility contact field showed
// the grey page through it; it is white like the pads.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    ValueChanged<SignatureResult>? onSigned,
  }) async {
    tester.view.physicalSize = const Size(1080, 2316);
    tester.view.devicePixelRatio = 1080 / 384;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: CertSignatureStep(
            requiresCustomerSig: true,
            onSigned: onSigned ?? (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets('each pad has a Clear button', (tester) async {
    await pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(TextButton, 'Clear'), findsNWidgets(2));
  });

  testWidgets('a cleared signature counts as not signed', (tester) async {
    var signed = false;
    await pump(tester, onSigned: (_) => signed = true);

    await tester.drag(find.byType(Signature).first, const Offset(120, 20));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Clear').first);
    await tester.pump();

    await tester.ensureVisible(find.text('Issue Certificate'));
    await tester.tap(find.text('Issue Certificate'));
    await tester.pump();

    expect(signed, isFalse);
    expect(find.text('Technician signature is required'), findsOneWidget);
  });

  testWidgets('the facility contact field is white', (tester) async {
    await pump(tester);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration?.filled, isTrue);
    expect(field.decoration?.fillColor, Colors.white);
  });
}
