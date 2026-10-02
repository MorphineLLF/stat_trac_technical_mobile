import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/register_part.dart';
import '../../domain/work_order_job.dart';
import 'part_picker_sheet.dart';

/// "Parts" — or with [charged] "Charged rates" — on the job card: a card with a
/// count and its own Add, each line with − and + for its quantity, and a tap to
/// edit or remove it. No prices.
///
/// Both sections share one list, the one the server receives, so [parts] and
/// [onChanged] are always the whole list: a section shows only its own kind and
/// leaves the other's lines where they are. A refusal naming `parts[<i>]...`
/// counts in the whole list and shows under that line in whichever section.
class PartsUsedSection extends StatelessWidget {
  const PartsUsedSection({
    super.key,
    required this.parts,
    required this.onChanged,
    required this.search,
    this.charged = false,
    this.error,
  });

  final List<PartUsed> parts;
  final ValueChanged<List<PartUsed>> onChanged;
  final Future<List<RegisterPart>> Function(String) search;
  final bool charged;
  final WorkOrderFieldError? error;

  String? _errorOn(int i) {
    final e = error;
    return e != null && e.field.startsWith('parts[$i].') ? e.message : null;
  }

  Future<void> _add(BuildContext context) async {
    final part = await showPartPicker(
      context,
      search: search,
      charged: charged,
    );
    if (part != null) onChanged([...parts, part]);
  }

  Future<void> _edit(BuildContext context, int i) async {
    final edit = await showPartEditor(context, parts[i]);
    if (edit == null) return;
    final next = [...parts];
    if (edit.removed) {
      next.removeAt(i);
    } else {
      next[i] = edit.part!;
    }
    onChanged(next);
  }

  void _step(int i, double by) {
    final p = parts[i];
    onChanged([...parts]..[i] = p.withQty(p.qty + by));
  }

  @override
  Widget build(BuildContext context) {
    final mine = [
      for (var i = 0; i < parts.length; i++)
        if (parts[i].isCharged == charged) i,
    ];
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    charged ? 'Charged rates' : 'Parts',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${mine.length}',
                  key: const Key('count'),
                  style: const TextStyle(color: brandGrey),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _add(context),
                  icon: const Icon(Icons.add),
                  label: Text(charged ? 'Add rate' : 'Add part'),
                ),
              ],
            ),
          ),
          if (mine.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                charged ? 'No charged rates' : 'No parts used',
                style: const TextStyle(color: brandGrey),
              ),
            ),
          for (final i in mine) ...[
            const Divider(height: 1),
            _Line(
              part: parts[i],
              index: i,
              error: _errorOn(i),
              errorColor: scheme.error,
              onTap: () => _edit(context, i),
              onLess: parts[i].qty > 1 ? () => _step(i, -1) : null,
              onMore: () => _step(i, 1),
            ),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.part,
    required this.index,
    required this.error,
    required this.errorColor,
    required this.onTap,
    required this.onLess,
    required this.onMore,
  });

  final PartUsed part;
  final int index;
  final String? error;
  final Color errorColor;
  final VoidCallback onTap;
  final VoidCallback? onLess;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final name = part.description.trim().isNotEmpty
        ? part.description.trim()
        : part.partNo.trim();
    final code = part.description.trim().isNotEmpty ? part.partNo.trim() : '';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name),
                  if (code.isNotEmpty || !part.picked)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (code.isNotEmpty)
                            Text(
                              code,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                color: brandGrey,
                              ),
                            ),
                          if (!part.picked) const _Tag('Typed'),
                        ],
                      ),
                    ),
                  if (error != null)
                    Text(error!, style: TextStyle(color: errorColor)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Less',
              icon: const Icon(Icons.remove),
              onPressed: onLess,
            ),
            Text(
              part.qtyText,
              key: Key('qty-$index'),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            IconButton(
              tooltip: 'More',
              icon: const Icon(Icons.add),
              onPressed: onMore,
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: brandTeal.withAlpha(25),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(text, style: const TextStyle(fontSize: 11, color: brandTeal)),
  );
}
