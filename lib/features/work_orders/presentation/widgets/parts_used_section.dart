import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/register_part.dart';
import '../../domain/work_order_job.dart';
import 'part_picker_sheet.dart';

/// "Parts used" on the job card: the lines, Add part, and a remove per line.
/// No prices. A refusal naming `parts[<i>]...` shows under that line.
class PartsUsedSection extends StatelessWidget {
  const PartsUsedSection({
    super.key,
    required this.parts,
    required this.onChanged,
    required this.search,
    this.error,
  });

  final List<PartUsed> parts;
  final ValueChanged<List<PartUsed>> onChanged;
  final Future<List<RegisterPart>> Function(String) search;
  final WorkOrderFieldError? error;

  String? _errorOn(int i) {
    final e = error;
    return e != null && e.field.startsWith('parts[$i].') ? e.message : null;
  }

  Future<void> _add(BuildContext context) async {
    final part = await showPartPicker(context, search: search);
    if (part != null) onChanged([...parts, part]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Parts used', style: Theme.of(context).textTheme.titleSmall),
        for (var i = 0; i < parts.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(parts[i].label),
            subtitle: _errorOn(i) == null
                ? null
                : Text(_errorOn(i)!, style: const TextStyle(color: brandError)),
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
            label: const Text('Add part'),
          ),
        ),
      ],
    );
  }
}
