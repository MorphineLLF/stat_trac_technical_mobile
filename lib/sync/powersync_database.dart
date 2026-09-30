import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';

import '../database/database_encryption.dart';
import 'powersync_schema.dart';

/// Opens the device's PowerSync database, encrypted.
///
/// This is deliberately thin wiring. It cannot be exercised by a unit test —
/// it needs PowerSync's native libraries and a real filesystem — so the
/// testable behaviour lives next door: the schema's guarantees in
/// `powersync_schema_test.dart`, the credentials logic in
/// `stat_trac_connector_test.dart`, and the encryption helpers in
/// `database_encryption_test.dart`. Keep this file small enough that there is
/// little here to be wrong.
///
/// It lives in the application support directory rather than a cache
/// directory: the system clears caches, and a technician three weeks offline
/// needs the whole register still there.
///
/// **A plain file from before encryption is deleted, not converted.** Every
/// row in it came down from the server and comes down again; nothing the
/// technician does is written here — the synced tables are read-only on the
/// device and field work waits in the local database's outbox, which is
/// converted in place. The same holds for a file this phone can no longer
/// open, because its key is gone.
Future<PowerSyncDatabase> openSyncDatabase() async {
  final dir = await getApplicationSupportDirectory();
  final path = p.join(dir.path, 'stattrac_sync.sqlite');
  final key = await DatabaseKeyStore(const FlutterSecureStorage()).key();

  final file = File(path);
  if (isPlaintextSqlite(path) ||
      (file.existsSync() && !opensWithKey(path, key))) {
    _deleteDatabaseFiles(path);
  }

  final db = PowerSyncDatabase(
    schema: schema,
    path: path,
    // SQLite3MultipleCiphers' own scheme, the same one the local database
    // uses. SQLCipher compatibility is only for files an older SQLCipher
    // build wrote, and this app never had one.
    encryption: EncryptionOptions(key: key, sqlcipherCompatibility: false),
  );
  await db.initialize();
  return db;
}

void _deleteDatabaseFiles(String path) {
  for (final suffix in ['', '-wal', '-shm', '-journal']) {
    final f = File('$path$suffix');
    if (f.existsSync()) f.deleteSync();
  }
}
