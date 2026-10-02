import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/core/documents/document_result.dart';
import 'package:stat_trac_technical/core/theme/app_theme.dart';
import 'package:stat_trac_technical/features/work_orders/presentation/providers/work_order_document_providers.dart';
import 'package:stat_trac_technical/features/work_orders/presentation/widgets/work_order_document_actions.dart';

Future<void> _pump(WidgetTester t, {int? trackId}) async {
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        // Signed out: the box opens with no defaults, nothing is fetched.
        workOrderDocumentCredentialsProvider.overrideWith((ref) async => null),
      ],
      child: MaterialApp(
        theme: appTheme,
        home: Scaffold(
          appBar: AppBar(actions: [WorkOrderDocumentActions(trackId: trackId)]),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

IconButton _button(WidgetTester t, IconData icon) =>
    t.widget<IconButton>(find.widgetWithIcon(IconButton, icon));

void main() {
  testWidgets('a queued job: both disabled, says Sync first', (t) async {
    await _pump(t);
    expect(_button(t, Icons.picture_as_pdf_outlined).onPressed, isNull);
    expect(_button(t, Icons.email_outlined).onPressed, isNull);
    expect(find.byTooltip('Sync first'), findsNWidgets(2));
  });

  testWidgets('a synced job: both enabled; Email opens the box', (t) async {
    await _pump(t, trackId: 7144);
    expect(_button(t, Icons.picture_as_pdf_outlined).onPressed, isNotNull);
    expect(_button(t, Icons.email_outlined).onPressed, isNotNull);

    await t.tap(find.byIcon(Icons.email_outlined));
    await t.pumpAndSettle();
    expect(find.text('Email Work Order'), findsOneWidget);
  });

  group('which PDF opens', () {
    final bytes = DocPdfBytes(Uint8List.fromList([1]));
    const offline = DocPdfUnavailable(0, 'Cannot reach the server.');

    // A work order can change after it was printed; an issued certificate
    // cannot. So a fresh copy always wins over the cache.
    test('fresh bytes are saved and opened, cache or not', () {
      expect(pdfToOpen(fetched: bytes, cached: true), PdfChoice.saveAndOpen);
      expect(pdfToOpen(fetched: bytes, cached: false), PdfChoice.saveAndOpen);
    });

    test('no signal opens the cached copy when there is one', () {
      expect(pdfToOpen(fetched: offline, cached: true), PdfChoice.openCached);
      expect(pdfToOpen(fetched: offline, cached: false), PdfChoice.say);
    });

    // A refusal is the server's answer about this work order now; an old copy
    // would contradict it.
    test('a refusal is said, never covered by the cache', () {
      expect(
        pdfToOpen(fetched: const DocPdfRefused(404, 'no'), cached: true),
        PdfChoice.say,
      );
    });
  });
}
