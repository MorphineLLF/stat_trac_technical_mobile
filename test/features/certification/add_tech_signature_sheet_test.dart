import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/core/theme/app_theme.dart';
import 'package:stat_trac_technical/features/certification/presentation/widgets/add_facility_signature_sheet.dart';

Widget _host() => MaterialApp(
  // The real theme: under a default ThemeData a full-width FilledButton in
  // the wrong place passes here and hangs the app.
  theme: appTheme,
  home: Scaffold(
    body: Builder(
      builder: (context) => ElevatedButton(
        onPressed: () => showAddTechSignatureSheet(context),
        child: const Text('open'),
      ),
    ),
  ),
);

void main() {
  testWidgets('opens without a layout exception under the app theme', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Technician signature'), findsOneWidget);
    expect(find.text('Save signature'), findsOneWidget);
  });

  // The technician's name comes from the login, on the server. A field for
  // it would be a name the server ignores.
  testWidgets('asks for no name', (tester) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('says inside the sheet that nothing was signed', (tester) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save signature'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Sign in the box first'),
      ),
      findsOneWidget,
    );
  });
}
