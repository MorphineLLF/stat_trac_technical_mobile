import 'package:sqflite/sqflite.dart';

Future<void> migration010CertName(Database db) async {
  try {
    await db.execute(
      'ALTER TABLE test_certificates ADD COLUMN cert_name TEXT',
    );
  } catch (_) {
    // Column already exists — safe to ignore.
  }
}
