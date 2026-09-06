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
import '../../../../sync/powersync_providers.dart';
import '../../../../sync/sync_indicator.dart';
import '../../../../sync/upload/upload_providers.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with WidgetsBindingObserver {
  int _navIndex = 0;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
      // Horse-era sync is DISABLED. Its endpoints (/assets, /sync/log) were
      // the retired Horse API's and do not exist on the Go host, so every
      // cycle 404s forever against a server that cannot answer -- confirmed
      // in the server's nginx log. Nothing is lost by stopping it: the 404s
      // meant it was already populating nothing.
      //
      // PowerSync now owns reads. The screens still read the OLD local
      // tables, so they stay empty until each feature is repointed at the
      // PowerSync schema -- that is the remaining migration work, tracked in
      // docs/superpowers/specs/2026-09-05-powersync-migration-design.md.
      // ref.read(syncProvider.notifier).triggerSync();

    // Uploads ARE driven from here. PowerSync only pulls; a certificate the
    // technician finished goes out through our own outbox, and something has
    // to start it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _drainUploads());
  }

  /// The manual "send now" action.
  ///
  /// Unlike the automatic drain this one always reports back, including when
  /// there was nothing to send. A technician who presses a button and sees
  /// nothing happen cannot tell success from a dead button, and this is the
  /// button they will press before leaving a hospital.
  Future<void> _sendNow() async {
    setState(() => _syncing = true);
    try {
      final worker = await ref.read(uploadWorkerProvider.future);
      final r = await worker.drain();
      // Both, not just the badge. The "Certs to Sync" tile reads the same
      // outbox and was left showing a count for work that had already gone —
      // an indicator that cannot reach the state reality is in.
      ref.invalidate(pendingUploadCountProvider);
      ref.invalidate(dashboardStatsProvider);
      if (!mounted) return;

      final String message;
      Color? colour;
      if (r.attempted == 0) {
        message = 'Nothing waiting to send.';
      } else if (r.stoppedForSignal) {
        message = 'No connection — ${r.attempted} still queued, '
            'it will go when you are back online.';
        colour = const Color(0xFFFFB300);
      } else if (r.rejected > 0 || r.failed > 0) {
        message = '${r.rejected + r.failed} could not be sent — '
            'open the certificate to see why.';
        colour = Theme.of(context).colorScheme.error;
      } else if (r.conflicted > 0) {
        message = '${r.conflicted} changed on the server and need you.';
        colour = const Color(0xFFFFB300);
      } else if (r.unguaranteed > 0) {
        // The upload succeeded and that is exactly the problem: this server
        // will not promise a reading must name its certificate, and one that
        // did not orphaned 46 of them while reporting success.
        message = 'Sent, but this server does not guarantee readings are '
            'attached — report before doing more certificates.';
        colour = Theme.of(context).colorScheme.error;
      } else if (r.shortApplied > 0) {
        // The server said yes and applied less than it was sent. Reporting
        // this green is what let a certificate be filed with no test data
        // against it and nobody know.
        message = '${r.shortApplied} certificate'
            '${r.shortApplied == 1 ? '' : 's'} reached the server without '
            'all readings — do not leave site, report this.';
        colour = Theme.of(context).colorScheme.error;
      } else {
        message = 'Sent ${r.applied} certificate'
            '${r.applied == 1 ? '' : 's'}.';
        colour = const Color(0xFF2E7D32);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: colour),
      );
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not send: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  /// Sends whatever is waiting in the outbox.
  ///
  /// Safe to call at any time: it does nothing when the queue is empty or
  /// nobody is signed in, and it stops itself the moment the server cannot be
  /// reached rather than working through a queue that will fail identically.
  Future<void> _drainUploads() async {
    try {
      final worker = await ref.read(uploadWorkerProvider.future);
      final result = await worker.drain();
      if (result.attempted > 0 && mounted) {
        ref.invalidate(pendingUploadCountProvider);
      }
    } on Exception {
      // Never surfaced here. A failed drain leaves the work queued, which is
      // the whole point of the queue -- and an error banner on the dashboard
      // for something that will retry on its own trains people to ignore
      // banners.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Horse-era sync disabled -- see initState. PowerSync reconnects on
      // its own when the app resumes.
      // ref.read(syncProvider.notifier).triggerSync();

      // Coming back to the app is the most likely moment for signal to have
      // returned -- a technician walking out of a basement.
      _drainUploads();
    }
  }

  // _showSyncErrors removed with the Horse-era badge that opened it. The
  // error sheet listed sync_error_log rows that can no longer be resolved.

  void _onNavTap(int index) {
    if (index == 1) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const AssetListScreen()));
      return;
    }
    if (index > 1) {
      const labels = ['', '', 'Inventory', 'Meter'];
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${labels[index]} — coming soon')));
      return;
    }
    setState(() => _navIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncProvider);

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
          const _PowerSyncStatus(),
          const _PendingUploads(),
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Send finished work now',
            onPressed: _syncing ? null : _sendNow,
          ),
          if (syncState is SyncInProgress)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Tooltip(
                message: syncState.message,
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: syncState.progress),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                    builder: (_, p, _) => Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: p,
                          strokeWidth: 3,
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                        ),
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
          if (syncState is SyncError)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                Icons.error_outline,
                size: 20,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          if (syncState is SyncComplete)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: _SyncDonePill(lastSyncedAt: syncState.lastSyncedAt),
            ),
          // The Horse-era sync badge and its manual trigger are REMOVED.
          //
          // The badge counted unresolved rows in sync_error_log, and those are
          // cleared only by a SUCCESSFUL Horse sync -- which can never happen
          // again, because that engine is disabled and its endpoints 404. So
          // the badge was stuck permanently at 1 from the last 404 before it
          // was switched off, reporting failure while PowerSync was healthy.
          //
          // That is the rule from docs/STATE-2026-09-05.md: an indicator must
          // be able to reach every state reality can reach, including the good
          // one. Retiring the engine without retiring its error surface left
          // exactly that defect behind. PowerSync's own status is shown by
          // _PowerSyncStatus, which can reach every state.
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
            data: (s) => _PendingTasksRow(woCount: s.overdue + s.pending, pmCount: 0, certsCount: s.pendingCerts),
            loading: () => const _PendingTasksRow(woCount: 0, pmCount: 0, certsCount: 0),
            error: (e, _) => const _PendingTasksRow(woCount: 0, pmCount: 0, certsCount: 0),
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
              child: Text(
                'Stats unavailable',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _ModuleGrid(),
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
  const _PendingTasksRow({
    required this.woCount,
    required this.pmCount,
    required this.certsCount,
  });
  final int woCount;
  final int pmCount;
  final int certsCount;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _TaskCountCard(
              label: 'Pending Work Orders',
              count: woCount,
              color: brandTeal,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TaskCountCard(
              label: 'Pending PM Orders',
              count: pmCount,
              color: Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TaskCountCard(
              label: 'Certs to Sync',
              count: certsCount,
              color: Color(0xFF00838F),
            ),
          ),
        ],
      ),
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
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
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
  static const _colorPendingCerts = Color(0xFF00838F);
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
            if (stats.pendingCerts > 0)
              PieChartSectionData(
                value: stats.pendingCerts.toDouble(),
                color: _colorPendingCerts,
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
                    color: _colorPendingCerts,
                    label: 'Certs to sync',
                    pct: stats.pendingCertsPct,
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
            label: 'Overdue',
            count: stats.overdue,
            color: brandError,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiTile(
            label: 'Pending',
            count: stats.pending,
            color: Color(0xFFF57F17),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiTile(
            label: 'Certs to sync',
            count: stats.pendingCerts,
            color: Color(0xFF00838F),
          ),
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
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: color),
            ),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

// ── Module grid ───────────────────────────────────────────────────────────────

class _TileAction {
  const _TileAction({
    required this.label,
    required this.icon,
    this.destination,
  });
  final String label;
  final IconData icon;
  final WidgetBuilder? destination;
}

class _ModuleGrid extends StatelessWidget {
  const _ModuleGrid();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _ModuleTile(
                  icon: Icons.list_alt_outlined,
                  label: 'Worklist',
                  color: brandTeal,
                  actions: [
                    _TileAction(
                      label: 'View',
                      icon: Icons.visibility_outlined,
                      destination: (_) => const WorkOrderListScreen(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ModuleTile(
                  icon: Icons.build_outlined,
                  label: 'Work Order',
                  color: const Color(0xFF1565C0),
                  actions: [
                    _TileAction(
                      label: 'Create',
                      icon: Icons.add_circle_outline,
                      destination: (_) => const CreateWorkOrderScreen(),
                    ),
                    _TileAction(
                      label: 'View',
                      icon: Icons.visibility_outlined,
                      destination: (_) => const WorkOrderListScreen(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _ModuleTile(
                  icon: Icons.assignment_outlined,
                  label: 'PM Work Order',
                  color: const Color(0xFF2E7D32),
                  actions: [
                    _TileAction(
                      label: 'Create',
                      icon: Icons.add_circle_outline,
                    ),
                    _TileAction(label: 'View', icon: Icons.visibility_outlined),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ModuleTile(
                  icon: Icons.verified_outlined,
                  label: 'Certificate',
                  color: const Color(0xFF00838F),
                  actions: [
                    _TileAction(
                      label: 'Create',
                      icon: Icons.add_circle_outline,
                      destination: (_) => const CreateCertificateScreen(),
                    ),
                    _TileAction(
                      label: 'View',
                      icon: Icons.visibility_outlined,
                      destination: (_) => const CertificateListScreen(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.actions,
  });
  final IconData icon;
  final String label;
  final Color color;
  final List<_TileAction> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (int i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(action: actions[i], color: color),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action, required this.color});
  final _TileAction action;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {
        if (action.destination != null) {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: action.destination!));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${action.label} — coming soon')),
          );
        }
      },
      icon: Icon(action.icon, size: 14),
      label: Text(action.label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withAlpha(120)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: const Size(0, 32),
        textStyle: const TextStyle(fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// ── Sync error sheet ──────────────────────────────────────────────────────────

// _SyncErrorSheet removed with the Horse-era badge: it listed sync_error_log
// rows that no successful sync can ever resolve.

class _SyncDonePill extends StatelessWidget {
  const _SyncDonePill({required this.lastSyncedAt});
  final DateTime lastSyncedAt;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(lastSyncedAt.toLocal());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.green.withAlpha(40),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withAlpha(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 14, color: Colors.green[700]),
          const SizedBox(width: 5),
          Text(
            'Synced $time',
            style: TextStyle(
              color: Colors.green[700],
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// PowerSync's real connection state.
///
/// Watching this is also what STARTS sync: `syncDatabaseProvider` is lazy, so
/// until something reads it the database is never opened or connected. The
/// dashboard is the first screen after sign-in, which is the right moment.
class _PowerSyncStatus extends ConsumerWidget {
  const _PowerSyncStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);

    return status.when(
      loading: () => const _StatusChip(
        icon: Icons.cloud_queue,
        label: 'Opening',
        color: Colors.white70,
      ),
      error: (e, _) => _StatusChip(
        icon: Icons.cloud_off,
        label: 'Sync failed',
        color: const Color(0xFFFF8A80),
        tooltip: e.toString(),
      ),
      data: (s) {
        final indicator = syncIndicatorFor(
          connected: s.connected,
          connecting: s.connecting,
          downloading: s.downloading,
          uploading: s.uploading,
          error: s.downloadError ?? s.uploadError,
        );
        // The last error is kept as a tooltip even when connected, so a
        // recovered blip is still discoverable without being alarming.
        final detail = (s.downloadError ?? s.uploadError)?.toString();

        switch (indicator) {
          case SyncIndicator.syncing:
            return const _StatusChip(
              icon: Icons.cloud_sync,
              label: 'Syncing',
              color: Colors.white,
            );
          case SyncIndicator.connected:
            final at = s.lastSyncedAt;
            return _StatusChip(
              icon: Icons.cloud_done,
              label: at == null ? 'Connected' : DateFormat('HH:mm').format(at),
              color: const Color(0xFF9CCC65),
              tooltip: detail == null ? null : 'Recovered from: $detail',
            );
          case SyncIndicator.connecting:
            return const _StatusChip(
              icon: Icons.cloud_queue,
              label: 'Connecting',
              color: Colors.white70,
            );
          case SyncIndicator.error:
            return _StatusChip(
              icon: Icons.cloud_off,
              label: 'Sync error',
              color: const Color(0xFFFF8A80),
              tooltip: detail,
            );
          case SyncIndicator.offline:
            return const _StatusChip(
              icon: Icons.cloud_off,
              label: 'Offline',
              color: Colors.white54,
            );
        }
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final chip = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Center(
        child: tooltip == null ? chip : Tooltip(message: tooltip!, child: chip),
      ),
    );
  }
}

/// How much finished work has not reached the server.
///
/// Shown only when there is something waiting, because a permanent zero is
/// noise — and hidden when it clears, so the indicator can reach every state
/// including the good one.
class _PendingUploads extends ConsumerWidget {
  const _PendingUploads();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(pendingUploadCountProvider).asData?.value ?? 0;
    if (count == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Center(
        child: Tooltip(
          message: '$count certificate${count == 1 ? '' : 's'} not yet sent',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.upload_file, size: 18, color: Color(0xFFFFB300)),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFFB300),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
