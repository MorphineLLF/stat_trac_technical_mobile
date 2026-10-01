import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stat_trac_technical/features/dashboard/data/pm_due_data_source.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late PmDueDataSource ds;
  final wednesday = DateTime(2026, 9, 30, 15, 20);

  Future<void> task(int id, String due, {int active = 1, int asset = 100}) =>
      db.insert('AssetPmTask', {
        'PmTaskID': id,
        'PmAssetID': asset,
        'PmTaskDescription': 'Task $id',
        'PmTaskScheduleDate': due,
        'PmTaskActive': active,
      });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute(
      'CREATE TABLE "AssetPmTask" ("PmTaskID" INTEGER, "PmAssetID" INTEGER, '
      '"PmTaskDescription" TEXT, "PmTaskScheduleDate" TEXT, '
      '"PmTaskActive" INTEGER)',
    );
    await db.execute(
      'CREATE TABLE "Asset" ("AssetID" INTEGER, "AssetEquipmentType" TEXT, '
      '"AssetHospital" TEXT)',
    );
    await db.insert('Asset', {
      'AssetID': 100,
      'AssetEquipmentType': 'Infusion pump',
      'AssetHospital': 'Groote Schuur',
    });
    ds = PmDueDataSource((sql, args) => db.rawQuery(sql, args));
  });

  tearDown(() async => db.close());

  test('today to Sunday, earliest first, with the machine attached', () async {
    await task(2, '2026-10-04');
    await task(1, '2026-10-01');

    final due = await ds.dueThisWeek(wednesday);

    expect([for (final t in due) t.description], ['Task 1', 'Task 2']);
    expect(due.first.due, DateTime(2026, 10, 1));
    expect(due.first.equipment, 'Infusion pump');
    expect(due.first.hospital, 'Groote Schuur');
  });

  test('next week, last week and inactive tasks are left out', () async {
    await task(1, '2026-10-05');
    await task(2, '2026-09-29');
    await task(3, '2026-10-02', active: 0);

    expect(await ds.dueThisWeek(wednesday), isEmpty);
  });

  test('on a Sunday the week is just today', () {
    expect(endOfWeek(DateTime(2026, 10, 4, 9)), DateTime(2026, 10, 4));
    expect(endOfWeek(wednesday), DateTime(2026, 10, 4));
  });

  // A slow asset store costs the names, never the list.
  test('machines that cannot be read in time leave the tasks', () async {
    await task(1, '2026-10-01');
    final slow = PmDueDataSource((sql, args) async {
      if (sql.contains('"Asset"')) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      return db.rawQuery(sql, args);
    }, timeout: const Duration(milliseconds: 20));

    final due = await slow.dueThisWeek(wednesday);

    expect(due.single.description, 'Task 1');
    expect(due.single.equipment, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 250));
  });
}
