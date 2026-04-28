import '../database/database_helper.dart';

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
  }
}
