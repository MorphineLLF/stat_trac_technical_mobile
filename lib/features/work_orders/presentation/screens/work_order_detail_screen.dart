import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../assets/data/datasources/asset_local_data_source.dart';
import '../../../assets/domain/entities/asset.dart';
import '../../domain/entities/work_order.dart';
import '../../domain/entities/work_order_enums.dart';
import '../providers/work_order_providers.dart';

class WorkOrderDetailScreen extends ConsumerWidget {
  const WorkOrderDetailScreen({super.key, required this.workOrderId});
  final int workOrderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final woAsync = ref.watch(workOrderDetailProvider(workOrderId));

    return Scaffold(
      appBar: AppBar(
        title: woAsync.when(
          data: (wo) => Text(wo?.woNumber ?? 'Work Order'),
          loading: () => const Text('Work Order'),
          error: (_, e) => const Text('Work Order'),
        ),
        actions: [
          woAsync.when(
            data: (wo) => wo != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _StatusChip(status: wo.status),
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, e) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: woAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
        data: (wo) => wo == null
            ? const Center(child: Text('Work order not found'))
            : _WorkOrderBody(wo: wo),
      ),
    );
  }
}

// ── Main body ─────────────────────────────────────────────────────────────────

class _WorkOrderBody extends ConsumerWidget {
  const _WorkOrderBody({required this.wo});
  final WorkOrder wo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync =
        ref.watch(workOrderStatusHistoryProvider(wo.id));

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderCard(wo: wo),
                const SizedBox(height: 12),
                if (wo.symptomDescription != null) ...[
                  _DescriptionCard(wo: wo),
                  const SizedBox(height: 12),
                ],
                _TimingCard(wo: wo),
                const SizedBox(height: 12),
                if (_isEditable(wo.status)) ...[
                  _ResolutionCard(wo: wo),
                  const SizedBox(height: 12),
                ],
                historyAsync.when(
                  data: (h) => h.isEmpty
                      ? const SizedBox.shrink()
                      : _StatusHistoryCard(history: h),
                  loading: () => const SizedBox.shrink(),
                  error: (_, e) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
        _TransitionBar(wo: wo),
      ],
    );
  }

  bool _isEditable(WoStatus s) =>
      s == WoStatus.inProgress ||
      s == WoStatus.paused ||
      s == WoStatus.awaitingParts ||
      s == WoStatus.onSite;
}

// ── Header card ───────────────────────────────────────────────────────────────

class _HeaderCard extends ConsumerWidget {
  const _HeaderCard({required this.wo});
  final WorkOrder wo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _TypeBadge(type: wo.type),
                const SizedBox(width: 8),
                _PriorityBadge(priority: wo.priority),
                const Spacer(),
                if (wo.isOverdue)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: brandError.withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: brandError),
                    ),
                    child: const Text(
                      'OVERDUE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: brandError,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.tag,
              label: 'WO Number',
              value: wo.woNumber,
            ),
            if (wo.assetId != null)
              _AsyncAssetRow(
                assetId: wo.assetId!,
                dataSource: ref.watch(assetLocalDataSourceProvider),
              ),
            if (wo.slaDueAt != null)
              _DetailRow(
                icon: Icons.timer_outlined,
                label: 'SLA Due',
                value: DateFormat('dd MMM yyyy HH:mm').format(wo.slaDueAt!),
                valueColor: wo.isOverdue ? brandError : null,
              ),
            if (wo.scheduledStart != null)
              _DetailRow(
                icon: Icons.calendar_today_outlined,
                label: 'Scheduled',
                value:
                    DateFormat('dd MMM yyyy HH:mm').format(wo.scheduledStart!),
              ),
            _DetailRow(
              icon: Icons.info_outline,
              label: 'Origin',
              value: wo.origin.value,
            ),
          ],
        ),
      ),
    );
  }
}

class _AsyncAssetRow extends StatefulWidget {
  const _AsyncAssetRow({
    required this.assetId,
    required this.dataSource,
  });
  final int assetId;
  final AssetLocalDataSource dataSource;

  @override
  State<_AsyncAssetRow> createState() => _AsyncAssetRowState();
}

class _AsyncAssetRowState extends State<_AsyncAssetRow> {
  Asset? _asset;

  @override
  void initState() {
    super.initState();
    widget.dataSource.getAssetById(widget.assetId).then((a) {
      if (mounted) setState(() => _asset = a);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_asset == null) {
      return _DetailRow(
        icon: Icons.medical_services_outlined,
        label: 'Asset',
        value: '#${widget.assetId}',
      );
    }
    return _DetailRow(
      icon: Icons.medical_services_outlined,
      label: 'Asset',
      value: _asset!.displayName,
      badge: _asset!.isProvisional ? 'PROVISIONAL' : null,
      badgeColor: const Color(0xFFF57F17),
    );
  }
}

// ── Description card ──────────────────────────────────────────────────────────

class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({required this.wo});
  final WorkOrder wo;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Symptom Description',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(wo.symptomDescription!,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

// ── Timing card ───────────────────────────────────────────────────────────────

class _TimingCard extends StatelessWidget {
  const _TimingCard({required this.wo});
  final WorkOrder wo;

  @override
  Widget build(BuildContext context) {
    final times = [
      if (wo.acceptedAt != null)
        ('Accepted', wo.acceptedAt!),
      if (wo.enRouteAt != null)
        ('En Route', wo.enRouteAt!),
      if (wo.onSiteAt != null)
        ('On Site', wo.onSiteAt!),
      if (wo.startedAt != null)
        ('Started', wo.startedAt!),
      if (wo.completedAt != null)
        ('Completed', wo.completedAt!),
    ];

    if (times.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Timeline',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...times.map((t) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: _DetailRow(
                    icon: Icons.access_time,
                    label: t.$1,
                    value: DateFormat('dd MMM yyyy HH:mm').format(t.$2),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

// ── Resolution card ───────────────────────────────────────────────────────────

class _ResolutionCard extends ConsumerStatefulWidget {
  const _ResolutionCard({required this.wo});
  final WorkOrder wo;

  @override
  ConsumerState<_ResolutionCard> createState() => _ResolutionCardState();
}

class _ResolutionCardState extends ConsumerState<_ResolutionCard> {
  late final TextEditingController _narrativeCtrl;

  @override
  void initState() {
    super.initState();
    _narrativeCtrl =
        TextEditingController(text: widget.wo.resolutionNarrative);
  }

  @override
  void dispose() {
    _narrativeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resolution',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            TextFormField(
              controller: _narrativeCtrl,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Resolution Narrative',
                hintText: 'Describe what was done…',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Status history card ───────────────────────────────────────────────────────

class _StatusHistoryCard extends StatelessWidget {
  const _StatusHistoryCard({required this.history});
  final List<WorkOrderStatusHistory> history;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status History',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            ...history.reversed.map((h) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 5),
                        decoration: const BoxDecoration(
                          color: brandTeal,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              h.newStatus.value.replaceAll('_', ' '),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                      fontWeight: FontWeight.w600),
                            ),
                            Text(
                              DateFormat('dd MMM yyyy HH:mm')
                                  .format(h.changedAt),
                              style:
                                  Theme.of(context).textTheme.bodySmall,
                            ),
                            if (h.notes != null && h.notes!.isNotEmpty)
                              Text(h.notes!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

// ── Transition bar ────────────────────────────────────────────────────────────

class _TransitionBar extends ConsumerWidget {
  const _TransitionBar({required this.wo});
  final WorkOrder wo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transitions = _availableTransitions(wo.status);
    if (transitions.isEmpty) return const SizedBox.shrink();

    final actionsState = ref.watch(workOrderActionsProvider);
    final isBusy = actionsState is AsyncLoading;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: const Color(0xFFDDE3EA)),
        ),
      ),
      child: Row(
        children: transitions.map((t) {
          final isDestructive = t.toStatus == WoStatus.cancelled ||
              t.toStatus == WoStatus.rejected;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: isDestructive
                  ? OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: brandError,
                        side: const BorderSide(color: brandError),
                      ),
                      onPressed: isBusy
                          ? null
                          : () => _confirmTransition(context, ref, t),
                      child: Text(t.label),
                    )
                  : FilledButton(
                      onPressed: isBusy
                          ? null
                          : () => _doTransition(ref, t.toStatus),
                      child: isBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(t.label),
                    ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _doTransition(WidgetRef ref, WoStatus toStatus) async {
    await ref
        .read(workOrderActionsProvider.notifier)
        .transition(wo.id, toStatus);
  }

  Future<void> _confirmTransition(
    BuildContext context,
    WidgetRef ref,
    _Transition t,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.label),
        content: Text('Confirm: ${t.label} this work order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: brandError),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(workOrderActionsProvider.notifier)
          .transition(wo.id, t.toStatus);
    }
  }

  List<_Transition> _availableTransitions(WoStatus status) {
    return switch (status) {
      WoStatus.assigned => [
          _Transition('Accept', WoStatus.accepted),
          _Transition('Reject', WoStatus.rejected),
        ],
      WoStatus.accepted => [
          _Transition('En Route', WoStatus.enRoute),
        ],
      WoStatus.enRoute => [
          _Transition('On Site', WoStatus.onSite),
        ],
      WoStatus.onSite => [
          _Transition('Start Work', WoStatus.inProgress),
        ],
      WoStatus.created => [
          _Transition('Start Work', WoStatus.inProgress),
        ],
      WoStatus.inProgress => [
          _Transition('Pause', WoStatus.paused),
          _Transition('Awaiting Parts', WoStatus.awaitingParts),
          _Transition('Complete', WoStatus.completed),
        ],
      WoStatus.paused => [
          _Transition('Resume', WoStatus.inProgress),
        ],
      WoStatus.awaitingParts => [
          _Transition('Resume', WoStatus.inProgress),
        ],
      _ => [],
    };
  }
}

class _Transition {
  const _Transition(this.label, this.toStatus);
  final String label;
  final WoStatus toStatus;
}

// ── Shared detail widgets ────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.badge,
    this.badgeColor,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final String? badge;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: brandGrey),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(label,
                style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: valueColor),
            ),
          ),
          if (badge != null && badgeColor != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor!.withAlpha(30),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: badgeColor!),
              ),
              child: Text(
                badge!,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: badgeColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final WoType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: brandTeal.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: brandTeal.withAlpha(80)),
      ),
      child: Text(
        type.value,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: brandTeal,
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});
  final WoPriority priority;

  static const _colors = {
    WoPriority.p1: Color(0xFFB71C1C),
    WoPriority.p2: Color(0xFFE65100),
    WoPriority.p3: Color(0xFFF9A825),
    WoPriority.p4: Color(0xFF2E7D32),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[priority]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        priority.value,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final WoStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white54),
      ),
      child: Text(
        status.value.replaceAll('_', ' ').toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
