// lib/database/migrations/migration_011_cert_details.dart
import 'package:sqflite/sqflite.dart';

Future<void> migration011CertDetails(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS test_equipment_assets (
      id        INTEGER PRIMARY KEY AUTOINCREMENT,
      asset_id  INTEGER NOT NULL UNIQUE,
      manufacturer TEXT,
      model        TEXT,
      serial_no    TEXT,
      cal_date     TEXT,
      synced_at    TEXT NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS test_cert_equipment (
      id             INTEGER PRIMARY KEY AUTOINCREMENT,
      certificate_id INTEGER NOT NULL,
      slot_no        INTEGER NOT NULL,
      asset_id       INTEGER NOT NULL,
      manufacturer   TEXT,
      model          TEXT,
      serial_no      TEXT,
      cal_date       TEXT,
      UNIQUE(certificate_id, slot_no)
    )
  ''');

  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_tce_cert ON test_cert_equipment(certificate_id)',
  );

  try {
    await db.execute(
      'ALTER TABLE test_template_names ADD COLUMN test_template_edit_date INTEGER',
    );
  } catch (_) {}

  try {
    await db.execute(
      'ALTER TABLE test_template_names ADD COLUMN test_template_next_service INTEGER',
    );
  } catch (_) {}

  try {
    await db.execute(
      'ALTER TABLE test_template_names ADD COLUMN test_template_test_equip_qty INTEGER',
    );
  } catch (_) {}
}
