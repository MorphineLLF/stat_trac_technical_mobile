// lib/database/migrations/migration_012_pm_tasks.dart
import 'package:sqflite/sqflite.dart';

Future<void> migration012PmTasks(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS asset_pm_tasks (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      pm_task_id   INTEGER NOT NULL UNIQUE,
      asset_id     INTEGER NOT NULL,
      description  TEXT NOT NULL,
      schedule_date TEXT,
      active       INTEGER NOT NULL DEFAULT 1
    )
  ''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_apt_asset ON asset_pm_tasks (asset_id)',
  );

  try {
    await db.execute(
      'ALTER TABLE test_certificates ADD COLUMN pm_task_description TEXT',
    );
  } catch (_) {}

  try {
    await db.execute(
      'ALTER TABLE test_equipment_assets ADD COLUMN equipment_type TEXT',
    );
  } catch (_) {}

  try {
    await db.execute(
      'ALTER TABLE test_cert_equipment ADD COLUMN equipment_type TEXT',
    );
  } catch (_) {}
}
