import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/core/documents/document_result.dart';
import 'package:stat_trac_technical/core/documents/email_document_dialog.dart';
import 'package:stat_trac_technical/core/theme/app_theme.dart';

Future<void> _open(
  WidgetTester t, {
  DocEmailDefaults? defaults,
  Future<void> Function(String, String?, String?)? onSend,
}) async {
  await t.pumpWidget(
    MaterialApp(
      theme: appTheme,
      home: Builder(
        builder: (c) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<void>(
              context: c,
              builder: (_) => EmailDocumentDialog(
                title: 'Email Work Order',
                sentLabel: 'Work order',
                loadDefaults: () async => defaults,
                onSend: onSend ?? (_, _, _) async {},
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
}

FilledButton _send(WidgetTester t) =>
    t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Send'));

void main() {
  testWidgets('shows its title; Send waits for an address', (t) async {
    await _open(t);
    expect(find.text('Email Work Order'), findsOneWidget);
    expect(_send(t).onPressed, isNull);

    await t.enterText(find.byType(TextField).first, 'sister@hospital.example');
    await t.pump();
    expect(_send(t).onPressed, isNotNull);
  });

  testWidgets("opens with the sender's CC and sign-off", (t) async {
    await _open(
      t,
      defaults: const DocEmailDefaults(
        cc: 'office@co.example',
        signature: 'Athi',
      ),
    );
    expect(find.text('office@co.example'), findsOneWidget);
    expect(find.textContaining('Athi'), findsOneWidget);
  });

  testWidgets('a refusal stays in the box', (t) async {
    await _open(
      t,
      onSend: (_, _, _) async => throw StateError('an address is needed'),
    );
    await t.enterText(find.byType(TextField).first, 'a@b.example');
    await t.pump();
    await t.tap(find.text('Send'));
    await t.pumpAndSettle();
    expect(find.text('Email Work Order'), findsOneWidget);
    expect(find.text('an address is needed'), findsOneWidget);
  });

  testWidgets('a send closes the box and names what went', (t) async {
    String? sentTo;
    await _open(t, onSend: (to, _, _) async => sentTo = to);
    await t.enterText(find.byType(TextField).first, ' a@b.example ');
    await t.pump();
    await t.tap(find.text('Send'));
    await t.pumpAndSettle();
    expect(sentTo, 'a@b.example');
    expect(find.text('Email Work Order'), findsNothing);
    expect(find.text('Work order emailed to a@b.example'), findsOneWidget);
  });
}
