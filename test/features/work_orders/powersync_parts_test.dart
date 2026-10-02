import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stat_trac_technical/features/work_orders/data/powersync_work_order_data_source.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late PowerSyncWorkOrderDataSource ds;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute(
      'CREATE TABLE "Part" ("PartID" INTEGER, "PartType" INTEGER, '
      '"PartNumber" TEXT, "PartDescription" TEXT)',
    );
    await db.execute(
      'CREATE TABLE "RepairPart" ("RepairPartSerialID" INTEGER, '
      '"RepairPartTrackID" INTEGER, "RepairPartNo" TEXT, '
      '"RepairPartDescription" TEXT, "RepairPartQty" TEXT, '
      '"RepairPartType" INTEGER, "RepairPartID" INTEGER)',
    );
    for (final (id, type, no, desc) in [
      (1, 1, 'FUSE-5A', 'Fuse 5A'),
      (2, 1, 'BATT-12', 'Battery 12V'),
      (3, 2, 'LABOUR', 'Labour'),
      (4, null, 'CABLE', 'Mains cable'),
    ]) {
      await db.insert('Part', {
        'PartID': id,
        'PartType': type,
        'PartNumber': no,
        'PartDescription': desc,
      });
    }
    ds = PowerSyncWorkOrderDataSource((sql, args) => db.rawQuery(sql, args));
  });

  tearDown(() => db.close());

  group('searchParts', () {
    test('parts only, sorted by number', () async {
      final all = await ds.searchParts('');
      expect([for (final p in all) p.number], ['BATT-12', 'CABLE', 'FUSE-5A']);
    });

    test('by number or description, any case', () async {
      expect((await ds.searchParts('fuse')).single.id, 1);
      expect((await ds.searchParts('mains')).single.id, 4);
      expect(await ds.searchParts('labour'), isEmpty);
    });

    // Charged rates are everything that is not a part, as the desktop's
    // Inventory splits the register.
    test('charged rates: everything but parts, with their kind', () async {
      final rates = await ds.searchParts('', charged: true);
      expect([for (final p in rates) p.number], ['LABOUR']);
      expect(rates.single.kind, 2);
    });
  });

  group('partsOn', () {
    test(
      'the lines on one work order, quantity read from numeric text',
      () async {
        await db.insert('RepairPart', {
          'RepairPartSerialID': 10,
          'RepairPartTrackID': 7144,
          'RepairPartNo': 'FUSE-5A',
          'RepairPartDescription': 'Fuse 5A',
          'RepairPartQty': '2.00',
          'RepairPartType': 1,
          'RepairPartID': 1,
        });
        await db.insert('RepairPart', {
          'RepairPartSerialID': 11,
          'RepairPartTrackID': 9999,
          'RepairPartNo': 'X',
          'RepairPartQty': '1',
        });

        final lines = (await ds.partsOn(7144))!;
        expect(lines.single.label, 'FUSE-5A — Fuse 5A');
        expect(lines.single.qty, 2);
        expect(lines.single.isCharged, isFalse);
      },
    );

    test('a charged line on a synced work order keeps its kind', () async {
      await db.insert('RepairPart', {
        'RepairPartSerialID': 12,
        'RepairPartTrackID': 7144,
        'RepairPartNo': 'LABOUR',
        'RepairPartQty': '1.50',
        'RepairPartType': 2,
      });
      expect((await ds.partsOn(7144))!.single.isCharged, isTrue);
    });

    // A slow or missing table: the detail screen says "parts not loaded"
    // rather than losing the whole work order.
    test('unreadable is null, not an exception', () async {
      final broken = PowerSyncWorkOrderDataSource(
        (sql, args) async => throw StateError('no such table'),
      );
      expect(await broken.partsOn(7144), isNull);
    });
  });
}
