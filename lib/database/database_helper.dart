import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' show databaseFactorySqflitePlugin;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database_encryption.dart';

import 'migrations/migration_001_work_orders.dart';
import 'migrations/migration_003_assets_v2.dart';
import 'migrations/migration_004_sync_error_log.dart';
import 'migrations/migration_005_certificates.dart';
import 'migrations/migration_007_template_items_actual.dart';
import 'migrations/migration_008_cert_compliance.dart';
import 'migrations/migration_009_sync_metadata.dart';
import 'migrations/migration_010_cert_name.dart';
import 'migrations/migration_011_cert_details.dart';
import 'migrations/migration_012_pm_tasks.dart';
import 'migrations/migration_013_pm_task_interval.dart';
import 'migrations/migration_014_cert_service_id.dart';
import 'migrations/migration_015_cert_test_type.dart';
import 'migrations/migration_016_upload_queue.dart';
import 'migrations/migration_017_upload_archive.dart';
import 'migrations/migration_018_cert_mobile_id.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'stat_trac_technical.db';
  static const _dbVersion = 18;

  /// One open, shared by every caller. `_db ??= await _open()` let callers
  /// arriving together each start their own open — harmless on a plain file,
  /// but with encryption the first one converts the file while the next is
  /// already deciding what the file is.
  Future<Database>? _db;

  Future<Database> get database => _db ??= _open();

  /// Opens the local database, encrypted.
  ///
  /// Through sqflite_common_ffi on the bundled SQLite3MultipleCiphers, so the
  /// key pragma is honoured — the platform sqflite plugin uses Android's own
  /// SQLite, which cannot encrypt. Same file, same place, same migrations.
  ///
  /// An installed phone's file is still plain the first time: it holds the
  /// certificates waiting to upload, so it is encrypted where it lies rather
  /// than replaced.
  Future<Database> _open() async {
    // The platform plugin's path — where every installed phone's file
    // already is. The ffi factory's own default path is somewhere else.
    final dbPath = p.join(
      await databaseFactorySqflitePlugin.getDatabasesPath(),
      _dbName,
    );
    final key = await DatabaseKeyStore(const FlutterSecureStorage()).key();

    if (isPlaintextSqlite(dbPath)) {
      encryptInPlace(dbPath, key);
    } else if (File(dbPath).existsSync() && !opensWithKey(dbPath, key)) {
      // Encrypted under a key this phone no longer has — the key store was
      // wiped. The file is unreadable to anyone now; it is set aside, not
      // deleted, and the app starts with a fresh one rather than not at all.
      final aside =
          '$dbPath.unreadable-${DateTime.now().millisecondsSinceEpoch}';
      debugPrint('Local database unreadable with this key; moved to $aside');
      File(dbPath).renameSync(aside);
    }

    return databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: _dbVersion,
        // First, before anything reads the file.
        onConfigure: (db) => db.execute(keyPragma(key)),
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await migration001WorkOrders(db);
    await migration003AssetsV2(db);
    await migration004SyncErrorLog(db);
    await migration005Certificates(db);
    await migration007TemplateItemsActual(db);
    await migration008CertCompliance(db);
    await migration009SyncMetadata(db);
    await migration010CertName(db);
    await migration011CertDetails(db);
    await migration012PmTasks(db);
    await migration013PmTaskInterval(db);
    await migration014CertServiceId(db);
    await migration015CertTestType(db);
    await migration016UploadQueue(db);
    await migration017UploadArchive(db);
    await migration018CertMobileId(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await migration001WorkOrders(db);
    if (oldVersion < 4) await migration003AssetsV2(db);
    if (oldVersion < 5) await migration004SyncErrorLog(db);
    if (oldVersion < 6) await migration005Certificates(db);
    if (oldVersion < 7) await migration007TemplateItemsActual(db);
    if (oldVersion < 8) await migration008CertCompliance(db);
    if (oldVersion < 9) await migration009SyncMetadata(db);
    if (oldVersion < 10) await migration010CertName(db);
    if (oldVersion < 11) await migration011CertDetails(db);
    if (oldVersion < 12) await migration012PmTasks(db);
    if (oldVersion < 13) await migration013PmTaskInterval(db);
    if (oldVersion < 14) await migration014CertServiceId(db);
    if (oldVersion < 15) await migration015CertTestType(db);
    if (oldVersion < 16) await migration016UploadQueue(db);
    if (oldVersion < 17) await migration017UploadArchive(db);
    if (oldVersion < 18) await migration018CertMobileId(db);
  }

  Future<void> close() async {
    final opening = _db;
    _db = null;
    await (await opening)?.close();
  }
}
