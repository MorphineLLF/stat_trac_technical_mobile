import 'package:sqflite/sqflite.dart';

Future<void> migration009SyncMetadata(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS sync_metadata (
      key   TEXT PRIMARY KEY,
      value TEXT
    )
  ''');
}
