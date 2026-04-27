import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../assets/presentation/widgets/asset_picker_dialog.dart';
import '../../../assets/domain/entities/asset.dart';
import '../../domain/entities/work_order_enums.dart';
import '../providers/work_order_providers.dart';
import 'work_order_detail_screen.dart';

class CreateWorkOrderScreen extends ConsumerStatefulWidget {
  const CreateWorkOrderScreen({super.key});

  @override
  ConsumerState<CreateWorkOrderScreen> createState() =>
      _CreateWorkOrderScreenState();
}

class _CreateWorkOrderScreenState
    extends ConsumerState<CreateWorkOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _symptomCtrl = TextEditingController();

  Asset? _selectedAsset;
  WoType _type = WoType.cm;
  WoPriority _priority = WoPriority.p3;

  static const _typeLabels = {
    WoType.cm: 'Corrective Maintenance',
    WoType.pm: 'Preventive Maintenance',
    WoType.ins: 'Inspection',
    WoType.inst: 'Installation',
    WoType.dec: 'Decommissioning',
    WoType.upg: 'Upgrade',
  };

  static const _typeIcons = {
    WoType.cm: Icons.build_outlined,
    WoType.pm: Icons.assignment_outlined,
    WoType.ins: Icons.search_outlined,
    WoType.inst: Icons.add_box_outlined,
    WoType.dec: Icons.delete_outline,
    WoType.upg: Icons.upgrade_outlined,
  };

  static const _priorityLabels = {
    WoPriority.p1: 'P1 — Critical',
    WoPriority.p2: 'P2 — High',
    WoPriority.p3: 'P3 — Medium',
    WoPriority.p4: 'P4 — Low',
  };

  static const _priorityColors = {
    WoPriority.p1: Color(0xFFB71C1C),
    WoPriority.p2: Color(0xFFE65100),
    WoPriority.p3: Color(0xFFF9A825),
    WoPriority.p4: Color(0xFF2E7D32),
  };

  @override
  void dispose() {
    _symptomCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAsset() async {
    final ds = ref.read(assetLocalDataSourceProvider);
    final asset = await showAssetPicker(context, ds);
    if (asset != null) setState(() => _selectedAsset = asset);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAsset == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an asset')),
      );
      return;
    }

    final wo = await ref
        .read(workOrderActionsProvider.notifier)
        .createWorkOrder(
          assetId: _selectedAsset!.id,
          type: _type,
          priority: _priority,
          symptomDescription: _symptomCtrl.text.trim(),
        );

    if (!mounted) return;

    if (wo != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => WorkOrderDetailScreen(workOrderId: wo.id),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create work order')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionsState = ref.watch(workOrderActionsProvider);
    final isSaving = actionsState is AsyncLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('New Work Order')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Type of work order
              _SectionLabel(label: 'Type of Work Order'),
              const SizedBox(height: 8),
              _TypeSelector(
                selected: _type,
                labels: _typeLabels,
                icons: _typeIcons,
                onChanged: (t) => setState(() => _type = t),
              ),
              const SizedBox(height: 20),

              // Priority
              _SectionLabel(label: 'Priority'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: WoPriority.values.map((p) {
                  final selected = _priority == p;
                  final color = _priorityColors[p]!;
                  return ChoiceChip(
                    label: Text(_priorityLabels[p]!),
                    selected: selected,
                    selectedColor: color.withAlpha(40),
                    labelStyle: TextStyle(
                      color: selected ? color : brandGrey,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: selected ? color : const Color(0xFFDDE3EA),
                    ),
                    onSelected: (_) => setState(() => _priority = p),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Asset
              _SectionLabel(label: 'Asset'),
              const SizedBox(height: 8),
              _AssetPickerField(
                asset: _selectedAsset,
                onTap: _pickAsset,
              ),
              const SizedBox(height: 20),

              // Description
              _SectionLabel(label: 'Description / Symptom'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _symptomCtrl,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText:
                      'Describe the fault, reason for visit, or work required…',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 32),

              if (_type == WoType.cm)
                _InfoBanner(
                  message:
                      'CM work orders start immediately — no dispatcher approval required.',
                  color: brandTeal,
                )
              else
                _InfoBanner(
                  message:
                      '${_type.value} work orders are submitted to the dispatcher for scheduling.',
                  color: const Color(0xFFF57F17),
                ),
              const SizedBox(height: 16),

              FilledButton(
                onPressed: isSaving ? null : _submit,
                child: isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _type == WoType.cm
                            ? 'Create & Start Work'
                            : 'Submit Work Order',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Type selector grid ────────────────────────────────────────────────────────

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({
    required this.selected,
    required this.labels,
    required this.icons,
    required this.onChanged,
  });

  final WoType selected;
  final Map<WoType, String> labels;
  final Map<WoType, IconData> icons;
  final ValueChanged<WoType> onChanged;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: WoType.values.map((t) {
        final isSelected = selected == t;
        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onChanged(t),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? brandTeal.withAlpha(20) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? brandTeal : const Color(0xFFDDE3EA),
                width: isSelected ? 2 : 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icons[t],
                  size: 22,
                  color: isSelected ? brandTeal : brandGrey,
                ),
                const SizedBox(height: 4),
                Text(
                  t.value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? brandTeal : brandDark,
                  ),
                ),
                Text(
                  labels[t]!,
                  style: TextStyle(
                    fontSize: 9,
                    color: isSelected ? brandTeal : brandGrey,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Asset picker field ────────────────────────────────────────────────────────

class _AssetPickerField extends StatelessWidget {
  const _AssetPickerField({required this.asset, required this.onTap});
  final Asset? asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: asset == null ? const Color(0xFFDDE3EA) : brandTeal,
            width: asset == null ? 1 : 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.medical_services_outlined,
              size: 20,
              color: asset == null ? brandGrey : brandTeal,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: asset == null
                  ? Text(
                      'Tap to select hospital & asset',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: brandGrey),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(asset!.equipmentType,
                            style: Theme.of(context).textTheme.bodyLarge),
                        Text(
                          [
                            asset!.assetId != null ? '#${asset!.assetId}' : 'Provisional',
                            if (asset!.serialNumber != null)
                              'S/N: ${asset!.serialNumber}',
                            asset!.hospital ?? '',
                          ].join('  ·  '),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (asset!.isProvisional)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              'PROVISIONAL — pending admin registration',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFFF57F17),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
            Icon(
              Icons.chevron_right,
              color: asset == null ? brandGrey : brandTeal,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Info banner ───────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message, required this.color});
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(color: brandGrey),
    );
  }
}
