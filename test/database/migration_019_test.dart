import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stat_trac_technical/database/migrations/migration_001_work_orders.dart';
import 'package:stat_trac_technical/database/migrations/migration_019_drop_work_orders.dart';
import 'package:stat_trac_technical/sync/upload/upload_archive.dart';

Future<Set<String>> tables(Database db) async => {
  for (final r in await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table'",
  ))
    r['name']! as String,
};

Future<Set<String>> columns(Database db, String table) async => {
  for (final r in await db.rawQuery('PRAGMA table_info($table)'))
    r['name']! as String,
};

void main() {
  sqfliteFfiInit();

  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    // A version-18 phone: the Horse-era tables, and the queue as 016 made it.
    await migration001WorkOrders(db);
    await db.execute('''
      CREATE TABLE upload_queue (
        mobile_id TEXT PRIMARY KEY, payload TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        attempts INTEGER NOT NULL DEFAULT 0, last_error TEXT, reason TEXT,
        created_at TEXT NOT NULL, updated_at TEXT NOT NULL)
    ''');
    await db.insert('upload_queue', {
      'mobile_id': 'cert-1',
      'payload': '{}',
      'created_at': 'x',
      'updated_at': 'x',
    });
    await UploadArchive.createTable(db);
  });

  tearDown(() async => db.close());

  test('drops the four Horse-era work-order tables', () async {
    await migration019DropWorkOrders(db);
    final t = await tables(db);
    for (final gone in [
      'work_orders',
      'work_order_status_history',
      'work_order_photos',
      'work_order_signatures',
    ]) {
      expect(t, isNot(contains(gone)));
    }
    expect(t, containsAll(['change_log', 'upload_queue', 'upload_archive']));
  });

  test('adds field to the queue and keeps what is queued', () async {
    await migration019DropWorkOrders(db);
    expect(await columns(db, 'upload_queue'), contains('field'));
    expect((await db.query('upload_queue')).single['mobile_id'], 'cert-1');
  });

  test('running it twice is harmless', () async {
    await migration019DropWorkOrders(db);
    await migration019DropWorkOrders(db);
    expect(await columns(db, 'upload_queue'), contains('field'));
  });
}
