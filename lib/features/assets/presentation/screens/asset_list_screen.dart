import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../data/datasources/asset_local_data_source.dart';
import '../../domain/entities/asset.dart';
import '../providers/asset_providers.dart';
import 'asset_barcode_scanner_screen.dart';
import 'asset_detail_screen.dart';

class AssetListScreen extends ConsumerStatefulWidget {
  const AssetListScreen({super.key});

  @override
  ConsumerState<AssetListScreen> createState() => _AssetListScreenState();
}

class _AssetListScreenState extends ConsumerState<AssetListScreen> {
  String? _selectedHospital;
  String _query = '';
  final _searchController = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _startSearch() => setState(() => _searching = true);

  void _stopSearch() {
    setState(() {
      _searching = false;
      _query = '';
      _searchController.clear();
    });
  }

  void _openScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => const AssetBarcodeScannerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showList =
        _searching && _query.isNotEmpty || _selectedHospital != null;

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search equipment, serial, barcode…',
                  hintStyle: TextStyle(color: Colors.white60),
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              )
            : const Text('Assets'),
        actions: [
          if (_searching)
            IconButton(
                icon: const Icon(Icons.close), onPressed: _stopSearch)
          else ...[
            IconButton(
                icon: const Icon(Icons.search), onPressed: _startSearch),
            IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: _openScanner),
          ],
        ],
      ),
      body: Column(
        children: [
          _HospitalSelectorRow(
            selected: _selectedHospital,
            onSelect: (h) => setState(() => _selectedHospital = h),
          ),
          const Divider(height: 1),
          Expanded(
            child: showList
                ? (_searching && _query.isNotEmpty
                    ? _SearchResults(
                        query: _query, hospital: _selectedHospital)
                    : _AssetBrowseList(hospital: _selectedHospital))
                : const _AssetOverview(),
          ),
        ],
      ),
    );
  }
}

// ── Hospital selector row ─────────────────────────────────────────────────────

class _HospitalSelectorRow extends ConsumerWidget {
  const _HospitalSelectorRow(
      {required this.selected, required this.onSelect});
  final String? selected;
  final ValueChanged<String?> onSelect;

  void _showPicker(
      BuildContext context, List<String> hospitals, String? current) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _HospitalPickerSheet(
        hospitals: hospitals,
        selected: current,
        onSelect: (h) {
          onSelect(h);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hospitalsAsync = ref.watch(hospitalListProvider);

    return hospitalsAsync.when(
      loading: () => const SizedBox(height: 48),
      error: (_, _) => const SizedBox(height: 48),
      data: (hospitals) {
        final hasSelection = selected != null;
        final label = selected ?? 'All Hospitals';

        return SizedBox(
          height: 48,
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: hospitals.isEmpty
                      ? null
                      : () => _showPicker(context, hospitals, selected),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.local_hospital_outlined,
                          size: 18,
                          color: hasSelection ? brandTeal : brandGrey,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            label,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color:
                                      hasSelection ? brandTeal : null,
                                  fontWeight: hasSelection
                                      ? FontWeight.w600
                                      : null,
                                ),
                          ),
                        ),
                        const Icon(Icons.expand_more,
                            size: 20, color: brandGrey),
                      ],
                    ),
                  ),
                ),
              ),
              if (hasSelection)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: brandGrey,
                  onPressed: () => onSelect(null),
                  tooltip: 'Clear filter',
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Hospital picker bottom sheet ──────────────────────────────────────────────

class _HospitalPickerSheet extends StatefulWidget {
  const _HospitalPickerSheet({
    required this.hospitals,
    required this.selected,
    required this.onSelect,
  });
  final List<String> hospitals;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  State<_HospitalPickerSheet> createState() => _HospitalPickerSheetState();
}

class _HospitalPickerSheetState extends State<_HospitalPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.hospitals
        : widget.hospitals
            .where((h) =>
                h.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      builder: (_, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              children: [
                Text('Select Hospital',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (widget.selected != null)
                  TextButton(
                    onPressed: () => widget.onSelect(null),
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search…',
                prefixIcon: Icon(Icons.search, size: 20),
                contentPadding:
                    EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              widget.selected == null ? Icons.check : Icons.public,
              color: widget.selected == null ? brandTeal : brandGrey,
              size: 20,
            ),
            title: const Text('All Hospitals'),
            onTap: () => widget.onSelect(null),
            selected: widget.selected == null,
            selectedColor: brandTeal,
          ),
          const Divider(height: 1, indent: 52),
          Expanded(
            child: ListView.separated(
              controller: scrollController,
              itemCount: filtered.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 52),
              itemBuilder: (_, i) {
                final h = filtered[i];
                final isSelected = widget.selected == h;
                return ListTile(
                  leading: Icon(
                    isSelected
                        ? Icons.check
                        : Icons.local_hospital_outlined,
                    color: isSelected ? brandTeal : brandGrey,
                    size: 20,
                  ),
                  title: Text(h),
                  onTap: () => widget.onSelect(h),
                  selected: isSelected,
                  selectedColor: brandTeal,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Overview (shown when no hospital selected and not searching) ───────────────

class _AssetOverview extends ConsumerWidget {
  const _AssetOverview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(assetStatsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          statsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, _) => const SizedBox.shrink(),
            data: (s) => _StatsGrid(stats: s),
          ),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Icon(Icons.local_hospital_outlined,
                    size: 40, color: brandGrey.withAlpha(100)),
                const SizedBox(height: 12),
                Text(
                  'Select a hospital above to browse assets,\nor use search to find equipment.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: brandGrey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});
  final AssetStats stats;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _StatTile(
            label: 'Total Assets',
            count: stats.total,
            color: brandTeal,
            icon: Icons.medical_services_outlined),
        _StatTile(
            label: 'Active',
            count: stats.active,
            color: const Color(0xFF2E7D32),
            icon: Icons.check_circle_outline),
        _StatTile(
            label: 'Service Due',
            count: stats.serviceDue,
            color: brandError,
            icon: Icons.build_outlined),
        _StatTile(
            label: 'Condemned',
            count: stats.condemned,
            color: brandGrey,
            icon: Icons.block_outlined),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$count',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Browse list ───────────────────────────────────────────────────────────────

class _AssetBrowseList extends ConsumerWidget {
  const _AssetBrowseList({this.hospital});
  final String? hospital;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetsAsync = ref.watch(assetsProvider(hospital: hospital));

    return assetsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style:
                TextStyle(color: Theme.of(context).colorScheme.error)),
      ),
      data: (assets) => assets.isEmpty
          ? const Center(child: Text('No assets found.'))
          : ListView.builder(
              itemCount: assets.length,
              itemBuilder: (_, i) =>
                  _AssetTile(asset: assets[i], index: i),
            ),
    );
  }
}

// ── Search results ────────────────────────────────────────────────────────────

class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.query, this.hospital});
  final String query;
  final String? hospital;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync =
        ref.watch(assetSearchProvider(query, hospital: hospital));

    return resultsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: TextStyle(
                color: Theme.of(context).colorScheme.error)),
      ),
      data: (assets) => assets.isEmpty
          ? const Center(child: Text('No assets matched'))
          : ListView.builder(
              itemCount: assets.length,
              itemBuilder: (_, i) =>
                  _AssetTile(asset: assets[i], index: i),
            ),
    );
  }
}

// ── Asset tile (zebra, accent bar, no chevron) ────────────────────────────────

class _AssetTile extends StatelessWidget {
  const _AssetTile({required this.asset, required this.index});
  final Asset asset;
  final int index;

  static const _zebra = Color(0xFFF2F5F8);

  Color get _accentColor {
    if (asset.isCondemned) return brandGrey;
    if (asset.isProvisional) return const Color(0xFFF57F17);
    if (asset.isServiceDue) return brandError;
    return brandTeal;
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final color = _accentColor;
    final bg = index.isOdd ? _zebra : Colors.white;

    final makeModel = [asset.manufacturer, asset.model]
        .whereType<String>()
        .join(' · ');
    final location = [asset.hospital, asset.location]
        .whereType<String>()
        .join(' › ');

    return InkWell(
      onTap: () {
        if (asset.assetId != null) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => AssetDetailScreen(
                assetId: asset.assetId!, localAsset: asset),
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Provisional asset — pending admin registration'),
            ),
          );
        }
      },
      child: Container(
        color: bg,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent bar
              Container(width: 4, color: color),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              asset.equipmentType,
                              style: tt.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (asset.isServiceDue)
                            _StatusBadge('SVC DUE', brandError),
                          if (asset.isCondemned)
                            _StatusBadge('CONDEMNED', brandGrey),
                          if (asset.isProvisional)
                            _StatusBadge(
                                'PROV', const Color(0xFFF57F17)),
                        ],
                      ),
                      if (makeModel.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          makeModel,
                          style: tt.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              location.isNotEmpty ? location : '—',
                              style: tt.bodySmall
                                  ?.copyWith(color: brandGrey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (asset.serialNumber != null)
                            Text(
                              'S/N ${asset.serialNumber}',
                              style: tt.bodySmall
                                  ?.copyWith(color: brandGrey),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      margin: const EdgeInsets.only(left: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withAlpha(160)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
