import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/auth_state.dart';
import '../../data/models/certificate_summary.dart';
import '../../domain/entities/test_output.dart';
import '../../../../sync/upload/upload_providers.dart';
import '../../data/cert_document_result.dart';
import '../providers/cert_document_providers.dart';
import '../providers/certificate_providers.dart';
import '../widgets/add_facility_signature_sheet.dart';
import '../widgets/result_radio_row.dart';
import '../widgets/signed_chip.dart';
import 'facility_signature_gate.dart';
import 'facility_signature_upload.dart';
import 'tech_signature_gate.dart';

class CertificateDetailScreen extends ConsumerStatefulWidget {
  const CertificateDetailScreen({super.key, required this.certId});
  final int certId;

  @override
  ConsumerState<CertificateDetailScreen> createState() =>
      _CertificateDetailScreenState();
}

class _CertificateDetailScreenState
    extends ConsumerState<CertificateDetailScreen> {
  bool _loadingPdf = false;
  bool _signing = false;

  /// Captures a facility signature for a certificate already issued and
  /// queues it on its own.
  ///
  /// Queued rather than sent directly: a signature taken in a basement must
  /// survive having no signal, and the outbox already knows how to hold work
  /// and drain it later. The batch carries its own key so it cannot replace
  /// anything else waiting there.
  Future<void> _addFacilitySignature(String certificateMobileId) async {
    final signature = await showAddFacilitySignatureSheet(context);
    if (signature == null || !mounted) return;

    setState(() => _signing = true);
    try {
      final upload = facilitySignatureUpload(
        certificateMobileId: certificateMobileId,
        png: signature.png,
        clientName: signature.name,
      );

      final queue = await ref.read(uploadQueueProvider.future);
      await queue.enqueue(upload);

      var sent = false;
      try {
        final worker = await ref.read(uploadWorkerProvider.future);
        final result = await worker.drain();
        sent = result.applied > 0;
      } on Exception {
        // Queued is enough: it goes when there is signal.
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sent
                ? 'Facility signature sent.'
                : 'Facility signature saved — it will go when you have signal.',
          ),
          backgroundColor: sent
              ? const Color(0xFF2E7D32)
              : const Color(0xFFFFB300),
        ),
      );
    } finally {
      if (mounted) setState(() => _signing = false);
    }
  }

  /// Captures the technician's signature for a certificate saved without it —
  /// the wizard closed at the signing step — and queues it on its own.
  ///
  /// Queued before it is recorded on the phone, so a signature the phone
  /// says it has is always one that is on its way.
  Future<void> _addTechSignature(String certificateMobileId) async {
    final png = await showAddTechSignatureSheet(context);
    if (png == null || !mounted) return;

    setState(() => _signing = true);
    try {
      final queue = await ref.read(uploadQueueProvider.future);
      await queue.enqueue(
        techSignatureUpload(certificateMobileId: certificateMobileId, png: png),
      );
      await ref
          .read(certLocalDataSourceProvider)
          .recordTechSignature(certificateMobileId, png);
      ref.invalidate(localTechSignatureProvider(certificateMobileId));
      ref.invalidate(pendingUploadCountProvider);

      var sent = false;
      try {
        final worker = await ref.read(uploadWorkerProvider.future);
        final result = await worker.drain();
        sent = result.applied > 0;
      } on Exception {
        // Queued is enough: it goes when there is signal.
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sent
                ? 'Technician signature sent.'
                : 'Technician signature saved — it will go when you have '
                      'signal.',
          ),
          backgroundColor: sent
              ? const Color(0xFF2E7D32)
              : const Color(0xFFFFB300),
        ),
      );
    } finally {
      if (mounted) setState(() => _signing = false);
    }
  }

  /// The summary, marked technician-signed when this phone holds the
  /// signature itself.
  ///
  /// The server's TestTechSigned covers every certificate once it has synced
  /// back; this covers the gap before that, for a certificate signed here.
  CertificateSummary _withOwnTechSignature(CertificateSummary summary) {
    final mobileId = summary.mobileId;
    if (summary.techSigned || mobileId == null || mobileId.isEmpty) {
      return summary;
    }
    final local = ref.watch(localTechSignatureProvider(mobileId)).value;
    return local?.techSigned == true
        ? summary.copyWith(techSigned: true)
        : summary;
  }

  /// The prompt to sign, or null when there is nothing to offer.
  ///
  /// Shown in the page rather than as another AppBar icon: an unsigned
  /// certificate is something the technician has to notice, and on a phone
  /// the AppBar is already full.
  Widget? _techSignPrompt(CertificateSummary summary) {
    final mobileId = summary.mobileId;
    if (mobileId == null || mobileId.isEmpty) return null;

    final local = ref.watch(localTechSignatureProvider(mobileId));
    if (!local.hasValue) return null;

    final auth = ref.watch(authProvider);
    final state = techSignatureState(
      mobileId: mobileId,
      local: local.value,
      currentUserId: auth is AuthAuthenticated ? auth.user.id : null,
    );
    if (state != TechSignatureState.available) return null;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Not signed by the technician',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            const Text('This certificate was saved without your signature.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _signing ? null : () => _addTechSignature(mobileId),
              icon: const Icon(Icons.draw_outlined),
              label: const Text('Sign as technician'),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the certificate PDF, from the cache when there is one.
  ///
  /// The server is the only renderer — paper and screen are built from one
  /// view there, and a second renderer on the device would drift from it
  /// invisibly. So the device fetches once and keeps it: a cached certificate
  /// opens in a basement with no signal at all.
  Future<void> _viewPdf(int serverId) async {
    setState(() => _loadingPdf = true);
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final certDir = Directory('${cacheDir.path}/certs');
      if (!certDir.existsSync()) certDir.createSync(recursive: true);
      final filePath = '${certDir.path}/cert_$serverId.pdf';

      if (!File(filePath).existsSync()) {
        final credentials = await ref.read(
          certDocumentCredentialsProvider.future,
        );
        if (credentials == null) {
          _sayPdf('Sign in again to open this certificate.', isError: true);
          return;
        }

        final result = await ref
            .read(certDocumentClientProvider)
            .fetchPdf(
              company: credentials.company,
              deviceToken: credentials.token,
              certificateId: serverId,
            );

        switch (result) {
          case CertPdfBytes(:final bytes):
            await File(filePath).writeAsBytes(bytes);
          // Not a failure: the certificate has not reached the server yet, so
          // there is nothing to render. Saying so is the difference between
          // "wait for signal" and "something is broken".
          case CertPdfNotReady():
            _sayPdf(
              'This certificate has not reached the server yet — it needs a '
              'moment of signal first.',
            );
            return;
          case CertPdfRefused(:final message):
            _sayPdf(message, isError: true);
            return;
          case CertPdfUnavailable(:final message):
            _sayPdf(message);
            return;
        }
      }

      final opened = await OpenFile.open(filePath);
      if (opened.type != ResultType.done && mounted) {
        _sayPdf('Could not open PDF: ${opened.message}', isError: true);
      }
    } finally {
      if (mounted) setState(() => _loadingPdf = false);
    }
  }

  void _sayPdf(String message, {bool isError = false}) {
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

  /// Emails the certificate to an address the technician types.
  ///
  /// The recipient is typed because there is nowhere to read it from: no
  /// contact table and no email column reach this device, and the office
  /// types it too.
  ///
  /// A 200 means the mail left. It does not promise the server's audit row
  /// exists — that write can fail afterwards and is still answered 200,
  /// because answering "failed" would have the technician send the same
  /// certificate twice.
  Future<void> _showEmailDialog(int serverId) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _EmailDialog(
        serverId: serverId,
        onSend: (email) async {
          final credentials = await ref.read(
            certDocumentCredentialsProvider.future,
          );
          if (credentials == null) {
            throw StateError('Sign in again to email this certificate.');
          }

          final result = await ref
              .read(certDocumentClientProvider)
              .email(
                company: credentials.company,
                deviceToken: credentials.token,
                certificateId: serverId,
                to: email,
              );

          switch (result) {
            case CertEmailSent():
              return;
            // Both are shown to the technician as the server's own sentence.
            // A refusal will never succeed and a fault might, but neither is
            // retried behind their back from a dialog they are looking at.
            case CertEmailRefused(:final message):
              throw StateError(message);
            case CertEmailUnavailable(:final message):
              throw StateError(message);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(certificateSummaryProvider(widget.certId));
    final outputsAsync = ref.watch(certOutputsProvider(widget.certId));

    final serverId = summaryAsync.asData?.value?.certificateNo;
    final isSynced = serverId != null;

    return Scaffold(
      appBar: AppBar(
        title: summaryAsync.when(
          data: (s) => Text(s?.displayTitle ?? 'Certificate'),
          loading: () => const Text('Certificate'),
          error: (_, _) => const Text('Certificate'),
        ),
        actions: [
          // ── View PDF ─────────────────────────────────────────
          Tooltip(
            message: isSynced ? 'View PDF' : 'Sync first to generate PDF',
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
              onPressed: isSynced && !_loadingPdf
                  ? () => _viewPdf(serverId)
                  : null,
            ),
          ),
          // ── Add facility signature ────────────────────────────
          // Signing is the one write allowed after a certificate is issued.
          // A certificate can sit issued and unsigned indefinitely, so this
          // fills that gap rather than working around a rule.
          summaryAsync.maybeWhen(
            data: (s) {
              // Gated on the design and on whether anybody has signed. The
              // server refuses a client signature the design never asked for,
              // and refuses a second one outright — and a technician who has
              // watched somebody sign believes it is filed. Taking a real
              // signature and discarding it is worse than not offering.
              final state = facilitySignatureState(
                testType: s?.testType,
                clientNameSignature: s?.clientNameSignature,
                mobileId: s?.mobileId,
              );
              final canSign =
                  state == FacilitySignatureState.available && !_signing;

              return Tooltip(
                message: facilitySignatureTooltip(state),
                child: IconButton(
                  icon: Icon(
                    state == FacilitySignatureState.alreadySigned
                        ? Icons.how_to_reg
                        : Icons.draw_outlined,
                  ),
                  onPressed: canSign
                      ? () => _addFacilitySignature(s!.mobileId!)
                      : null,
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          // ── Email ─────────────────────────────────────────────
          Tooltip(
            message: isSynced ? 'Email certificate' : 'Sync first to email',
            child: IconButton(
              icon: const Icon(Icons.email_outlined),
              onPressed: isSynced ? () => _showEmailDialog(serverId) : null,
            ),
          ),
        ],
      ),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (summary) => summary == null
            ? const Center(child: Text('Certificate not found'))
            : _DetailBody(
                summary: _withOwnTechSignature(summary),
                outputsAsync: outputsAsync,
                signPrompt: _techSignPrompt(summary),
              ),
      ),
    );
  }
}

// ── Email dialog ──────────────────────────────────────────────────────────────

class _EmailDialog extends StatefulWidget {
  const _EmailDialog({required this.serverId, required this.onSend});
  final int serverId;
  final Future<void> Function(String email) onSend;

  @override
  State<_EmailDialog> createState() => _EmailDialogState();
}

class _EmailDialogState extends State<_EmailDialog> {
  final _controller = TextEditingController();
  bool _sending = false;
  String? _error;

  bool get _valid =>
      _controller.text.contains('@') && _controller.text.contains('.');

  Future<void> _submit() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onSend(_controller.text.trim());
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Certificate emailed to ${_controller.text.trim()}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Email Certificate'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Recipient email',
              hintText: 'name@example.com',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            onChanged: (_) => setState(() {}),
            enabled: !_sending,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _valid && !_sending ? _submit : null,
          child: _sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send'),
        ),
      ],
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.summary,
    required this.outputsAsync,
    this.signPrompt,
  });
  final CertificateSummary summary;
  final AsyncValue<List<TestOutput>> outputsAsync;
  final Widget? signPrompt;

  Color get _typeColor {
    switch (summary.certType) {
      case 2:
        return Colors.amber[700]!;
      case 3:
        return Colors.green[700]!;
      case 4:
        return Colors.purple[700]!;
      default:
        return brandTeal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ?signPrompt,
        _HeaderCard(summary: summary, typeColor: _typeColor),
        const SizedBox(height: 8),
        outputsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error loading results: $e')),
          data: (outputs) => outputs.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No test results recorded.',
                    style: TextStyle(color: brandGrey),
                  ),
                )
              : _OutputsSection(outputs: outputs),
        ),
      ],
    );
  }
}

// ── Header card ───────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.summary, required this.typeColor});
  final CertificateSummary summary;
  final Color typeColor;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat(
      'dd MMM yyyy',
    ).format(summary.createdAt.toLocal());

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: typeColor.withAlpha(20),
                    border: Border.all(color: typeColor),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    summary.typeLabel,
                    style: TextStyle(
                      color: typeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (summary.complianceLabel.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: summary.complianceColor.withAlpha(20),
                      border: Border.all(color: summary.complianceColor),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      summary.complianceLabel,
                      style: TextStyle(
                        color: summary.complianceColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: summary.isPending
                        ? Colors.amber[50]
                        : Colors.green[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    summary.isPending ? 'Pending sync' : 'Synced',
                    style: TextStyle(
                      color: summary.isPending
                          ? Colors.amber[800]
                          : Colors.green[700],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            // On a line of their own: beside the type, compliance and sync
            // chips they overflow a phone.
            if (signedChips(summary).isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: signedChips(summary, large: true),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              summary.displayTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (summary.equipmentType != null) ...[
              const SizedBox(height: 4),
              Text(
                summary.equipmentType!,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: brandGrey),
              ),
            ],
            const SizedBox(height: 8),
            Text(dateStr, style: Theme.of(context).textTheme.bodySmall),
            if (summary.pmTaskDescription != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'PM Task: ',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: brandGrey),
                  ),
                  Text(
                    summary.pmTaskDescription!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Test outputs ──────────────────────────────────────────────────────────────

class _OutputsSection extends StatelessWidget {
  const _OutputsSection({required this.outputs});
  final List<TestOutput> outputs;

  @override
  Widget build(BuildContext context) {
    final sections = <String, List<TestOutput>>{};
    for (final o in outputs) {
      final section = o.descriptionId ?? 'General';
      sections.putIfAbsent(section, () => []).add(o);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in sections.entries) ...[
          _SectionHeader(title: entry.key),
          for (final output in entry.value) _OutputRow(output: output),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: brandTeal.withAlpha(20),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: brandTeal,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _OutputRow extends StatelessWidget {
  const _OutputRow({required this.output});
  final TestOutput output;

  /// The Actual column's width on Create Certificate, so a line reads the
  /// same here as when it was filled in.
  static const double _actualWidth = 100;

  static String _orDash(String? v) {
    final t = v?.trim();
    return t == null || t.isEmpty ? '-' : t;
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      color: brandGrey,
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );
    final valueStyle = Theme.of(context).textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The same headings as Create Certificate, on every line.
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Text('Test Description', style: labelStyle),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Text(
                  'Test Value',
                  style: labelStyle,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: _actualWidth,
                child: Text(
                  'Actual',
                  style: labelStyle,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(output.description ?? '', style: valueStyle),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Text(
                  _orDash(output.expectedValue),
                  style: valueStyle,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: _actualWidth,
                child: Text(
                  _orDash(output.actualValue),
                  style: valueStyle?.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ResultRadioRow(
            value: output.pass
                ? TestResult.pass
                : output.fail
                ? TestResult.fail
                : output.na
                ? TestResult.na
                : null,
            onSelected: null,
          ),
          if (output.notes != null && output.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              output.notes!,
              style: TextStyle(fontSize: 12, color: brandGrey),
            ),
          ],
          const Divider(height: 1),
        ],
      ),
    );
  }
}
