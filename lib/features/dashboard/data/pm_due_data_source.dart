import 'package:flutter/foundation.dart';
import 'package:powersync/powersync.dart';

import '../../../sync/powersync_types.dart';

typedef SqlRead =
    Future<List<Map<String, Object?>>> Function(String sql, List<Object?> args);

/// One PM task due this week, as the dashboard lists it.
class PmDueTask {
  const PmDueTask({
    required this.description,
    required this.due,
    this.equipment,
    this.hospital,
  });

  final String description;
  final DateTime due;
  final String? equipment;
  final String? hospital;
}

/// Sunday of [today]'s week, date only. On a Sunday, today.
DateTime endOfWeek(DateTime today) {
  final day = DateTime(today.year, today.month, today.day);
  return day.add(Duration(days: DateTime.sunday - day.weekday));
}

/// PM tasks due from today to Sunday.
///
/// **PM is its own module.** This reads the PM schedule (`AssetPmTask`) and
/// has nothing to do with work orders.
///
/// No joins: the tasks first, the machines separately with a timeout, so a
/// slow asset store costs the names, never the list. Takes a [SqlRead] rather
/// than the database so the SQL is tested against plain SQLite tables.
class PmDueDataSource {
  PmDueDataSource(this._read, {this.timeout = const Duration(seconds: 5)});

  factory PmDueDataSource.of(PowerSyncDatabase db) =>
      PmDueDataSource((sql, args) => db.getAll(sql, args));

  final SqlRead _read;
  final Duration timeout;

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<List<PmDueTask>> dueThisWeek(DateTime today) async {
    final from = DateTime(today.year, today.month, today.day);
    final rows = await _read(
      'SELECT "PmAssetID", "PmTaskDescription", "PmTaskScheduleDate" '
      'FROM "AssetPmTask" WHERE "PmTaskActive" = 1 '
      'AND date("PmTaskScheduleDate") BETWEEN ? AND ? '
      'ORDER BY "PmTaskScheduleDate", "PmTaskDescription" LIMIT 200',
      [_date(from), _date(endOfWeek(from))],
    ).timeout(timeout);

    final ids = <int>{for (final r in rows) ?psInt(r['PmAssetID'])};
    final assets = <int, ({String? equipment, String? hospital})>{};
    if (ids.isNotEmpty) {
      try {
        final marks = List.filled(ids.length, '?').join(',');
        final found = await _read(
          'SELECT "AssetID", "AssetEquipmentType", "AssetHospital" '
          'FROM "Asset" WHERE "AssetID" IN ($marks)',
          ids.toList(),
        ).timeout(timeout);
        for (final a in found) {
          final id = psInt(a['AssetID']);
          if (id == null) continue;
          assets[id] = (
            equipment: a['AssetEquipmentType'] as String?,
            hospital: a['AssetHospital'] as String?,
          );
        }
      } catch (e) {
        debugPrint('[dashboard] PM task machines unreadable: $e');
      }
    }

    return [
      for (final r in rows)
        if (psDate(r['PmTaskScheduleDate']) case final due?)
          PmDueTask(
            description: (r['PmTaskDescription'] as String? ?? '').trim(),
            due: due,
            equipment: assets[psInt(r['PmAssetID'])]?.equipment,
            hospital: assets[psInt(r['PmAssetID'])]?.hospital,
          ),
    ];
  }
}
