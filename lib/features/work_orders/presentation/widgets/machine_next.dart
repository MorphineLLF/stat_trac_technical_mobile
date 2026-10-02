import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/work_order_providers.dart';

/// The machine step's way on, or the reason there is none.
///
/// **A machine with an open work order offers no Next** (the user's rule,
/// 2026-10-02): the server refuses a second capture on it, so going on would
/// only fill in a job card that cannot be sent. Greyed out while the check
/// runs, so a quick tap cannot get past it. If the phone's copy cannot be
/// read, Next stands and the server decides — it is a cache, not the rule.
class MachineNext extends ConsumerWidget {
  const MachineNext({super.key, required this.assetId, required this.onNext});

  final int assetId;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final check = ref.watch(openRepairOnAssetProvider(assetId));
    final open = check.asData?.value;

    if (open != null) {
      return Card(
        color: const Color(0xFFFFF8E1),
        child: ListTile(
          leading: const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFE65100),
          ),
          title: Text(
            'Work order $open is still open on this machine '
            '(as of last sync).',
          ),
          subtitle: const Text('The server will refuse a second one.'),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: FilledButton(
        onPressed: check.isLoading ? null : onNext,
        child: const Text('Next'),
      ),
    );
  }
}
