import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../domain/entities/test_equipment_selection.dart';
import '../../domain/entities/test_template_name.dart';
import '../providers/certificate_providers.dart';

class CertDetailsStep extends ConsumerStatefulWidget {
  const CertDetailsStep({
    super.key,
    required this.template,
    required this.initialDate,
    required this.initialEquipment,
    required this.onChanged,
    required this.onNext,
  });

  final TestTemplateName template;
  final DateTime initialDate;
  final List<TestEquipmentSelection?> initialEquipment;
  final void Function(DateTime testDate, List<TestEquipmentSelection?> equipment) onChanged;
  final VoidCallback onNext;

  @override
  ConsumerState<CertDetailsStep> createState() => _CertDetailsStepState();
}

class _CertDetailsStepState extends ConsumerState<CertDetailsStep> {
  late DateTime _testDate;
  late List<TestEquipmentSelection?> _equipment;

  @override
  void initState() {
    super.initState();
    _testDate = widget.initialDate;
    _equipment = List.from(widget.initialEquipment);
  }

  bool get _isValid =>
      widget.template.testEquipQty == 0 ||
      (_equipment.length == widget.template.testEquipQty &&
          _equipment.every((e) => e != null));

  void _notify() => widget.onChanged(_testDate, _equipment);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _testDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _testDate = picked);
      _notify();
    }
  }

  Future<void> _pickEquipment(int slotIndex) async {
    final excluded = _equipment
        .asMap()
        .entries
        .where((e) => e.key != slotIndex && e.value != null)
        .map((e) => e.value!.assetId)
        .toSet();

    final picked = await showTestEquipmentPicker(context, excludeAssetIds: excluded);
    if (picked != null) {
      setState(() => _equipment[slotIndex] = picked);
      _notify();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd MMM yyyy').format(_testDate);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Certificate Details',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),

          // Test Date
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Test Date',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(color: brandGrey)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: widget.template.editDate ? _pickDate : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: widget.template.editDate
                            ? null
                            : const Color(0xFFF0F2F5),
                        border: Border.all(
                          color: widget.template.editDate
                              ? brandTeal
                              : const Color(0xFFDDE3EA),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 18,
                              color: widget.template.editDate
                                  ? brandTeal
                                  : brandGrey),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              dateStr,
                              style: TextStyle(
                                color: widget.template.editDate
                                    ? null
                                    : brandGrey,
                              ),
                            ),
                          ),
                          if (widget.template.editDate)
                            Text('Tap to change',
                                style: TextStyle(
                                    fontSize: 11, color: brandTeal)),
                          if (!widget.template.editDate)
                            Text('Auto — today',
                                style: TextStyle(
                                    fontSize: 11, color: brandGrey)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Test Equipment
          if (widget.template.testEquipQty > 0) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Test Equipment',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: brandGrey)),
                    const SizedBox(height: 8),
                    for (var i = 0; i < widget.template.testEquipQty; i++)
                      _EquipmentSlot(
                        slotNo: i + 1,
                        selection: i < _equipment.length ? _equipment[i] : null,
                        onPick: () => _pickEquipment(i),
                      ),
                  ],
                ),
              ),
            ),
          ],

          const Spacer(),
          FilledButton(
            onPressed: _isValid ? widget.onNext : null,
            child: Text(_isValid
                ? 'Next'
                : 'Select all test equipment to continue'),
          ),
        ],
      ),
    );
  }
}

// ── Equipment slot tile ───────────────────────────────────────────────────────

class _EquipmentSlot extends StatelessWidget {
  const _EquipmentSlot({
    required this.slotNo,
    required this.selection,
    required this.onPick,
  });

  final int slotNo;
  final TestEquipmentSelection? selection;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final filled = selection != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: filled ? brandTeal.withAlpha(10) : const Color(0xFFFAFBFC),
            border: Border.all(
              color: filled
                  ? brandTeal.withAlpha(100)
                  : const Color(0xFFDDE3EA),
              width: filled ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: brandTeal,
                child: Text('$slotNo',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: filled
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(selection!.displayName,
                              style: const TextStyle(fontWeight: FontWeight.w500)),
                          if (selection!.subtitleText.isNotEmpty)
                            Text(selection!.subtitleText,
                                style: TextStyle(
                                    fontSize: 11, color: brandGrey)),
                        ],
                      )
                    : Text('Select test equipment…',
                        style: TextStyle(color: brandGrey)),
              ),
              Text(filled ? 'Change' : 'Pick',
                  style: TextStyle(
                      fontSize: 11,
                      color: brandTeal,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Test equipment picker ─────────────────────────────────────────────────────

Future<TestEquipmentSelection?> showTestEquipmentPicker(
  BuildContext context, {
  Set<int> excludeAssetIds = const {},
}) {
  return showModalBottomSheet<TestEquipmentSelection>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) =>
        _TestEquipmentPickerSheet(excludeAssetIds: excludeAssetIds),
  );
}

class _TestEquipmentPickerSheet extends ConsumerWidget {
  const _TestEquipmentPickerSheet({required this.excludeAssetIds});
  final Set<int> excludeAssetIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetsAsync = ref.watch(testEquipmentAssetsProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Select Test Equipment',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          const Divider(height: 1),
          Expanded(
            child: assetsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Error loading equipment: $e')),
              data: (assets) {
                final available = assets
                    .where((a) => !excludeAssetIds.contains(a.assetId))
                    .toList();
                if (available.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.build_outlined,
                            size: 48, color: brandGrey),
                        const SizedBox(height: 12),
                        Text('No test equipment available',
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 4),
                        Text('Sync to load test equipment',
                            style: TextStyle(color: brandGrey)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  controller: controller,
                  itemCount: available.length,
                  itemBuilder: (_, i) {
                    final a = available[i];
                    return ListTile(
                      leading: const Icon(Icons.biotech_outlined,
                          color: brandTeal),
                      title: Text(a.displayName),
                      subtitle: Text([
                        if (a.serialNo != null) 'S/N: ${a.serialNo}',
                        if (a.calDate != null) 'Cal: ${a.calDate}',
                      ].join(' · ')),
                      onTap: () => Navigator.of(context).pop(
                        TestEquipmentSelection.fromAsset(a),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
