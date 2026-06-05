import 'package:sqflite/sqflite.dart';

Future<void> migration013PmTaskInterval(Database db) async {
  await db.execute(
    'ALTER TABLE asset_pm_tasks ADD COLUMN interval TEXT',
  );
  await db.execute(
    'ALTER TABLE asset_pm_tasks ADD COLUMN interval_type TEXT',
  );
}
