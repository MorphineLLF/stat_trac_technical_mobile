import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqlite3/sqlite3.dart';

/// Encryption at rest for both on-device databases.
///
/// The bundled SQLite is SQLite3MultipleCiphers (`hooks:` in pubspec.yaml),
/// so a database is encrypted by giving it a key before anything else is
/// read. One key per phone, made on first use and kept in the Android
/// Keystore through flutter_secure_storage. It never leaves the phone, and
/// Android backup is off so no file is restored somewhere its key is not.

/// The first 16 bytes of every unencrypted SQLite file.
const _plainHeader = 'SQLite format 3\u0000';

/// Whether [path] is an unencrypted SQLite database — every installed phone's
/// files before this change. False for a missing or empty file.
bool isPlaintextSqlite(String path) {
  final file = File(path);
  if (!file.existsSync() || file.lengthSync() < _plainHeader.length) {
    return false;
  }
  final raf = file.openSync();
  try {
    return String.fromCharCodes(raf.readSync(_plainHeader.length)) ==
        _plainHeader;
  } finally {
    raf.closeSync();
  }
}

/// The statement that unlocks a database. It must run before any other on the
/// connection.
String keyPragma(String key) => "PRAGMA key = '${key.replaceAll("'", "''")}'";

/// Encrypts an existing plain database where it lies, keeping every row and
/// the schema version.
///
/// This is how an installed phone's local database moves over: it holds the
/// certificates still waiting to upload, so it is converted, never replaced.
/// Rekey does not work in WAL mode, so the journal is set to DELETE first —
/// what sqflite uses anyway.
void encryptInPlace(String path, String key) {
  final db = sqlite3.open(path);
  try {
    db
      ..execute('PRAGMA journal_mode = DELETE')
      ..execute("PRAGMA rekey = '${key.replaceAll("'", "''")}'");
  } finally {
    db.close();
  }
  if (isPlaintextSqlite(path)) {
    throw StateError('The database at $path is still unencrypted after rekey.');
  }
}

/// Whether [path] opens and reads with [key].
bool opensWithKey(String path, String key) {
  final db = sqlite3.open(path);
  try {
    db
      ..execute(keyPragma(key))
      ..select('SELECT count(*) FROM sqlite_master');
    return true;
  } on SqliteException {
    return false;
  } finally {
    db.close();
  }
}

/// 32 random bytes as 64 hex characters.
String newDatabaseKey() {
  final random = Random.secure();
  return List.generate(
    32,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

/// The phone's database key, made the first time it is asked for.
class DatabaseKeyStore {
  DatabaseKeyStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _storageKey = 'database_encryption_key';

  /// The read-or-make in flight, shared by every caller in the process.
  ///
  /// At start-up the local database and PowerSync ask at the same moment.
  /// Without this each found no key, made its own, and one file was
  /// encrypted under a key the other could not open.
  static Future<String>? _pending;

  Future<String> key() =>
      _pending ??= _readOrMake().whenComplete(() => _pending = null);

  Future<String> _readOrMake() async {
    final existing = await _storage.read(key: _storageKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final made = newDatabaseKey();
    await _storage.write(key: _storageKey, value: made);
    return made;
  }
}
