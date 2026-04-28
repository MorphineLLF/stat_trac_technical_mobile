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
import '../../../work_orders/presentation/screens/create_work_order_screen.dart';
import '../../../work_orders/presentation/screens/work_order_list_screen.dart';
import '../providers/dashboard_providers.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _navIndex = 0;

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
    final lastSynced = ref.watch(lastSyncedAtProvider);
    final syncState = ref.watch(syncProvider);
    final isSyncing = syncState is SyncInProgress;

    ref.listen(syncProvider, (_, next) {
      if (next is SyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: ${next.message}'),
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
          _LastSyncedLabel(lastSynced: lastSynced, isSyncing: isSyncing),
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync now',
            onPressed: isSyncing
                ? null
                : () => ref.read(syncProvider.notifier).triggerSync(),
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
      childAspectRatio: 1.4,
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
        const _QuickActionTile(
          icon: Icons.verified_outlined,
          label: 'Create Certificate',
          color: brandTeal,
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
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
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

// ── AppBar: last synced label ─────────────────────────────────────────────────

class _LastSyncedLabel extends StatelessWidget {
  const _LastSyncedLabel({required this.lastSynced, required this.isSyncing});
  final DateTime? lastSynced;
  final bool isSyncing;

  @override
  Widget build(BuildContext context) {
    if (isSyncing) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final label = lastSynced == null
        ? 'Not synced'
        : 'Last synced: ${DateFormat('dd MMM yyyy HH:mm').format(lastSynced!)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: lastSynced == null
                ? Colors.white60
                : const Color(0xFF4CAF50),
          ),
        ),
      ),
    );
  }
}
