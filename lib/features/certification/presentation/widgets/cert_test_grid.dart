import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter;
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
    required this.onValidityChanged,
  });
  final int templateNameId;
  final int assetId;
  final ValueChanged<List<TestOutput>> onOutputsChanged;
  /// Called whenever validation state changes — true when all required actual
  /// values are filled in.
  final ValueChanged<bool> onValidityChanged;

  @override
  ConsumerState<CertTestGrid> createState() => _CertTestGridState();
}

class _CertTestGridState extends ConsumerState<CertTestGrid> {
  final Map<int, _OutputState> _states = {};
  // Cached item list so _notify always works on current data, not a
  // stale closure reference from a previous build.
  List<TestTemplateItem> _items = [];

  @override
  void didUpdateWidget(CertTestGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.templateNameId != widget.templateNameId) {
      _states.clear();
      _items = [];
    }
  }

  bool _isComplete(TestTemplateItem item, _OutputState s) {
    final hasResult = s.pass || s.fail || s.na;
    if (!hasResult) return false;
    if (item.noActualRequired) return true;
    return s.actualValue != null && s.actualValue!.trim().isNotEmpty;
  }

  void _notify() {
    final outputs = _items.map((item) {
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

    final completed = _items.where((item) {
      final s = _states[item.id] ?? _OutputState();
      return _isComplete(item, s);
    }).length;

    widget.onValidityChanged(completed == _items.length);
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

        // Cache items and initialise state for any new entries
        _items = items;
        for (final item in items) {
          _states.putIfAbsent(item.id, () => _OutputState());
        }

        final passFailCount = items.where((item) {
          final s = _states[item.id] ?? _OutputState();
          return s.pass || s.fail || s.na;
        }).length;
        final itemsNeedingActual =
            items.where((item) => !item.noActualRequired).toList();
        final actualCount = itemsNeedingActual.where((item) {
          final s = _states[item.id] ?? _OutputState();
          return s.actualValue != null && s.actualValue!.trim().isNotEmpty;
        }).length;

        return Column(
          children: [
            _ProgressBanner(
              passFailCount: passFailCount,
              total: items.length,
              actualCount: actualCount,
              actualRequired: itemsNeedingActual.length,
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final entry in sections.entries) ...[
                    _SectionHeader(title: entry.key),
                    for (final item in entry.value)
                      _TestItemRow(
                        item: item,
                        state: _states[item.id]!,
                        onChanged: (s) {
                          setState(() => _states[item.id] = s);
                          _notify();
                        },
                      ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
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

class _ProgressBanner extends StatelessWidget {
  const _ProgressBanner({
    required this.passFailCount,
    required this.total,
    required this.actualCount,
    required this.actualRequired,
  });
  final int passFailCount;
  final int total;
  final int actualCount;
  final int actualRequired;

  @override
  Widget build(BuildContext context) {
    final allResultsDone = passFailCount == total;
    final allActualDone = actualRequired == 0 || actualCount == actualRequired;
    final allDone = allResultsDone && allActualDone;
    final color = allDone ? Colors.green[700]! : const Color(0xFFF57F17);

    final rowStyle = TextStyle(
      color: color,
      fontWeight: FontWeight.w600,
      fontSize: 12,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              allDone ? Icons.task_alt : Icons.checklist,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Pass / Fail / N/A', style: rowStyle)),
                    Text('$passFailCount / $total', style: rowStyle),
                  ],
                ),
                if (actualRequired > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(child: Text('Actual Values', style: rowStyle)),
                      Text('$actualCount / $actualRequired', style: rowStyle),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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
  bool get _noExpectedValue {
    final v = item.expectedValue?.trim();
    return v == null || v.isEmpty || v == '-';
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      color: brandGrey,
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column labels
          Row(
            children: [
              Expanded(flex: 3, child: Text('Test Description', style: labelStyle)),
              if (!_noExpectedValue) ...[
                const SizedBox(width: 8),
                Expanded(flex: 2, child: Text('Test Value', style: labelStyle, textAlign: TextAlign.center)),
              ],
              if (!_noActualRequired) ...[
                const SizedBox(width: 8),
                Expanded(flex: 2, child: Text('Actual', style: labelStyle, textAlign: TextAlign.center)),
              ],
            ],
          ),
          const SizedBox(height: 4),
          // Description + expected + actual row
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(item.description ?? '',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              if (!_noExpectedValue) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Text(
                    item.expectedValue!,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              if (!_noActualRequired) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    key: ValueKey(item.id),
                    initialValue: state.actualValue,
                    decoration: const InputDecoration(
                      hintText: 'Actual',
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    inputFormatters: [LengthLimitingTextInputFormatter(15)],
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
          // Template note (read-only reference from TestTempNotes)
          if (item.notes != null && item.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                item.notes!,
                style: TextStyle(
                  fontSize: 11,
                  color: brandGrey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          // Technician's own notes
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
            inputFormatters: [LengthLimitingTextInputFormatter(30)],
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
