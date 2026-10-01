import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/pm_due_data_source.dart';
import '../providers/dashboard_providers.dart';

const _pm = Color(0xFF2E7D32);
const _border = Color(0xFFDDE3EA);
const _muted = Color(0xFF4A5B6C);

/// PM tasks due from today to Sunday. Fills what the dashboard has left and
/// scrolls inside itself, so the page never scrolls.
class PmDueCard extends ConsumerWidget {
  const PmDueCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(pmDueThisWeekProvider);
    final count = due.value?.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'PM TASKS DUE · THIS WEEK',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _muted,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              if (count != null)
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _pm,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: due.when(
              loading: () => const Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              ),
              error: (e, _) => const _Message('PM tasks could not be loaded'),
              data: (tasks) => tasks.isEmpty
                  ? const _Message('No PM tasks due this week')
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: tasks.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: Color(0xFFEEF1F5)),
                      itemBuilder: (_, i) => _Row(tasks[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(text, style: const TextStyle(fontSize: 14, color: _muted)),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row(this.task);
  final PmDueTask task;

  @override
  Widget build(BuildContext context) {
    final where = [?task.equipment, ?task.hospital].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: _pm, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.description,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (where.isNotEmpty)
                  Text(
                    where,
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
              ],
            ),
          ),
          Text(
            DateFormat('EEE d MMM').format(task.due),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _muted,
            ),
          ),
        ],
      ),
    );
  }
}
