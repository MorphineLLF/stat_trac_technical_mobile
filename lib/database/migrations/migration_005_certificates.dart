import 'package:sqflite/sqflite.dart';

Future<void> migration005Certificates(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS test_template_names (
      id                        INTEGER PRIMARY KEY,
      test_template_name        TEXT,
      test_template_cert_name   TEXT,
      test_template_type        INTEGER,
      test_template_customer_sig INTEGER DEFAULT 0,
      test_template_doc_no      TEXT,
      test_template_note        TEXT,
      last_synced_at            TEXT
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS test_template_items (
      id                  INTEGER PRIMARY KEY,
      certificate_name_id INTEGER NOT NULL,
      description_id      TEXT,
      description_no      INTEGER,
      description         TEXT,
      notes               TEXT,
      expected_value      TEXT
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS test_certificates (
      id               INTEGER PRIMARY KEY AUTOINCREMENT,
      server_id        INTEGER,
      asset_id         INTEGER,
      test_date        TEXT,
      cert_type        INTEGER,
      template_name_id INTEGER,
      technician       TEXT,
      technician_id    INTEGER,
      next_service     TEXT,
      wo_number        INTEGER,
      jobcard_no       TEXT,
      doc_no           TEXT,
      service_interval TEXT,
      service_type     TEXT,
      tech_signature   BLOB,
      client_signature BLOB,
      client_name      TEXT,
      notes            TEXT,
      sync_status      TEXT NOT NULL DEFAULT 'pending',
      created_at       TEXT NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS test_outputs (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      certificate_id  INTEGER NOT NULL,
      asset_id        INTEGER,
      description_id  TEXT,
      description     TEXT,
      expected_value  TEXT,
      actual_value    TEXT,
      notes           TEXT,
      pass            INTEGER DEFAULT 0,
      fail            INTEGER DEFAULT 0,
      na              INTEGER DEFAULT 0
    )
  ''');
}
