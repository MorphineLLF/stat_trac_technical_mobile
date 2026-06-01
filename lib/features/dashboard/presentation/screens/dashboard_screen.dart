import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../sync/sync_notifier.dart';
import '../../../../../sync/sync_state.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/auth_state.dart';
import '../../../assets/presentation/screens/asset_list_screen.dart';
import '../../../certification/presentation/screens/create_certificate_screen.dart';
import '../../../certification/presentation/screens/certificate_list_screen.dart';
import '../../../work_orders/presentation/screens/create_work_order_screen.dart';
import '../../../work_orders/presentation/screens/work_order_list_screen.dart';
import '../providers/dashboard_providers.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with WidgetsBindingObserver {
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncProvider.notifier).triggerSync();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(syncProvider.notifier).triggerSync();
    }
  }

  void _showSyncErrors(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _SyncErrorSheet(
        onRetry: () {
          Navigator.of(context).pop();
          ref.read(syncProvider.notifier).triggerSync();
        },
      ),
    );
  }

  void _onNavTap(int index) {
    if (index == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AssetListScreen()),
      );
      return;
    }
    if (index > 1) {
      const labels = ['', '', 'Inventory', 'Meter'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${labels[index]} — coming soon')),
      );
      return;
    }
    setState(() => _navIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncProvider);
    final isSyncing = syncState is SyncInProgress;
    final badgeCount =
        ref.watch(unresolvedSyncErrorCountProvider).asData?.value ?? 0;

    ref.listen(syncProvider, (_, next) {
      if (next is SyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    });
    final authState = ref.watch(authProvider);
    final userName = authState is AuthAuthenticated ? authState.user.name : '';

    return Scaffold(
      appBar: AppBar(
        title: Text(userName.isNotEmpty ? 'Hi, $userName' : 'Dashboard'),
        actions: [
          _SyncStatusLabel(syncState: syncState),
          Badge(
            isLabelVisible: badgeCount > 0,
            label: Text('$badgeCount'),
            child: IconButton(
              icon: const Icon(Icons.sync),
              tooltip: badgeCount > 0 ? 'Sync errors — tap to view' : 'Sync now',
              onPressed: isSyncing
                  ? null
                  : badgeCount > 0
                      ? () => _showSyncErrors(context, ref)
                      : () => ref.read(syncProvider.notifier).triggerSync(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: _navIndex == 0 ? const _HomeBody() : const _ComingSoonBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: _onNavTap,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.medical_services_outlined),
            label: 'Assets',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Inventory',
          ),
          NavigationDestination(
            icon: Icon(Icons.speed_outlined),
            label: 'Meter',
          ),
        ],
      ),
    );
  }
}

// ── Home body ─────────────────────────────────────────────────────────────────

class _HomeBody extends ConsumerWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pending task counts — WO and PM side by side
          stats.when(
            data: (s) => _PendingTasksRow(woCount: s.total, pmCount: 0),
            loading: () => const _PendingTasksRow(woCount: 0, pmCount: 0),
            error: (e, _) => const _PendingTasksRow(woCount: 0, pmCount: 0),
          ),
          const SizedBox(height: 16),
          // Donut chart + KPI row
          stats.when(
            data: (s) => Column(
              children: [
                _StatsCard(stats: s),
                const SizedBox(height: 12),
                _KpiRow(stats: s),
              ],
            ),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Stats unavailable',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          ),
          const SizedBox(height: 16),
          const _QuickActionsGrid(),
        ],
      ),
    );
  }
}

class _ComingSoonBody extends StatelessWidget {
  const _ComingSoonBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Coming soon', style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

// ── Pending tasks row (WO + PM side by side) ──────────────────────────────────

class _PendingTasksRow extends StatelessWidget {
  const _PendingTasksRow({required this.woCount, required this.pmCount});
  final int woCount;
  final int pmCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TaskCountCard(
            label: 'Work Orders',
            count: woCount,
            color: brandTeal,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TaskCountCard(
            label: 'PM Work Orders',
            count: pmCount,
            color: Color(0xFF2E7D32),
          ),
        ),
      ],
    );
  }
}

class _TaskCountCard extends StatelessWidget {
  const _TaskCountCard({
    required this.label,
    required this.count,
    required this.color,
  });
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 32,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pending $label',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

// ── Donut chart card ──────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});
  final DashboardStats stats;

  static const _colorOverdue = brandError;
  static const _colorPending = Color(0xFFF57F17);
  static const _colorWip = brandTeal;
  static const _colorEmpty = Color(0xFFDDE3EA);

  @override
  Widget build(BuildContext context) {
    final sections = stats.total == 0
        ? [
            PieChartSectionData(
              value: 1,
              color: _colorEmpty,
              radius: 22,
              title: '',
            ),
          ]
        : [
            if (stats.overdue > 0)
              PieChartSectionData(
                value: stats.overdue.toDouble(),
                color: _colorOverdue,
                radius: 22,
                title: '',
              ),
            if (stats.pending > 0)
              PieChartSectionData(
                value: stats.pending.toDouble(),
                color: _colorPending,
                radius: 22,
                title: '',
              ),
            if (stats.wip > 0)
              PieChartSectionData(
                value: stats.wip.toDouble(),
                color: _colorWip,
                radius: 22,
                title: '',
              ),
          ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              height: 110,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 38,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ChartLegend(
                    color: _colorOverdue,
                    label: 'Overdue',
                    pct: stats.overduePct,
                  ),
                  const SizedBox(height: 10),
                  _ChartLegend(
                    color: _colorPending,
                    label: 'Pending',
                    pct: stats.pendingPct,
                  ),
                  const SizedBox(height: 10),
                  _ChartLegend(
                    color: _colorWip,
                    label: 'Work in Progress',
                    pct: stats.wipPct,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({
    required this.color,
    required this.label,
    required this.pct,
  });
  final Color color;
  final String label;
  final double pct;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Text(
          '${(pct * 100).toStringAsFixed(0)}%',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

// ── KPI row ───────────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.stats});
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _KpiTile(
              label: 'Overdue', count: stats.overdue, color: brandError),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiTile(
              label: 'Pending',
              count: stats.pending,
              color: Color(0xFFF57F17)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              _KpiTile(label: 'WIP', count: stats.wip, color: brandTeal),
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.count,
    required this.color,
  });
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(height: 8),
            Text(
              '$count',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: color),
            ),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

// ── Quick actions grid ────────────────────────────────────────────────────────

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _QuickActionTile(
          icon: Icons.list_alt_outlined,
          label: 'Worklist',
          color: brandTeal,
          destination: (_) => const WorkOrderListScreen(),
        ),
        _QuickActionTile(
          icon: Icons.add_circle_outline,
          label: 'Create Work Order',
          color: brandTeal,
          destination: (_) => const CreateWorkOrderScreen(),
        ),
        const _QuickActionTile(
          icon: Icons.assignment_outlined,
          label: 'Create PM Order',
          color: brandTeal,
        ),
        _QuickActionTile(
          icon: Icons.verified_outlined,
          label: 'Create Certificate',
          color: brandTeal,
          destination: (_) => const CreateCertificateScreen(),
        ),
        _QuickActionTile(
          icon: Icons.workspace_premium_outlined,
          label: 'View Certificates',
          color: brandTeal,
          destination: (_) => const CertificateListScreen(),
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.color,
    this.destination,
  });
  final IconData icon;
  final String label;
  final Color color;
  final WidgetBuilder? destination;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withAlpha(20),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (destination != null) {
            Navigator.of(context)
                .push(MaterialPageRoute(builder: destination!));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$label — coming soon')),
            );
          }
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withAlpha(60)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: color),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── AppBar: sync status label ─────────────────────────────────────────────────

class _SyncStatusLabel extends StatelessWidget {
  const _SyncStatusLabel({required this.syncState});
  final SyncState syncState;

  @override
  Widget build(BuildContext context) {
    return switch (syncState) {
      SyncInProgress(:final progress, :final message) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Tooltip(
            message: message,
            child: SizedBox(
              width: 38,
              height: 38,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: progress),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                builder: (_, p, _) => Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer ring — actual progress, animates between pages.
                    CircularProgressIndicator(
                      value: p,
                      strokeWidth: 3,
                      color: Colors.white,
                      backgroundColor: Colors.white24,
                    ),
                    // Inner ring — always spinning so it's clear we're not frozen.
                    SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Colors.white38,
                      ),
                    ),
                    Text(
                      '${(p * 100).round()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      SyncComplete(:final lastSyncedAt) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline,
                  size: 14, color: Color(0xFF4CAF50)),
              const SizedBox(width: 4),
              Text(
                DateFormat('dd MMM HH:mm').format(lastSyncedAt),
                style: const TextStyle(fontSize: 12, color: Color(0xFF4CAF50)),
              ),
            ],
          ),
        ),
      SyncError(:final lastSyncedAt) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 14, color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 4),
              Text(
                lastSyncedAt != null
                    ? 'Sync failed · ${DateFormat('dd MMM HH:mm').format(lastSyncedAt)}'
                    : 'Sync failed',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
        ),
      _ => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Not synced',
            style: TextStyle(fontSize: 12, color: Colors.white60),
          ),
        ),
    };
  }
}

// ── Sync error sheet ──────────────────────────────────────────────────────────

class _SyncErrorSheet extends ConsumerWidget {
  const _SyncErrorSheet({required this.onRetry});
  final VoidCallback onRetry;

  static const _labels = <String, String>{
    'sync_assets':       'Asset sync failed',
    'sync_templates':    'Template sync failed',
    'push_certificates': 'Certificate upload failed',
    'pull_certificates': 'Certificate download failed',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final errorsAsync = ref.watch(unresolvedSyncErrorsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 8),
              Text('Sync Errors',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      )),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'These operations failed on the last sync.\nTapping Retry will attempt them again.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: brandGrey),
          ),
          const SizedBox(height: 16),
          errorsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Could not load errors: $e'),
            data: (errors) => errors.isEmpty
                ? const Text('No unresolved errors.')
                : Column(
                    children: errors
                        .map((e) => _ErrorTile(entry: e, labels: _labels))
                        .toList(),
                  ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.sync),
              label: const Text('Retry Sync'),
              onPressed: onRetry,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  const _ErrorTile({required this.entry, required this.labels});
  final SyncErrorEntry entry;
  final Map<String, String> labels;

  @override
  Widget build(BuildContext context) {
    final label = labels[entry.operation] ?? entry.operation;
    final ago = _timeAgo(entry.occurredAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: brandError),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(label,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                    Text(ago,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: brandGrey)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  entry.errorMessage,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: brandGrey),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
