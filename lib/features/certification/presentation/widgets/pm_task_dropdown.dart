import 'package:flutter/material.dart';

import '../../domain/entities/asset_pm_task.dart';

/// Which of the asset's PM tasks this certificate is for — by description
/// only, e.g. "Annual service".
///
/// Replaces a greyed, locked box for a single task (it read as a placeholder)
/// and a row of chips for several. Keyed by task id, not description: one
/// asset can carry two tasks with the same wording.
class PmTaskDropdown extends StatelessWidget {
  const PmTaskDropdown({
    super.key,
    required this.tasks,
    required this.selectedId,
    required this.onSelected,
  });

  final List<AssetPmTask> tasks;
  final int? selectedId;
  final ValueChanged<AssetPmTask> onSelected;

  @override
  Widget build(BuildContext context) {
    final known = tasks.any((t) => t.pmTaskId == selectedId);
    return DropdownButtonFormField<int>(
      // The parent auto-selects a lone task after the first frame; the key
      // makes the field show that choice rather than its first, empty value.
      key: ValueKey(selectedId),
      initialValue: known ? selectedId : null,
      isExpanded: true,
      hint: const Text('Select PM task'),
      items: [
        for (final t in tasks)
          DropdownMenuItem(
            value: t.pmTaskId,
            child: Text(t.description, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (id) {
        if (id == null) return;
        onSelected(tasks.firstWhere((t) => t.pmTaskId == id));
      },
    );
  }
}
