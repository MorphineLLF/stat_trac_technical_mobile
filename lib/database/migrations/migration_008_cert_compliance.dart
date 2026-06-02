import 'package:sqflite/sqflite.dart';

Future<void> migration008CertCompliance(Database db) async {
  try {
    await db.execute(
      'ALTER TABLE test_certificates ADD COLUMN patient_safe INTEGER',
    );
  } catch (_) {
    // Column already exists from a previous migration run — safe to ignore.
  }
}
