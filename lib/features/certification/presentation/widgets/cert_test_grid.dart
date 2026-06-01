import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/test_template_item.dart';
import '../../domain/entities/test_output.dart';
import '../providers/certificate_providers.dart';

class CertTestGrid extends ConsumerStatefulWidget {
  const CertTestGrid({
    super.key,
    required this.templateNameId,
    required this.assetId,
    required this.onOutputsChanged,
  });
  final int templateNameId;
  final int assetId;
  final ValueChanged<List<TestOutput>> onOutputsChanged;

  @override
  ConsumerState<CertTestGrid> createState() => _CertTestGridState();
}

class _CertTestGridState extends ConsumerState<CertTestGrid> {
  // Map from item id → mutable output state
  final Map<int, _OutputState> _states = {};

  @override
  void didUpdateWidget(CertTestGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.templateNameId != widget.templateNameId) {
      _states.clear();
    }
  }

  void _notify(List<TestTemplateItem> items) {
    final outputs = items.map((item) {
      final s = _states[item.id] ?? _OutputState();
      return TestOutput(
        id: 0,
        certificateId: 0,
        assetId: widget.assetId,
        descriptionId: item.descriptionId,
        description: item.description,
        expectedValue: item.expectedValue,
        actualValue: s.actualValue,
        notes: s.notes,
        pass: s.pass,
        fail: s.fail,
        na: s.na,
      );
    }).toList();
    widget.onOutputsChanged(outputs);
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(templateItemsProvider(widget.templateNameId));

    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Text('No test items for this template',
                style: TextStyle(color: brandGrey)),
          );
        }

        // Group by section (descriptionId)
        final sections = <String, List<TestTemplateItem>>{};
        for (final item in items) {
          final section = item.descriptionId ?? 'General';
          sections.putIfAbsent(section, () => []).add(item);
        }

        // Initialise state for any new items
        for (final item in items) {
          _states.putIfAbsent(item.id, () => _OutputState());
        }

        return ListView(
          children: [
            for (final entry in sections.entries) ...[
              _SectionHeader(title: entry.key),
              for (final item in entry.value)
                _TestItemRow(
                  item: item,
                  state: _states[item.id]!,
                  onChanged: (s) {
                    setState(() => _states[item.id] = s);
                    _notify(items);
                  },
                ),
            ],
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

class _OutputState {
  String? actualValue;
  String? notes;
  bool pass = false;
  bool fail = false;
  bool na = false;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: brandTeal.withAlpha(20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: brandTeal, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _TestItemRow extends StatelessWidget {
  const _TestItemRow({
    required this.item,
    required this.state,
    required this.onChanged,
  });
  final TestTemplateItem item;
  final _OutputState state;
  final ValueChanged<_OutputState> onChanged;

  bool get _noActualRequired => item.noActualRequired;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description + expected + actual row
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.description ?? '',
                        style: Theme.of(context).textTheme.bodyMedium),
                    if (item.notes != null)
                      Text(item.notes!,
                          style: TextStyle(color: brandGrey, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Text(
                  item.expectedValue ?? '',
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
                child: TextFormField(
                  key: ValueKey(item.id),
                  initialValue: state.actualValue,
                  enabled: !_noActualRequired,
                  decoration: InputDecoration(
                    hintText: _noActualRequired ? 'N/A' : 'Actual',
                    isDense: true,
                  ),
                  onChanged: (v) {
                    onChanged(_OutputState()
                      ..actualValue = v
                      ..notes = state.notes
                      ..pass = state.pass
                      ..fail = state.fail
                      ..na = state.na);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Pass / Fail / N/A chips — left-aligned
          Row(
            children: [
              _ResultChip(
                label: 'Pass',
                color: Colors.green,
                selected: state.pass,
                onTap: () => onChanged(_OutputState()
                  ..actualValue = state.actualValue
                  ..notes = state.notes
                  ..pass = !state.pass
                  ..fail = false
                  ..na = false),
              ),
              const SizedBox(width: 6),
              _ResultChip(
                label: 'Fail',
                color: brandError,
                selected: state.fail,
                onTap: () => onChanged(_OutputState()
                  ..actualValue = state.actualValue
                  ..notes = state.notes
                  ..pass = false
                  ..fail = !state.fail
                  ..na = false),
              ),
              const SizedBox(width: 6),
              _ResultChip(
                label: 'N/A',
                color: brandGrey,
                selected: state.na,
                onTap: () => onChanged(_OutputState()
                  ..actualValue = state.actualValue
                  ..notes = state.notes
                  ..pass = false
                  ..fail = false
                  ..na = !state.na),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Notes field
          TextFormField(
            key: ValueKey('notes_${item.id}'),
            initialValue: state.notes,
            decoration: const InputDecoration(
              hintText: 'Notes',
              isDense: true,
            ),
            maxLines: 2,
            minLines: 1,
            style: const TextStyle(fontSize: 13),
            onChanged: (v) {
              onChanged(_OutputState()
                ..actualValue = state.actualValue
                ..notes = v
                ..pass = state.pass
                ..fail = state.fail
                ..na = state.na);
            },
          ),
          const SizedBox(height: 8),
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
    required this.onTap,
  });
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
      ),
    );
  }
}
