import 'package:sqflite/sqflite.dart';

/// Creates all tables needed for Phase 1 Work Orders.
/// Schema matches §5.1 of the spec exactly.
/// Uses IF NOT EXISTS so this is safe to call from both onCreate and onUpgrade.
Future<void> migration001WorkOrders(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS work_orders (
      id                    INTEGER PRIMARY KEY AUTOINCREMENT,
      wo_number             TEXT    NOT NULL,
      type                  TEXT    NOT NULL,
      priority              TEXT    NOT NULL,
      sla_due_at            TEXT,
      status                TEXT    NOT NULL,
      origin                TEXT    NOT NULL,
      account_id            INTEGER,
      asset_id              INTEGER,
      reporter_user_id      INTEGER,
      assigned_user_id      INTEGER,
      scheduled_start       TEXT,
      accepted_at           TEXT,
      en_route_at           TEXT,
      on_site_at            TEXT,
      started_at            TEXT,
      completed_at          TEXT,
      reviewed_at           TEXT,
      closed_at             TEXT,
      cancelled_at          TEXT,
      cancel_reason         TEXT,
      symptom_description   TEXT,
      resolution_narrative  TEXT,
      root_cause_code       TEXT,
      failure_mode_code     TEXT,
      outcome               TEXT,
      billing_flag          TEXT,
      travel_km             REAL,
      travel_minutes        INTEGER,
      labour_minutes        INTEGER,
      wait_minutes          INTEGER,
      created_at            TEXT    NOT NULL,
      updated_at            TEXT    NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS work_order_status_history (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      work_order_id   INTEGER NOT NULL REFERENCES work_orders(id),
      old_status      TEXT,
      new_status      TEXT    NOT NULL,
      changed_by      INTEGER NOT NULL,
      notes           TEXT,
      gps_lat         REAL,
      gps_lng         REAL,
      changed_at      TEXT    NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS work_order_photos (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      work_order_id   INTEGER NOT NULL REFERENCES work_orders(id),
      stage           TEXT    NOT NULL,
      caption         TEXT,
      gps_lat         REAL,
      gps_lng         REAL,
      captured_at     TEXT    NOT NULL,
      file_url        TEXT,
      local_path      TEXT,
      sync_status     TEXT    NOT NULL DEFAULT 'pending'
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS work_order_signatures (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      work_order_id   INTEGER NOT NULL REFERENCES work_orders(id),
      signer_role     TEXT    NOT NULL,
      signer_name     TEXT    NOT NULL,
      signer_contact  TEXT,
      signature_png   TEXT,
      signed_at       TEXT    NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS change_log (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      table_name  TEXT    NOT NULL,
      row_id      INTEGER NOT NULL,
      operation   TEXT    NOT NULL,
      payload     TEXT    NOT NULL,
      device_id   TEXT    NOT NULL,
      user_id     INTEGER NOT NULL,
      created_at  TEXT    NOT NULL,
      synced_at   TEXT
    )
  ''');
}
