import 'package:sqflite/sqflite.dart';

/// Read-only master asset records synced from the Horse API, plus
/// provisional records created in the field pending admin registration.
Future<void> migration002Assets(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS assets (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      server_id       INTEGER,
      asset_number    TEXT    NOT NULL,
      name            TEXT    NOT NULL,
      serial_number   TEXT,
      barcode         TEXT,
      manufacturer    TEXT,
      model           TEXT,
      category        TEXT,
      account_id      INTEGER,
      account_name    TEXT,
      department      TEXT,
      condition       TEXT,
      is_provisional  INTEGER NOT NULL DEFAULT 0,
      created_at      TEXT    NOT NULL,
      updated_at      TEXT    NOT NULL
    )
  ''');
}
