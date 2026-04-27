import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../domain/entities/asset.dart';
import '../../domain/entities/asset_detail.dart';
import '../providers/asset_providers.dart';

class AssetDetailScreen extends ConsumerWidget {
  const AssetDetailScreen({
    super.key,
    required this.assetId,
    required this.localAsset,
  });

  final int assetId;
  final Asset localAsset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(assetDetailProvider(assetId));

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
          localAsset.serialNumber != null
              ? 'S/N ${localAsset.serialNumber}'
              : localAsset.equipmentType,
        ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Service'),
              Tab(text: 'Warranty'),
            ],
          ),
        ),
        body: Column(
          children: [
            _HeaderCard(asset: localAsset),
            Expanded(
              child: detailAsync.when(
                loading: () => const _SkeletonBody(),
                error: (e, _) => const _OfflineBody(),
                data: (detail) => _TabBody(detail: detail),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header card (from local slim record) ─────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.asset});
  final Asset asset;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.medical_services_outlined,
                    color: brandTeal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    asset.equipmentType,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (asset.model != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(asset.model!,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            const SizedBox(height: 8),
            _InfoRow(
                icon: Icons.factory_outlined,
                text: asset.manufacturer ?? '—'),
            if (asset.serialNumber != null)
              _InfoRow(
                  icon: Icons.tag, text: 'S/N: ${asset.serialNumber}'),
            if (asset.barcode != null)
              _InfoRow(
                  icon: Icons.qr_code,
                  text: 'Barcode: ${asset.barcode}'),
            if (asset.hospital != null)
              _InfoRow(
                  icon: Icons.local_hospital_outlined,
                  text: asset.hospital!),
            if (asset.location != null)
              _InfoRow(
                  icon: Icons.location_on_outlined,
                  text: asset.location!),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: brandGrey),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

// ── Tab body ──────────────────────────────────────────────────────────────────

class _TabBody extends StatelessWidget {
  const _TabBody({required this.detail});
  final AssetDetail detail;

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      children: [
        _OverviewTab(detail: detail),
        _ServiceTab(detail: detail),
        _WarrantyTab(detail: detail),
      ],
    );
  }
}

// ── Overview tab ──────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.detail});
  final AssetDetail detail;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _DetailRow(label: 'Condition', value: detail.condition ?? '—'),
        _DetailRow(label: 'Risk Level', value: detail.riskLabel),
        _DetailRow(
          label: 'Status',
          value: detail.isCondemned
              ? 'Condemned'
              : detail.isActive
                  ? 'Active'
                  : 'Inactive',
        ),
        _DetailRow(
            label: 'Loan Unit',
            value: detail.isLoan ? 'Yes' : 'No'),
        _DetailRow(
            label: 'Demo Unit',
            value: detail.isDemo ? 'Yes' : 'No'),
        if (detail.softwareVersion != null)
          _DetailRow(
              label: 'Software Version',
              value: detail.softwareVersion!),
        if (detail.accessories != null)
          _DetailRow(
              label: 'Accessories', value: detail.accessories!),
        if (detail.notes != null) ...[
          const Divider(),
          Text('Notes', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(detail.notes!,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}

// ── Service tab ───────────────────────────────────────────────────────────────

class _ServiceTab extends StatelessWidget {
  const _ServiceTab({required this.detail});
  final AssetDetail detail;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _DetailRow(
          label: 'Last Service Date',
          value: detail.lastServiceDate != null
              ? fmt.format(detail.lastServiceDate!)
              : '—',
        ),
        _DetailRow(
          label: 'Next Service Date',
          value: detail.nextServiceDate != null
              ? fmt.format(detail.nextServiceDate!)
              : '—',
          valueColor: detail.isServiceDueSoon ? brandError : null,
        ),
        _DetailRow(
            label: 'Operating Hours',
            value: detail.hours?.toString() ?? '—'),
        const Divider(),
        _DetailRow(
          label: 'Service Plan',
          value: detail.hasServicePlan ? 'Active' : 'None',
        ),
        if (detail.hasServicePlan) ...[
          _DetailRow(
            label: 'Plan Start',
            value: detail.servicePlanStartDate != null
                ? fmt.format(detail.servicePlanStartDate!)
                : '—',
          ),
          _DetailRow(
            label: 'Plan Expiry',
            value: detail.servicePlanExpDate != null
                ? fmt.format(detail.servicePlanExpDate!)
                : '—',
          ),
          if (detail.servicePlanValue != null)
            _DetailRow(
              label: 'Plan Value',
              value:
                  'R ${detail.servicePlanValue!.toStringAsFixed(2)}',
            ),
        ],
      ],
    );
  }
}

// ── Warranty tab ──────────────────────────────────────────────────────────────

class _WarrantyTab extends StatelessWidget {
  const _WarrantyTab({required this.detail});
  final AssetDetail detail;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _DetailRow(
          label: 'Warranty Status',
          value: detail.isUnderWarranty ? 'Under Warranty' : 'Expired',
          valueColor: detail.isUnderWarranty ? brandGreen : null,
        ),
        _DetailRow(
          label: 'Type',
          value: detail.assetType == 1 ? 'Warranty' : 'Non-warranty',
        ),
        _DetailRow(
          label: 'Warranty Start',
          value: detail.warrantyDateStart != null
              ? fmt.format(detail.warrantyDateStart!)
              : '—',
        ),
        _DetailRow(
          label: 'Warranty End',
          value: detail.warrantyEndDate != null
              ? fmt.format(detail.warrantyEndDate!)
              : '—',
        ),
        if (detail.warrantyPeriod != null)
          _DetailRow(
              label: 'Period',
              value: '${detail.warrantyPeriod} months'),
        const Divider(),
        _DetailRow(
          label: 'Manufacture Date',
          value: detail.manufactureDate != null
              ? fmt.format(detail.manufactureDate!)
              : '—',
        ),
        _DetailRow(
          label: 'Delivery Date',
          value: detail.deliverDate != null
              ? fmt.format(detail.deliverDate!)
              : '—',
        ),
        _DetailRow(
          label: 'Commission Date',
          value: detail.commissionDate != null
              ? fmt.format(detail.commissionDate!)
              : '—',
        ),
      ],
    );
  }
}

// ── Shared row widget ─────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  const _DetailRow(
      {required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: brandGrey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: valueColor,
                    fontWeight: valueColor != null ? FontWeight.w600 : null,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

const int _kTabCount = 3;

// ── Loading skeleton ──────────────────────────────────────────────────────────

class _SkeletonBody extends StatelessWidget {
  const _SkeletonBody();

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      children: List.generate(
        _kTabCount,
        (_) => ListView(
          padding: const EdgeInsets.all(16),
          children: List.generate(
            5,
            (_) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Container(
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(40),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Offline state ─────────────────────────────────────────────────────────────

class _OfflineBody extends StatelessWidget {
  const _OfflineBody();

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      children: List.generate(
        _kTabCount,
        (_) => const Center(
          child: Text('Connect to view full details'),
        ),
      ),
    );
  }
}
