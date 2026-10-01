import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/dashboard_providers.dart';

// The module tiles' background colours — Work Order, PM Work Order and
// Certificate — as the user asked (2026-10-01).
const _wo = Color(0xFFE8EEF8);
const _pm = Color(0xFFEAF4EA);
const _certs = Color(0xFFE6F3F4);

/// The dark block under the app bar: what is still on the phone.
///
/// The ring is the three counts in their colours; its centre is their total
/// and "to sync", or a tick and "All synced" when nothing is waiting.
class SyncSummary extends StatelessWidget {
  const SyncSummary({super.key, required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final allSynced = stats.total == 0;
    final sections = allSynced
        ? [PieChartSectionData(value: 1, color: _pm, radius: 12, title: '')]
        : [
            if (stats.woToSync > 0)
              PieChartSectionData(
                value: stats.woToSync.toDouble(),
                color: _wo,
                radius: 12,
                title: '',
              ),
            if (stats.pmWoToSync > 0)
              PieChartSectionData(
                value: stats.pmWoToSync.toDouble(),
                color: _pm,
                radius: 12,
                title: '',
              ),
            if (stats.certsToSync > 0)
              PieChartSectionData(
                value: stats.certsToSync.toDouble(),
                color: _certs,
                radius: 12,
                title: '',
              ),
          ];

    return Container(
      color: brandDark,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 34,
                    sectionsSpace: 0,
                  ),
                ),
                if (allSynced)
                  const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_rounded,
                        color: Color(0xFF7CD992),
                        size: 24,
                      ),
                      Text(
                        'All synced',
                        style: TextStyle(
                          color: Color(0xFFC9D6E0),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${stats.total}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                      const Text(
                        'to sync',
                        style: TextStyle(
                          color: Color(0xFFC9D6E0),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                _Line(color: _wo, label: 'WO to Sync', count: stats.woToSync),
                const SizedBox(height: 8),
                _Line(
                  color: _pm,
                  label: 'PM WO to Sync',
                  count: stats.pmWoToSync,
                ),
                const SizedBox(height: 8),
                _Line(
                  color: _certs,
                  label: 'Certs to Sync',
                  count: stats.certsToSync,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.color, required this.label, required this.count});

  final Color color;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
      Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}
