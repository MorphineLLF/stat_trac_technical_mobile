import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/register_part.dart';
import '../../domain/work_order_job.dart';
import 'part_picker_sheet.dart';

/// "Parts" — or with [charged] "Charged rates" — on the job card: its own
/// lines, Add, and a remove per line. No prices.
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          charged ? 'Charged rates' : 'Parts',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        for (var i = 0; i < parts.length; i++)
          if (parts[i].isCharged == charged)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(parts[i].label),
              subtitle: _errorOn(i) == null
                  ? null
                  : Text(
                      _errorOn(i)!,
                      style: const TextStyle(color: brandError),
                    ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('× ${parts[i].qtyText}'),
                  IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.close),
                    onPressed: () => onChanged([...parts]..removeAt(i)),
                  ),
                ],
              ),
            ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _add(context),
            icon: const Icon(Icons.add),
            label: Text(charged ? 'Add charged rate' : 'Add part'),
          ),
        ),
      ],
    );
  }
}
