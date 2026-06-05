import 'package:sqflite/sqflite.dart';

Future<void> migration015CertTestType(Database db) async {
  await db.execute(
    'ALTER TABLE test_certificates ADD COLUMN test_type INTEGER',
  );
}
