import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../data/models/certificate_summary.dart';
import '../../domain/entities/test_output.dart';
import '../providers/certificate_providers.dart';

class CertificateDetailScreen extends ConsumerWidget {
  const CertificateDetailScreen({super.key, required this.certId});
  final int certId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(certificateSummaryProvider(certId));
    final outputsAsync = ref.watch(certOutputsProvider(certId));

    return Scaffold(
      appBar: AppBar(
        title: summaryAsync.when(
          data: (s) => Text(s?.displayTitle ?? 'Certificate'),
          loading: () => const Text('Certificate'),
          error: (_, _) => const Text('Certificate'),
        ),
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

// ── Body ──────────────────────────────────────────────────────────────────────

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.summary, required this.outputsAsync});
  final CertificateSummary summary;
  final AsyncValue<List<TestOutput>> outputsAsync;

  Color get _typeColor {
    switch (summary.certType) {
      case 2: return Colors.amber[700]!;
      case 3: return Colors.green[700]!;
      default: return brandTeal;
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
          error: (e, _) =>
              Center(child: Text('Error loading results: $e')),
          data: (outputs) => outputs.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No test results recorded.',
                      style: TextStyle(color: brandGrey)),
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
    final dateStr =
        DateFormat('dd MMM yyyy').format(summary.createdAt.toLocal());

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
                      horizontal: 10, vertical: 4),
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
                        horizontal: 10, vertical: 4),
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
                      horizontal: 8, vertical: 4),
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
            Text(summary.displayTitle,
                style: Theme.of(context).textTheme.titleLarge),
            if (summary.equipmentType != null) ...[
              const SizedBox(height: 4),
              Text(summary.equipmentType!,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: brandGrey)),
            ],
            const SizedBox(height: 8),
            Text(dateStr,
                style: Theme.of(context).textTheme.bodySmall),
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
                child: Text(output.description ?? '',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Text(
                  output.expectedValue ?? '',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: brandGrey),
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
              _ResultChip(label: 'P', color: Colors.green, selected: output.pass),
              const SizedBox(width: 4),
              _ResultChip(label: 'F', color: brandError, selected: output.fail),
              const SizedBox(width: 4),
              _ResultChip(label: 'N/A', color: brandGrey, selected: output.na),
            ],
          ),
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
