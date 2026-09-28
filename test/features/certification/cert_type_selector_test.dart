import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/core/theme/app_theme.dart';
import 'package:stat_trac_technical/features/certification/domain/entities/test_template_name.dart';
import 'package:stat_trac_technical/features/certification/presentation/widgets/cert_type_selector.dart';

// Create Certificate offers four types: Test, QA, Commission and
// Decontamination (TestTemplateType 4). The picker offered three, so the
// decontamination designs could never be chosen on the device.
void main() {
  testWidgets('offers all four certificate types', (tester) async {
    tester.view.physicalSize = const Size(1080, 2316);
    tester.view.devicePixelRatio = 1080 / 384;
    addTearDown(tester.view.reset);

    CertType? chosen;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: CertTypeSelector(onSelected: (t) => chosen = t),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(ListTile), findsNWidgets(4));

    await tester.tap(find.text('Decontamination Certificate'));
    expect(chosen, CertType.decontamination);
  });
}
