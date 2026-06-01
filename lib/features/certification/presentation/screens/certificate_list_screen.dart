import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../data/models/certificate_summary.dart';
import '../providers/certificate_providers.dart';
import 'certificate_detail_screen.dart';

class CertificateListScreen extends ConsumerWidget {
  const CertificateListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final certsAsync = ref.watch(certificateListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Certificates')),
      body: certsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
        data: (certs) => certs.isEmpty
            ? const _EmptyView()
            : ListView.builder(
                itemCount: certs.length,
                itemBuilder: (_, i) => _CertTile(cert: certs[i]),
              ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_outlined, size: 64, color: brandGrey),
          const SizedBox(height: 16),
          Text('No certificates yet',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Tap Create Certificate to get started',
            style: TextStyle(color: brandGrey),
          ),
        ],
      ),
    );
  }
}

// ── List tile ─────────────────────────────────────────────────────────────────

class _CertTile extends StatelessWidget {
  const _CertTile({required this.cert});
  final CertificateSummary cert;

  Color get _typeColor {
    switch (cert.certType) {
      case 2: return Colors.amber[700]!;
      case 3: return Colors.green[700]!;
      default: return brandTeal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('dd MMM yyyy').format(cert.createdAt.toLocal());

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _typeColor.withAlpha(20),
            border: Border.all(color: _typeColor),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            cert.typeLabel,
            style: TextStyle(
              color: _typeColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        title: Text(
          cert.certName ?? 'Unknown template',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (cert.equipmentType != null)
              Text(cert.equipmentType!,
                  style: TextStyle(color: brandGrey)),
            Row(
              children: [
                Text(dateStr,
                    style: Theme.of(context).textTheme.bodySmall),
                if (cert.isPending) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'PENDING',
                      style: TextStyle(
                        color: Colors.amber[800],
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CertificateDetailScreen(certId: cert.id),
          ),
        ),
      ),
    );
  }
}
