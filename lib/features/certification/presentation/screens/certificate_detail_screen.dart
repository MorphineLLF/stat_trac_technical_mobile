import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../data/models/certificate_summary.dart';
import '../../domain/entities/test_output.dart';
import '../../../../sync/upload/upload_providers.dart';
import '../providers/certificate_providers.dart';
import '../widgets/add_facility_signature_sheet.dart';
import 'facility_signature_upload.dart';

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

  Future<void> _viewPdf(int serverId) async {
    setState(() => _loadingPdf = true);
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final certDir = Directory('${cacheDir.path}/certs');
      if (!certDir.existsSync()) certDir.createSync(recursive: true);
      final filePath = '${certDir.path}/cert_$serverId.pdf';

      if (!File(filePath).existsSync()) {
        final bytes = await ref
            .read(certificateRepositoryProvider)
            .fetchCertificatePdf(serverId);
        await File(filePath).writeAsBytes(bytes);
      }

      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open PDF: ${result.message}')),
        );
      }
    } catch (e, st) {
      debugPrint('PDF error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingPdf = false);
    }
  }

  Future<void> _showEmailDialog(int serverId) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _EmailDialog(
        serverId: serverId,
        onSend: (email) async {
          await ref
              .read(certificateRepositoryProvider)
              .emailCertificate(serverId, email);
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
            data: (s) => Tooltip(
              message: s?.mobileId == null
                  ? 'This certificate cannot be signed from the app'
                  : 'Add facility signature',
              child: IconButton(
                icon: const Icon(Icons.draw_outlined),
                onPressed: s?.mobileId == null || _signing
                    ? null
                    : () => _addFacilitySignature(s!.mobileId!),
              ),
            ),
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
            : _DetailBody(summary: summary, outputsAsync: outputsAsync),
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
  const _DetailBody({required this.summary, required this.outputsAsync});
  final CertificateSummary summary;
  final AsyncValue<List<TestOutput>> outputsAsync;

  Color get _typeColor {
    switch (summary.certType) {
      case 2:
        return Colors.amber[700]!;
      case 3:
        return Colors.green[700]!;
      default:
        return brandTeal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  output.description ?? '',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Text(
                  output.expectedValue ?? '',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: brandGrey),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Text(
                  output.actualValue ?? '—',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _ResultChip(
                label: 'P',
                color: Colors.green,
                selected: output.pass,
              ),
              const SizedBox(width: 4),
              _ResultChip(label: 'F', color: brandError, selected: output.fail),
              const SizedBox(width: 4),
              _ResultChip(label: 'N/A', color: brandGrey, selected: output.na),
            ],
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

class _ResultChip extends StatelessWidget {
  const _ResultChip({
    required this.label,
    required this.color,
    required this.selected,
  });
  final String label;
  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: selected ? color : color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
