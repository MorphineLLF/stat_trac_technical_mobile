import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../data/models/certificate_summary.dart';
import '../providers/certificate_providers.dart';
import 'certificate_detail_screen.dart';
import 'certificate_search.dart';

class CertificateListScreen extends ConsumerStatefulWidget {
  const CertificateListScreen({super.key});

  @override
  ConsumerState<CertificateListScreen> createState() =>
      _CertificateListScreenState();
}

class _CertificateListScreenState extends ConsumerState<CertificateListScreen> {
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final certsAsync = ref.watch(certificateListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Certificates')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _search = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search hospital, cert no., equipment',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: certsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  'Error: $e',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              data: (certs) {
                if (certs.isEmpty) return const _EmptyView();

                final matches = [
                  for (final c in certs)
                    if (certificateMatchesSearch(c, _search)) c,
                ];

                // An empty result and an empty list are different states and
                // must not look alike: one means there are no certificates,
                // the other means this search found none of them.
                if (matches.isEmpty) {
                  return _NoMatchesView(search: _search);
                }

                return ListView.builder(
                  itemCount: matches.length,
                  itemBuilder: (_, i) => _CertTile(cert: matches[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Nothing matched ───────────────────────────────────────────────────────────

class _NoMatchesView extends StatelessWidget {
  const _NoMatchesView({required this.search});
  final String search;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 56, color: brandGrey),
            const SizedBox(height: 12),
            Text(
              'No certificate matches "$search"',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
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
          Text(
            'No certificates yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
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
    final dateStr = DateFormat('dd MMM yyyy').format(cert.createdAt.toLocal());

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
        // The hospital leads. A technician looking for a certificate knows
        // which facility they were standing in long before they remember what
        // the template was called, so the facility is the headline and the
        // certificate's own name sits under it, smaller.
        title: Text(
          cert.hospital ?? 'No facility recorded',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: cert.hospital == null ? brandGrey : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cert.displayTitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: brandDark,
              ),
            ),
            Text(cert.equipmentType ?? '—', style: TextStyle(color: brandGrey)),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(dateStr, style: Theme.of(context).textTheme.bodySmall),
                // The certificate number is how the office refers to this
                // document, so it leads. When there is none it says so rather
                // than showing nothing: a missing number and a number that
                // failed to arrive look identical otherwise, and that is
                // exactly the confusion this list caused before.
                Text(
                  cert.certificateNo != null
                      ? 'Cert #${cert.certificateNo}'
                      : 'No cert no. yet',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cert.certificateNo != null ? brandDark : brandGrey,
                    fontWeight: cert.certificateNo != null
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontStyle: cert.certificateNo != null
                        ? FontStyle.normal
                        : FontStyle.italic,
                  ),
                ),
                if (cert.isPending)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
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
                if (cert.complianceLabel.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: cert.complianceColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: cert.complianceColor.withAlpha(120),
                      ),
                    ),
                    child: Text(
                      cert.complianceLabel.toUpperCase(),
                      style: TextStyle(
                        color: cert.complianceColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
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
