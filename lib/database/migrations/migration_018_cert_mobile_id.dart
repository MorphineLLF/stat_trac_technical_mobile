import 'package:sqflite/sqflite.dart';

/// The client-generated identity a certificate keeps for its whole life.
///
/// Without it the device cannot recognise its own work coming back. The
/// upload generates a UUID, the server returns the real key against that UUID
/// in `assigned`, and there was nowhere to put either — so a finished
/// certificate could never be told apart from the server's copy of itself,
/// and the row could never record that it had landed.
Future<void> migration018CertMobileId(Database db) async {
  await db.execute('ALTER TABLE test_certificates ADD COLUMN mobile_id TEXT');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_test_certificates_mobile_id '
    'ON test_certificates(mobile_id)',
  );
}
