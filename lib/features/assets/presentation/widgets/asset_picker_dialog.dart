import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../sync/sync_notifier.dart';
import '../../../../sync/sync_state.dart';
import '../../data/datasources/asset_local_data_source.dart';
import '../../domain/entities/asset.dart';

// ── Scoped providers ──────────────────────────────────────────────────────────

final _assetDataSourceProvider = Provider<AssetLocalDataSource>(
  (ref) => throw UnimplementedError('Override before use'),
  dependencies: [],
);

final _hospitalsProvider = FutureProvider.autoDispose<List<String>>(
  (ref) => ref.watch(_assetDataSourceProvider).getHospitals(),
  dependencies: [_assetDataSourceProvider],
);

final _selectedHospitalProvider = NotifierProvider<
    _SelectedHospitalNotifier, String?>(
  _SelectedHospitalNotifier.new,
  dependencies: [],
  isAutoDispose: true,
);

final class _SelectedHospitalNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? hospital) => state = hospital;
}

final _assetSearchQueryProvider = NotifierProvider<
    _AssetSearchQueryNotifier, String>(
  _AssetSearchQueryNotifier.new,
  dependencies: [],
  isAutoDispose: true,
);

final class _AssetSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void update(String query) => state = query;
}

final _assetSearchResultsProvider =
    FutureProvider.autoDispose.family<List<Asset>, String>(
  (ref, query) async {
    final hospital = ref.watch(_selectedHospitalProvider);
    final ds = ref.watch(_assetDataSourceProvider);
    return ds.searchAssets(query, hospital: hospital);
  },
  dependencies: [_assetDataSourceProvider, _selectedHospitalProvider],
);

// ── Public entry point ────────────────────────────────────────────────────────

Future<Asset?> showAssetPicker(
  BuildContext context,
  AssetLocalDataSource dataSource,
) {
  return showDialog<Asset>(
    context: context,
    builder: (_) => ProviderScope(
      overrides: [
        _assetDataSourceProvider.overrideWithValue(dataSource),
      ],
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
            child: Text(title,
                style: Theme.of(context).textTheme.titleMedium),
          ),
          IconButton(icon: const Icon(Icons.close), onPressed: onClose),
        ],
      ),
    );
  }
}

// ── Page 1: Hospital selection ────────────────────────────────────────────────

class _HospitalPage extends ConsumerWidget {
  const _HospitalPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hospitalsAsync = ref.watch(_hospitalsProvider);

    return hospitalsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error: $e', style: Theme.of(context).textTheme.bodySmall),
      ),
      data: (hospitals) => hospitals.isEmpty
          ? _SyncEmptyState(
              message: 'No hospitals available',
              subtitle: 'Sync to download the asset list',
            )
          : ListView.separated(
              itemCount: hospitals.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 16),
              itemBuilder: (_, i) => ListTile(
                leading: const Icon(Icons.local_hospital_outlined,
                    color: brandTeal),
                title: Text(hospitals[i],
                    style: Theme.of(context).textTheme.bodyLarge),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () =>
                    ref.read(_selectedHospitalProvider.notifier).select(hospitals[i]),
              ),
            ),
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

  Future<void> _openProvisionalForm() async {
    final hospital = ref.read(_selectedHospitalProvider);
    final ds = ref.read(_assetDataSourceProvider);
    final asset = await showModalBottomSheet<Asset>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProvisionalAssetForm(
        dataSource: ds,
        prefilledHospital: hospital,
      ),
    );
    if (asset != null && mounted) {
      Navigator.of(context).pop(asset);
    }
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
              child: Text('Error: $e',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            data: (assets) => assets.isEmpty
                ? _SyncEmptyState(
                    message: query.isNotEmpty
                        ? 'No assets matched'
                        : 'No assets for this hospital',
                    subtitle: query.isNotEmpty
                        ? 'Try a different search or register a provisional'
                        : 'Sync to download assets, or register a provisional',
                    showProvisional: true,
                    onProvisional: _openProvisionalForm,
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
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: TextButton.icon(
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('Asset not listed — register provisional'),
            onPressed: _openProvisionalForm,
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
      leading: Icon(
        Icons.medical_services_outlined,
        color: asset.isProvisional ? const Color(0xFFF57F17) : brandTeal,
      ),
      title: Text(asset.equipmentType,
          style: Theme.of(context).textTheme.bodyLarge),
      subtitle: Text(
        [
          if (asset.assetId != null) '#${asset.assetId}',
          if (asset.serialNumber != null) 'S/N: ${asset.serialNumber}',
        ].join('  ·  '),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: asset.isProvisional
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF57F17).withAlpha(30),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFF57F17)),
              ),
              child: const Text(
                'PROVISIONAL',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFF57F17),
                ),
              ),
            )
          : const Icon(Icons.chevron_right, size: 18),
    );
  }
}

// ── Sync / empty state ────────────────────────────────────────────────────────

class _SyncEmptyState extends ConsumerWidget {
  const _SyncEmptyState({
    required this.message,
    required this.subtitle,
    this.showProvisional = false,
    this.onProvisional,
  });
  final String message;
  final String subtitle;
  final bool showProvisional;
  final VoidCallback? onProvisional;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSyncing = ref.watch(syncProvider) is SyncInProgress;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_download_outlined,
                size: 48, color: brandGrey),
            const SizedBox(height: 12),
            Text(message,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(subtitle,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.sync, size: 18),
              label: Text(isSyncing ? 'Syncing…' : 'Sync Now'),
              onPressed: isSyncing
                  ? null
                  : () =>
                      ref.read(syncProvider.notifier).triggerSync(),
            ),
            if (showProvisional && onProvisional != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onProvisional,
                child: const Text('Or register a provisional asset'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Provisional asset form ────────────────────────────────────────────────────

class _ProvisionalAssetForm extends StatefulWidget {
  const _ProvisionalAssetForm({
    required this.dataSource,
    this.prefilledHospital,
  });
  final AssetLocalDataSource dataSource;
  final String? prefilledHospital;

  @override
  State<_ProvisionalAssetForm> createState() => _ProvisionalAssetFormState();
}

class _ProvisionalAssetFormState extends State<_ProvisionalAssetForm> {
  final _formKey = GlobalKey<FormState>();
  final _equipmentTypeCtrl = TextEditingController();
  final _serialCtrl = TextEditingController();
  final _manufacturerCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _equipmentTypeCtrl.dispose();
    _serialCtrl.dispose();
    _manufacturerCtrl.dispose();
    _modelCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final asset = await widget.dataSource.createProvisional(
        equipmentType: _equipmentTypeCtrl.text.trim(),
        serialNumber:
            _serialCtrl.text.trim().isEmpty ? null : _serialCtrl.text.trim(),
        manufacturer: _manufacturerCtrl.text.trim().isEmpty
            ? null
            : _manufacturerCtrl.text.trim(),
        model:
            _modelCtrl.text.trim().isEmpty ? null : _modelCtrl.text.trim(),
        hospital: widget.prefilledHospital,
        location: _locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(asset);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFF57F17)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Provisional Asset',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              ]),
              const SizedBox(height: 4),
              Text(
                'This record will be flagged for admin registration after sync.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (widget.prefilledHospital != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: brandTeal.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: brandTeal.withAlpha(60)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.local_hospital_outlined,
                        size: 16, color: brandTeal),
                    const SizedBox(width: 8),
                    Text(widget.prefilledHospital!,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: brandTeal)),
                  ]),
                ),
              ],
              const SizedBox(height: 20),
              TextFormField(
                controller: _equipmentTypeCtrl,
                decoration:
                    const InputDecoration(labelText: 'Equipment Type *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _serialCtrl,
                decoration:
                    const InputDecoration(labelText: 'Serial Number'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _manufacturerCtrl,
                decoration:
                    const InputDecoration(labelText: 'Manufacturer'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _modelCtrl,
                decoration: const InputDecoration(labelText: 'Model'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationCtrl,
                decoration:
                    const InputDecoration(labelText: 'Location / Ward'),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Provisional Asset'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
