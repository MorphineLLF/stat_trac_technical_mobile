import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/test_template_item.dart';
import '../../domain/entities/test_output.dart';
import '../providers/certificate_providers.dart';
import 'actual_value_field.dart';
import 'result_radio_row.dart';

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
    final outputs = _items
        .where((item) {
          final s = _states[item.id] ?? _OutputState();
          return s.pass || s.fail || s.na;
        })
        .map((item) {
          final s = _states[item.id]!;
          return TestOutput(
            id: 0,
            certificateId: 0,
            assetId: widget.assetId,
            descriptionId: item.descriptionId,
            description: item.description,
            expectedValue: item.expectedValue,
            actualValue: s.actualValue,
            notes: item.notes,
            pass: s.pass,
            fail: s.fail,
            na: s.na,
          );
        })
        .toList();
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
            child: Text(
              'No test items for this template',
              style: TextStyle(color: brandGrey),
            ),
          );
        }

        // Group by section (descriptionId)
        final sections = <String, List<TestTemplateItem>>{};
        for (final item in items) {
          final section = item.descriptionId ?? 'General';
          sections.putIfAbsent(section, () => []).add(item);
        }

        // Cache items and initialise state for any new entries.
        // Pre-populate actualValue from the template's TestTempActualValue so
        // it flows through to TestOutput.TestActualValue on save.
        _items = items;
        for (final item in items) {
          _states.putIfAbsent(item.id, () {
            final s = _OutputState();
            if (item.actualValueTemplate != null &&
                item.actualValueTemplate!.isNotEmpty) {
              s.actualValue = item.actualValueTemplate;
            }
            return s;
          });
        }

        final passFailCount = items.where((item) {
          final s = _states[item.id] ?? _OutputState();
          return s.pass || s.fail || s.na;
        }).length;
        final itemsNeedingActual = items
            .where((item) => !item.noActualRequired)
            .toList();
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
    final color = allDone ? Colors.green[700]! : const Color(0xFF00838F);

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
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: brandTeal,
          fontWeight: FontWeight.bold,
        ),
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

  // Fixed, not a flex share: at flex 2 the box took over a quarter of the
  // card for readings that are a few digits long.
  static const double _actualWidth = 100;

  bool get _noActualRequired => item.noActualRequired;
  bool get _noExpectedValue {
    final v = item.expectedValue?.trim();
    return v == null || v.isEmpty || v == '-';
  }

  Color get _accentColor {
    if (state.pass) return TestResult.pass.color;
    if (state.fail) return TestResult.fail.color;
    if (state.na) return TestResult.na.color;
    return const Color(0xFFDDE3EA);
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      color: brandGrey,
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      clipBehavior: Clip.hardEdge,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 5,
              color: _accentColor,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Column headings on every line, as in the mockup the
                    // user chose on 2026-09-30. A line with no test value or no
                    // reading shows "-" in that column rather than dropping
                    // it, so the columns sit in the same place on every card.
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text('Test Description', style: labelStyle),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Test Value',
                            style: labelStyle,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: _actualWidth,
                          child: Text(
                            'Actual',
                            style: labelStyle,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Description + expected + actual row
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            item.description ?? '',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: Text(
                            _noExpectedValue ? '-' : item.expectedValue!,
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: _actualWidth,
                          // '-' is the register saying there is nothing to
                          // measure on this line; the server counts it complete.
                          child: _noActualRequired
                              ? Text(
                                  '-',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  textAlign: TextAlign.center,
                                )
                              : ActualValueField(
                                  key: ValueKey(item.id),
                                  initialValue: state.actualValue,
                                  onChanged: (v) {
                                    onChanged(
                                      _OutputState()
                                        ..actualValue = v
                                        ..notes = state.notes
                                        ..pass = state.pass
                                        ..fail = state.fail
                                        ..na = state.na,
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ResultRadioRow(
                      value: state.pass
                          ? TestResult.pass
                          : state.fail
                          ? TestResult.fail
                          : state.na
                          ? TestResult.na
                          : null,
                      onSelected: (r) => onChanged(
                        _OutputState()
                          ..actualValue = state.actualValue
                          ..notes = state.notes
                          ..pass = r == TestResult.pass
                          ..fail = r == TestResult.fail
                          ..na = r == TestResult.na,
                      ),
                    ),
                    // Template note (read-only reference from TestTempNotes)
                    if (item.notes != null && item.notes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF374151),
                          ),
                          children: [
                            const TextSpan(
                              text: 'Notes: ',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            TextSpan(
                              text: item.notes!,
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
