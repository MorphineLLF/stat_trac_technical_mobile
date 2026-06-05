import 'package:sqflite/sqflite.dart';

Future<void> migration014CertServiceId(Database db) async {
  await db.execute(
    'ALTER TABLE test_certificates ADD COLUMN service_id INTEGER',
  );
}
