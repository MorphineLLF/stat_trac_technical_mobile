import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'migrations/migration_001_work_orders.dart';
import 'migrations/migration_003_assets_v2.dart';
import 'migrations/migration_004_sync_error_log.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'stat_trac_technical.db';
  static const _dbVersion = 5;

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
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await migration001WorkOrders(db);
    if (oldVersion < 4) await migration003AssetsV2(db);
    if (oldVersion < 5) await migration004SyncErrorLog(db);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
