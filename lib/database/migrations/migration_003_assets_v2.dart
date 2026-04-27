import 'package:sqflite/sqflite.dart';

Future<void> migration003AssetsV2(Database db) async {
  // Rescue provisional records before dropping the old schema.
  // Old columns: name (→ equipment_type), department (→ location).
  // Provisionals have is_provisional=1 and no asset_id.
  await db.execute('''
    CREATE TABLE IF NOT EXISTS assets_prov_rescue (
      equipment_type TEXT NOT NULL,
      model          TEXT,
      manufacturer   TEXT,
      serial_number  TEXT,
      hospital       TEXT,
      location       TEXT,
      created_at     TEXT NOT NULL,
      updated_at     TEXT NOT NULL
    )
  ''');

  // Safe on v1→v4 upgrades where the old assets table may not exist yet.
  try {
    await db.rawInsert('''
      INSERT INTO assets_prov_rescue
        (equipment_type, model, manufacturer, serial_number,
         hospital, location, created_at, updated_at)
      SELECT
        COALESCE(name, 'Unknown'),
        model, manufacturer, serial_number,
        account_name,
        department,
        created_at, updated_at
      FROM assets
      WHERE is_provisional = 1
    ''');
  } catch (_) {
    // No existing assets table — nothing to rescue.
  }

  await db.execute('DROP TABLE IF EXISTS assets');

  await db.execute('''
    CREATE TABLE assets (
      id                INTEGER PRIMARY KEY AUTOINCREMENT,
      asset_id          INTEGER UNIQUE,
      equipment_type    TEXT    NOT NULL,
      model             TEXT,
      manufacturer      TEXT,
      serial_number     TEXT,
      barcode           TEXT,
      hospital          TEXT,
      location          TEXT,
      condition         TEXT,
      is_active         INTEGER NOT NULL DEFAULT 1,
      is_condemned      INTEGER NOT NULL DEFAULT 0,
      next_service_date TEXT,
      is_provisional    INTEGER NOT NULL DEFAULT 0,
      synced_at         TEXT,
      created_at        TEXT    NOT NULL,
      updated_at        TEXT    NOT NULL
    )
  ''');

  await db.execute(
      'CREATE INDEX assets_barcode_idx ON assets (barcode)');
  await db.execute(
      'CREATE INDEX assets_hospital_idx ON assets (hospital)');

  // Restore rescued provisionals into the new table.
  await db.rawInsert('''
    INSERT INTO assets
      (equipment_type, model, manufacturer, serial_number,
       hospital, location, is_active, is_condemned, is_provisional,
       created_at, updated_at)
    SELECT
      equipment_type, model, manufacturer, serial_number,
      hospital, location, 1, 0, 1,
      created_at, updated_at
    FROM assets_prov_rescue
  ''');

  await db.execute('DROP TABLE assets_prov_rescue');
}
