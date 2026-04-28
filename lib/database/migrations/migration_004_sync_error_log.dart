import 'package:sqflite/sqflite.dart';

Future<void> migration004SyncErrorLog(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS sync_error_log (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      occurred_at   TEXT    NOT NULL,
      operation     TEXT    NOT NULL,
      entity_table  TEXT,
      entity_id     TEXT,
      error_message TEXT    NOT NULL,
      stack_trace   TEXT,
      resolved      INTEGER NOT NULL DEFAULT 0
    )
  ''');
}
