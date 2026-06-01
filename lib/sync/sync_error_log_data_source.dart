import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';

@immutable
class SyncErrorEntry {
  const SyncErrorEntry({
    required this.operation,
    required this.errorMessage,
    required this.occurredAt,
  });
  final String operation;
  final String errorMessage;
  final DateTime occurredAt;
}

abstract interface class SyncErrorLogDataSource {
  Future<void> logError({
    required String operation,
    String? entityTable,
    String? entityId,
    required String errorMessage,
    String? stackTrace,
  });

  /// Mark all unresolved rows for [operation] as resolved.
  Future<void> markResolved(String operation);

  /// Count of rows where resolved = 0.
  Future<int> unresolvedCount();

  /// All unresolved errors, newest first.
  Future<List<SyncErrorEntry>> getUnresolvedErrors();

  /// Delete rows older than 30 days where resolved = 1.
  Future<void> purgeOldResolved();
}

class SyncErrorLogDataSourceImpl implements SyncErrorLogDataSource {
  SyncErrorLogDataSourceImpl(this._db);
  final DatabaseHelper _db;

  static const _table = 'sync_error_log';

  @override
  Future<void> logError({
    required String operation,
    String? entityTable,
    String? entityId,
    required String errorMessage,
    String? stackTrace,
  }) async {
    final db = await _db.database;
    // Replace any existing unresolved row for this operation so the count
    // stays at 1 per operation rather than growing on every sync cycle.
    await db.rawDelete(
      'DELETE FROM $_table WHERE operation = ? AND resolved = 0',
      [operation],
    );
    await db.insert(_table, {
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
      'operation': operation,
      'entity_table': entityTable,
      'entity_id': entityId,
      'error_message': errorMessage,
      'stack_trace': stackTrace,
      'resolved': 0,
    });
  }

  @override
  Future<void> markResolved(String operation) async {
    final db = await _db.database;
    await db.rawUpdate(
      'UPDATE $_table SET resolved = 1 WHERE operation = ? AND resolved = 0',
      [operation],
    );
  }

  @override
  Future<List<SyncErrorEntry>> getUnresolvedErrors() async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT operation, error_message, occurred_at '
      'FROM $_table WHERE resolved = 0 ORDER BY occurred_at DESC',
    );
    return rows
        .map((r) => SyncErrorEntry(
              operation: r['operation'] as String,
              errorMessage: r['error_message'] as String,
              occurredAt: DateTime.parse(r['occurred_at'] as String).toLocal(),
            ))
        .toList();
  }

  @override
  Future<int> unresolvedCount() async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM $_table WHERE resolved = 0',
    );
    return (rows.first['cnt'] as int?) ?? 0;
  }

  @override
  Future<void> purgeOldResolved() async {
    final db = await _db.database;
    final cutoff = DateTime.now()
        .subtract(const Duration(days: 30))
        .toUtc()
        .toIso8601String();
    await db.rawDelete(
      'DELETE FROM $_table WHERE resolved = 1 AND occurred_at < ?',
      [cutoff],
    );
    // Remove duplicate unresolved rows per operation — keep only the latest.
    // Cleans up rows accumulated before the one-row-per-operation rule.
    await db.rawDelete(
      'DELETE FROM $_table WHERE resolved = 0 AND id NOT IN '
      '(SELECT MAX(id) FROM $_table WHERE resolved = 0 GROUP BY operation)',
    );
  }
}
