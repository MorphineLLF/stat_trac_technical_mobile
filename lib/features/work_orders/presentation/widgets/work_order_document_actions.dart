import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/documents/document_result.dart';
import '../../../../core/documents/email_document_dialog.dart';
import '../providers/work_order_document_providers.dart';

enum PdfChoice { saveAndOpen, openCached, say }

/// What to do with the server's answer for a work order sheet.
///
/// **Unlike an issued certificate, a work order can change after it was
/// printed** — the office adds parts, closes it. So a fresh copy always wins,
/// and the cached one is only for when the server cannot be reached at all.
/// A refusal is the server's answer now and is never covered by an old copy.
PdfChoice pdfToOpen({required DocPdfResult fetched, required bool cached}) =>
    switch (fetched) {
      DocPdfBytes() => PdfChoice.saveAndOpen,
      DocPdfUnavailable() when cached => PdfChoice.openCached,
      _ => PdfChoice.say,
    };

/// View PDF and Email, for the app bar of a work order.
///
/// A job still in the queue has no `RepairTrackID`, so there is nothing on the
/// server to render — both are disabled and say so.
class WorkOrderDocumentActions extends ConsumerStatefulWidget {
  const WorkOrderDocumentActions({super.key, this.trackId});

  final int? trackId;

  @override
  ConsumerState<WorkOrderDocumentActions> createState() =>
      _WorkOrderDocumentActionsState();
}

class _WorkOrderDocumentActionsState
    extends ConsumerState<WorkOrderDocumentActions> {
  bool _loadingPdf = false;

  Future<void> _viewPdf(int trackId) async {
    setState(() => _loadingPdf = true);
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final dir = Directory('${cacheDir.path}/work_orders');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final file = File('${dir.path}/wo_$trackId.pdf');

      final credentials = await ref.read(
        workOrderDocumentCredentialsProvider.future,
      );
      final DocPdfResult fetched = credentials == null
          ? const DocPdfRefused(401, 'Sign in again to open this work order.')
          : await ref
                .read(workOrderDocumentClientProvider)
                .fetchPdf(
                  company: credentials.company,
                  deviceToken: credentials.token,
                  trackId: trackId,
                );

      switch (pdfToOpen(fetched: fetched, cached: file.existsSync())) {
        case PdfChoice.saveAndOpen:
          await file.writeAsBytes((fetched as DocPdfBytes).bytes);
        case PdfChoice.openCached:
          break;
        case PdfChoice.say:
          _say(switch (fetched) {
            DocPdfNotReady() =>
              'This work order has not reached the server yet — it needs a '
                  'moment of signal first.',
            DocPdfRefused(:final message) => message,
            DocPdfUnavailable(:final message) => message,
            DocPdfBytes() => '',
          }, isError: fetched is DocPdfRefused);
          return;
      }

      final opened = await OpenFile.open(file.path);
      if (opened.type != ResultType.done) {
        _say('Could not open PDF: ${opened.message}', isError: true);
      }
    } finally {
      if (mounted) setState(() => _loadingPdf = false);
    }
  }

  void _say(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : const Color(0xFFFFB300),
      ),
    );
  }

  Future<void> _email(int trackId) async {
    await showDialog<void>(
      context: context,
      builder: (_) => EmailDocumentDialog(
        title: 'Email Work Order',
        sentLabel: 'Work order',
        loadDefaults: () async {
          final c = await ref.read(workOrderDocumentCredentialsProvider.future);
          if (c == null) return null;
          return ref
              .read(workOrderDocumentClientProvider)
              .fetchEmailDefaults(
                company: c.company,
                deviceToken: c.token,
                trackId: trackId,
              );
        },
        onSend: (to, cc, body) async {
          final c = await ref.read(workOrderDocumentCredentialsProvider.future);
          if (c == null) {
            throw StateError('Sign in again to email this work order.');
          }
          final result = await ref
              .read(workOrderDocumentClientProvider)
              .email(
                company: c.company,
                deviceToken: c.token,
                trackId: trackId,
                to: to,
                cc: cc,
                body: body,
              );
          switch (result) {
            case DocEmailSent():
              return;
            // Both shown as the server's own sentence, inside the box.
            case DocEmailRefused(:final message):
              throw StateError(message);
            case DocEmailUnavailable(:final message):
              throw StateError(message);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.trackId;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: id == null ? 'Sync first' : 'View PDF',
          child: IconButton(
            icon: _loadingPdf
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            onPressed: id != null && !_loadingPdf ? () => _viewPdf(id) : null,
          ),
        ),
        Tooltip(
          message: id == null ? 'Sync first' : 'Email work order',
          child: IconButton(
            icon: const Icon(Icons.email_outlined),
            onPressed: id != null ? () => _email(id) : null,
          ),
        ),
      ],
    );
  }
}
