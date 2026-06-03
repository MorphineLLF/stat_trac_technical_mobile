// lib/database/migrations/migration_011_cert_details.dart
import 'package:sqflite/sqflite.dart';

Future<void> migration011CertDetails(Database db) async {
  await db.execute('''
    CREATE TABLE test_equipment_assets (
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
    CREATE TABLE test_cert_equipment (
      id             INTEGER PRIMARY KEY AUTOINCREMENT,
      certificate_id INTEGER NOT NULL,
      slot_no        INTEGER NOT NULL,
      asset_id       INTEGER NOT NULL,
      manufacturer   TEXT,
      model          TEXT,
      serial_no      TEXT,
      cal_date       TEXT
    )
  ''');

  await db.execute(
    'ALTER TABLE test_template_names ADD COLUMN test_template_edit_date INTEGER',
  );
  await db.execute(
    'ALTER TABLE test_template_names ADD COLUMN test_template_next_service INTEGER',
  );
  await db.execute(
    'ALTER TABLE test_template_names ADD COLUMN test_template_test_equip_qty INTEGER',
  );
}
