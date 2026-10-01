import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/work_order_summary.dart';
import '../providers/work_order_providers.dart';
import 'work_order_detail_screen.dart';

/// The signed-in technician's captured work orders.
class WorkOrderListScreen extends ConsumerWidget {
  const WorkOrderListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(worklistProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Work Orders')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(worklistProvider.future),
        child: list.when(
          // Every state is a ListView that can always be dragged: a list that
          // does not overflow cannot be overscrolled, so without this the
          // "pull to retry" in the short states could never fire.
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              Padding(
                padding: EdgeInsets.all(24),
                child: Text('Work orders could not be read — pull to retry'),
              ),
            ],
          ),
          data: (w) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (!w.syncedComplete)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Synced work orders still loading — pull to retry',
                  ),
                ),
              if (w.items.isEmpty && w.syncedComplete)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No work orders yet')),
                ),
              for (final item in w.items) _Row(item: item),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item});
  final WorkOrderSummary item;

  @override
  Widget build(BuildContext context) {
    final asset = item.asset;
    final setAside = item.queueState == WorkOrderQueueState.setAside;
    final colour = switch (item.queueState) {
      WorkOrderQueueState.waiting => const Color(0xFFE65100),
      WorkOrderQueueState.setAside => brandError,
      null => const Color(0xFF2E7D32),
    };
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text(item.trackId == null ? 'Pending' : 'WO ${item.trackId}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                if (item.dateIn != null)
                  DateFormat('dd MMM yyyy').format(item.dateIn!),
                ?item.workType?.label,
              ].join(' · '),
            ),
            if (asset != null)
              Text(
                [
                  asset.equipment,
                  asset.serial,
                  asset.hospital,
                ].whereType<String>().join(' · '),
              ),
            if (setAside && item.message != null)
              Text(item.message!, style: const TextStyle(color: brandError)),
          ],
        ),
        trailing: Text(item.status, style: TextStyle(color: colour)),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => WorkOrderDetailScreen(
              trackId: item.trackId,
              mobileId: item.mobileId,
            ),
          ),
        ),
      ),
    );
  }
}
