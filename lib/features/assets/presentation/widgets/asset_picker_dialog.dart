import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../sync/sync_notifier.dart';
import '../../../../sync/sync_state.dart';
import '../../data/powersync_asset_data_source.dart';
import '../../domain/entities/asset.dart';

// ── Scoped providers ──────────────────────────────────────────────────────────

final _assetDataSourceProvider = Provider<PowerSyncAssetDataSource>(
  (ref) => throw UnimplementedError('Override before use'),
  dependencies: [],
);

final _hospitalsProvider = FutureProvider.autoDispose<List<String>>(
  (ref) => ref.watch(_assetDataSourceProvider).getHospitals(),
  dependencies: [_assetDataSourceProvider],
);

final _selectedHospitalProvider =
    NotifierProvider<_SelectedHospitalNotifier, String?>(
      _SelectedHospitalNotifier.new,
      dependencies: [],
      isAutoDispose: true,
    );

final class _SelectedHospitalNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? hospital) => state = hospital;
}

final _assetSearchQueryProvider =
    NotifierProvider<_AssetSearchQueryNotifier, String>(
      _AssetSearchQueryNotifier.new,
      dependencies: [],
      isAutoDispose: true,
    );

final class _AssetSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void update(String query) => state = query;
}

final _assetSearchResultsProvider = FutureProvider.autoDispose
    .family<List<Asset>, String>((ref, query) async {
      final hospital = ref.watch(_selectedHospitalProvider);
      final ds = ref.watch(_assetDataSourceProvider);
      return ds.searchAssets(query, hospital: hospital);
    }, dependencies: [_assetDataSourceProvider, _selectedHospitalProvider]);

// ── Public entry point ────────────────────────────────────────────────────────

/// Opens the two-step hospital → equipment picker.
///
/// Takes the PowerSync source: the old `assets` table is never populated, so
/// a picker pointed at it shows nothing. That is what happened when the
/// feature-level providers were repointed and this dialog's own scoped
/// provider was missed.
Future<Asset?> showAssetPicker(
  BuildContext context,
  PowerSyncAssetDataSource dataSource,
) {
  return showDialog<Asset>(
    context: context,
    builder: (_) => ProviderScope(
      overrides: [_assetDataSourceProvider.overrideWithValue(dataSource)],
      child: const _AssetPickerDialog(),
    ),
  );
}

// ── Dialog shell ──────────────────────────────────────────────────────────────

class _AssetPickerDialog extends ConsumerWidget {
  const _AssetPickerDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedHospital = ref.watch(_selectedHospitalProvider);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Column(
          children: [
            _DialogHeader(
              title: selectedHospital ?? 'Select Hospital',
              showBack: selectedHospital != null,
              onBack: () =>
                  ref.read(_selectedHospitalProvider.notifier).select(null),
              onClose: () => Navigator.of(context).pop(),
            ),
            const Divider(height: 1),
            Expanded(
              child: selectedHospital == null
                  ? const _HospitalPage()
                  : const _AssetPage(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dialog header ─────────────────────────────────────────────────────────────

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({
    required this.title,
    required this.showBack,
    required this.onBack,
    required this.onClose,
  });
  final String title;
  final bool showBack;
  final VoidCallback onBack;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
      child: Row(
        children: [
          if (showBack)
            IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack)
          else
            const SizedBox(width: 48),
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          IconButton(icon: const Icon(Icons.close), onPressed: onClose),
        ],
      ),
    );
  }
}

// ── Page 1: Hospital selection ────────────────────────────────────────────────

class _HospitalPage extends ConsumerStatefulWidget {
  const _HospitalPage();

  @override
  ConsumerState<_HospitalPage> createState() => _HospitalPageState();
}

class _HospitalPageState extends ConsumerState<_HospitalPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hospitalsAsync = ref.watch(_hospitalsProvider);

    return hospitalsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error: $e', style: Theme.of(context).textTheme.bodySmall),
      ),
      data: (hospitals) {
        if (hospitals.isEmpty) {
          return _SyncEmptyState(
            message: 'No hospitals available',
            subtitle: 'Sync to download the asset list',
          );
        }

        final filtered = _query.isEmpty
            ? hospitals
            : hospitals
                  .where((h) => h.toLowerCase().contains(_query.toLowerCase()))
                  .toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: TextField(
                controller: _searchCtrl,
                autofocus: false,
                decoration: const InputDecoration(
                  hintText: 'Search hospitals…',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No hospitals matched',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, indent: 16),
                      itemBuilder: (_, i) => ListTile(
                        leading: const Icon(
                          Icons.local_hospital_outlined,
                          color: brandTeal,
                        ),
                        title: Text(
                          filtered[i],
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () => ref
                            .read(_selectedHospitalProvider.notifier)
                            .select(filtered[i]),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ── Page 2: Asset selection ───────────────────────────────────────────────────

class _AssetPage extends ConsumerStatefulWidget {
  const _AssetPage();

  @override
  ConsumerState<_AssetPage> createState() => _AssetPageState();
}

class _AssetPageState extends ConsumerState<_AssetPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(_assetSearchQueryProvider);
    final resultsAsync = ref.watch(_assetSearchResultsProvider(query));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Search by equipment type, serial or barcode…',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (v) =>
                ref.read(_assetSearchQueryProvider.notifier).update(v.trim()),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: resultsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(
                'Error: $e',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            data: (assets) => assets.isEmpty
                ? _SyncEmptyState(
                    message: query.isNotEmpty
                        ? 'No assets matched'
                        : 'No assets for this hospital',
                    subtitle: query.isNotEmpty
                        ? 'Try a different search'
                        // Assets are registered by the office, never here.
                        : 'No equipment has synced for this hospital yet',
                  )
                : ListView.separated(
                    itemCount: assets.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 16),
                    itemBuilder: (_, i) => _AssetTile(
                      asset: assets[i],
                      onTap: () => Navigator.of(context).pop(assets[i]),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

// ── Asset tile ────────────────────────────────────────────────────────────────

class _AssetTile extends StatelessWidget {
  const _AssetTile({required this.asset, required this.onTap});
  final Asset asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(Icons.medical_services_outlined, color: brandTeal),
      title: Text(
        asset.equipmentType,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      subtitle: Text(
        [
          if (asset.assetId != null) '#${asset.assetId}',
          if (asset.serialNumber != null) 'S/N: ${asset.serialNumber}',
        ].join('  ·  '),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

// ── Sync / empty state ────────────────────────────────────────────────────────

class _SyncEmptyState extends ConsumerWidget {
  const _SyncEmptyState({required this.message, required this.subtitle});
  final String message;
  final String subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSyncing = ref.watch(syncProvider) is SyncInProgress;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_download_outlined,
              size: 48,
              color: brandGrey,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sync, size: 18),
              label: Text(isSyncing ? 'Syncing…' : 'Sync Now'),
              onPressed: isSyncing
                  ? null
                  : () => ref.read(syncProvider.notifier).triggerSync(),
            ),
          ],
        ),
      ),
    );
  }
}
