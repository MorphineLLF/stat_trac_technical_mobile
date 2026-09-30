import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:stat_trac_technical/database/database_encryption.dart';

void main() {
  late Directory dir;
  late String path;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('db_encryption_test');
    path = '${dir.path}/local.db';
  });

  tearDown(() => dir.deleteSync(recursive: true));

  /// A plain database like the one every installed phone has today, in the
  /// rollback-journal mode sqflite uses, at the schema version it would be.
  void createPlainDatabase() {
    final db = sqlite3.open(path)
      ..execute('CREATE TABLE upload_queue (id INTEGER PRIMARY KEY, body TEXT)')
      ..execute("INSERT INTO upload_queue (body) VALUES ('certificate 8485')")
      ..execute('PRAGMA user_version = 18');
    db.close();
  }

  // Without this the rest proves nothing: under plain SQLite `PRAGMA key` is
  // silently ignored and every file stays readable.
  test('the bundled SQLite can encrypt', () {
    final db = sqlite3.open(':memory:');
    final cipher = db.select('PRAGMA cipher');
    db.close();
    expect(cipher, isNotEmpty);
  });

  test('a plain database is recognised as plain', () {
    createPlainDatabase();
    expect(isPlaintextSqlite(path), isTrue);
  });

  test('a missing file is not plain', () {
    expect(isPlaintextSqlite(path), isFalse);
  });

  group('encryptInPlace', () {
    const key = 'a-test-key';

    test('leaves no readable SQLite header', () {
      createPlainDatabase();
      encryptInPlace(path, key);
      expect(isPlaintextSqlite(path), isFalse);
    });

    // The whole point for an installed phone: the certificates waiting to
    // upload are still there afterwards.
    test('keeps the rows, readable with the key', () {
      createPlainDatabase();
      encryptInPlace(path, key);

      final db = sqlite3.open(path)..execute(keyPragma(key));
      final rows = db.select('SELECT body FROM upload_queue');
      db.close();
      expect(rows.single['body'], 'certificate 8485');
    });

    // sqflite runs its migrations from user_version; losing it would replay
    // every migration over existing tables.
    test('keeps the schema version', () {
      createPlainDatabase();
      encryptInPlace(path, key);

      final db = sqlite3.open(path)..execute(keyPragma(key));
      final version = db.select('PRAGMA user_version').single.values.first;
      db.close();
      expect(version, 18);
    });

    test('cannot be read without the key', () {
      createPlainDatabase();
      encryptInPlace(path, key);

      final db = sqlite3.open(path);
      expect(
        () => db.select('SELECT * FROM upload_queue'),
        throwsA(isA<SqliteException>()),
      );
      db.close();
    });

    test('cannot be read with another key', () {
      createPlainDatabase();
      encryptInPlace(path, key);
      expect(opensWithKey(path, 'wrong'), isFalse);
      expect(opensWithKey(path, key), isTrue);
    });
  });

  group('DatabaseKeyStore', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    test('makes a key once and returns the same one after', () async {
      final store = DatabaseKeyStore(const FlutterSecureStorage());
      final first = await store.key();
      final second = await DatabaseKeyStore(const FlutterSecureStorage()).key();

      expect(first, second);
      expect(first, matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    // At start-up the local database and PowerSync both ask for the key at
    // once. Each found none and made its own, so one file was encrypted
    // under a key the other could not open — found on the emulator,
    // 2026-09-30.
    test('asked twice at once, gives one key', () async {
      final keys = await Future.wait([
        DatabaseKeyStore(const FlutterSecureStorage()).key(),
        DatabaseKeyStore(const FlutterSecureStorage()).key(),
        DatabaseKeyStore(const FlutterSecureStorage()).key(),
      ]);
      expect(keys.toSet(), hasLength(1));
      expect(
        await const FlutterSecureStorage().read(key: 'database_encryption_key'),
        keys.first,
      );
    });

    test('keys differ between phones', () {
      expect(newDatabaseKey(), isNot(newDatabaseKey()));
    });
  });
}
