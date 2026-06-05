import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

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

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'stat_trac_technical.db';
  static const _dbVersion = 14;

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = p.join(await getDatabasesPath(), _dbName);
    return openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
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
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
