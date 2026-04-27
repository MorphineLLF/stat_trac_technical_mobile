import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/work_order.dart';
import '../../domain/entities/work_order_enums.dart';
import '../providers/work_order_providers.dart';
import 'work_order_detail_screen.dart';

class WorkOrderListScreen extends ConsumerWidget {
  const WorkOrderListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final woAsync = ref.watch(todaysWorkOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Work Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () =>
                ref.read(todaysWorkOrdersProvider.notifier).refresh(),
          ),
        ],
      ),
      body: woAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(message: e.toString()),
        data: (wos) => wos.isEmpty
            ? const _EmptyView()
            : _WorkOrderList(workOrders: wos),
      ),
    );
  }
}

// ── List ─────────────────────────────────────────────────────────────────────

class _WorkOrderList extends StatelessWidget {
  const _WorkOrderList({required this.workOrders});
  final List<WorkOrder> workOrders;

  @override
  Widget build(BuildContext context) {
    // Group by priority P1 → P4.
    final grouped = <WoPriority, List<WorkOrder>>{};
    for (final wo in workOrders) {
      grouped.putIfAbsent(wo.priority, () => []).add(wo);
    }
    final priorities = WoPriority.values
        .where((p) => grouped.containsKey(p))
        .toList();

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: priorities.fold<int>(
          0,
          (sum, p) => sum + 1 + grouped[p]!.length,
        ),
        itemBuilder: (context, index) {
          int cursor = 0;
          for (final priority in priorities) {
            if (index == cursor) {
              return _PriorityHeader(priority: priority);
            }
            cursor++;
            final items = grouped[priority]!;
            if (index < cursor + items.length) {
              return _WorkOrderCard(wo: items[index - cursor]);
            }
            cursor += items.length;
          }
          return null;
        },
      ),
    );
  }
}

// ── Priority section header ───────────────────────────────────────────────────

class _PriorityHeader extends StatelessWidget {
  const _PriorityHeader({required this.priority});
  final WoPriority priority;

  static const _colors = {
    WoPriority.p1: Color(0xFFB71C1C),
    WoPriority.p2: Color(0xFFE65100),
    WoPriority.p3: Color(0xFFF9A825),
    WoPriority.p4: Color(0xFF2E7D32),
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _colors[priority],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            priority.value,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: _colors[priority],
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Work order card ───────────────────────────────────────────────────────────

class _WorkOrderCard extends StatelessWidget {
  const _WorkOrderCard({required this.wo});
  final WorkOrder wo;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WorkOrderDetailScreen(workOrderId: wo.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    wo.woNumber,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(width: 8),
                  _TypeChip(type: wo.type),
                  const Spacer(),
                  _StatusChip(status: wo.status),
                ],
              ),
              if (wo.symptomDescription != null) ...[
                const SizedBox(height: 6),
                Text(
                  wo.symptomDescription!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    wo.slaDueAt != null
                        ? _slaLabel(wo)
                        : 'No SLA',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: wo.isOverdue
                              ? Theme.of(context).colorScheme.error
                              : null,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _slaLabel(WorkOrder wo) {
    final due = wo.slaDueAt!;
    final diff = due.difference(DateTime.now());
    if (diff.isNegative) {
      return 'Overdue ${_formatDuration(diff.abs())}';
    }
    if (diff.inHours < 24) {
      return 'Due in ${_formatDuration(diff)}';
    }
    return 'Due ${DateFormat('dd MMM HH:mm').format(due)}';
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
  }
}

// ── Chips ─────────────────────────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});
  final WoType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type.value,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final WoStatus status;

  static const _activeStatuses = {
    WoStatus.inProgress,
    WoStatus.onSite,
    WoStatus.enRoute,
  };

  @override
  Widget build(BuildContext context) {
    final isActive = _activeStatuses.contains(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.value.replaceAll('_', ' '),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isActive
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

// ── Empty / error states ──────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline,
              size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text('No work orders for today',
              style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ),
    );
  }
}
