import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stat_trac_technical/features/work_orders/data/powersync_work_order_data_source.dart';
import 'package:stat_trac_technical/features/work_orders/domain/work_type.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late PowerSyncWorkOrderDataSource ds;

  Future<void> repair(
    int id, {
    int tech = 31,
    int request = 1,
    int? status = 9,
    int asset = 100,
    String date = '2026-10-01',
    String? mobile,
  }) => db.insert('Repair', {
    'RepairTrackID': id,
    'RepairTechID': tech,
    'RepairRequest': request,
    'RepairStatus': status,
    'RepairAssetID': asset,
    'RepairDate': date,
    'RepairType': 1,
    'RepairMobileID': mobile,
  });

  Future<void> card(int trackId, {int type = 3}) => db.insert('RepairDetail', {
    'RepairDetailJobID': trackId * 10,
    'RepairDetailTrackID': trackId,
    'RepairDetailType': type,
    'RepairDetailDateIN': '2026-10-01',
    'RepairDetailTimeIn': '08:15:00',
    'RepairDetailDate': '2026-10-01',
    'RepairDetailTimeOut': '10:40:00',
    'RepairDetailFault': 'Beeps',
    'RepairDetailManualWoType': 1,
    'RepairDetailTech': 'Athi',
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute(
      'CREATE TABLE "Repair" ("RepairTrackID" INTEGER, '
      '"RepairTechID" INTEGER, "RepairRequest" INTEGER, "RepairStatus" '
      'INTEGER, "RepairAssetID" INTEGER, "RepairDate" TEXT, "RepairType" '
      'INTEGER, "RepairMobileID" TEXT)',
    );
    await db.execute(
      'CREATE TABLE "RepairDetail" ("RepairDetailJobID" '
      'INTEGER, "RepairDetailTrackID" INTEGER, "RepairDetailType" INTEGER, '
      '"RepairDetailDateIN" TEXT, "RepairDetailTimeIn" TEXT, '
      '"RepairDetailDate" TEXT, "RepairDetailTimeOut" TEXT, '
      '"RepairDetailFault" TEXT, "RepairDetailWork" TEXT, '
      '"RepairDetailNote" TEXT, "RepairDetailClient" TEXT, '
      '"RepairDetailJobCard" TEXT, "RepairDetailHrs" INTEGER, '
      '"RepairDetailNop" INTEGER, "RepairDetailManualWoType" INTEGER, '
      '"RepairDetailTech" TEXT)',
    );
    await db.execute(
      'CREATE TABLE "Asset" ("AssetID" INTEGER, '
      '"AssetEquipmentType" TEXT, "AssetSerialNo" TEXT, "AssetHospital" '
      'TEXT)',
    );
    await db.execute(
      'CREATE TABLE "ComboStatus" ("StatusID" INTEGER, '
      '"StatusDescription" TEXT)',
    );
    await db.insert('Asset', {
      'AssetID': 100,
      'AssetEquipmentType': 'Pump',
      'AssetSerialNo': 'SN1',
      'AssetHospital': 'Groote Schuur',
    });
    await db.insert('ComboStatus', {
      'StatusID': 9,
      'StatusDescription': 'WO Completed',
    });
    ds = PowerSyncWorkOrderDataSource((sql, args) => db.rawQuery(sql, args));
  });

  tearDown(() async => db.close());

  group('open repair on a machine', () {
    test('status 9 is closed', () async {
      await repair(1, status: 9);
      expect(await ds.openRepairOn(100), isNull);
    });
    test('a blank status is open', () async {
      await repair(1, status: null);
      expect(await ds.openRepairOn(100), 1);
    });
    test('a PM work order does not count', () async {
      await repair(1, status: 2, request: 2);
      expect(await ds.openRepairOn(100), isNull);
    });
    // Any technician's, booked in or captured — the server refuses either.
    test('somebody else\'s counts, lowest number first', () async {
      await repair(7, status: 2, tech: 99);
      await repair(5, status: 1, tech: 98);
      expect(await ds.openRepairOn(100), 5);
    });
  });

  group('captured by the technician', () {
    test('only captures, only theirs', () async {
      await repair(1, mobile: 'wo-1');
      await card(1);
      await repair(2); // booked in
      await card(2, type: 1);
      await repair(3, tech: 99); // someone else's capture
      await card(3);

      final list = await ds.capturedBy(31);

      expect(list.complete, isTrue);
      expect([for (final w in list.items) w.trackId], [1]);
      final w = list.items.single;
      expect(w.mobileId, 'wo-1');
      expect(w.status, 'WO Completed');
      expect(w.workType, WorkType.repair);
      expect(w.asset?.hospital, 'Groote Schuur');
    });

    // If the cards cannot be read, nothing synced can be shown: without them a
    // booked-in work order is indistinguishable from a capture.
    test('cards timing out shows nothing synced and says so', () async {
      await repair(1);
      await card(1);
      final slow = PowerSyncWorkOrderDataSource((sql, args) async {
        if (sql.contains('"RepairDetail"')) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
        return db.rawQuery(sql, args);
      }, timeout: const Duration(milliseconds: 20));

      final list = await slow.capturedBy(31);

      expect(list.complete, isFalse);
      expect(list.items, isEmpty);
      // The slow read is still running; let it finish before tearDown closes
      // the database under it.
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });
  });

  test('record reads the job card', () async {
    await repair(1, mobile: 'wo-1');
    await card(1);

    final r = (await ds.record(1))!;

    expect(r.trackId, 1);
    expect(r.started, DateTime(2026, 10, 1, 8, 15));
    expect(r.finished, DateTime(2026, 10, 1, 10, 40));
    expect(r.fault, 'Beeps');
    expect(r.tech, 'Athi');
    expect(r.workType, WorkType.repair);
  });
}
