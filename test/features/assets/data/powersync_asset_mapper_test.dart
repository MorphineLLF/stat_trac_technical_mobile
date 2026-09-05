import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/features/assets/data/powersync_asset_mapper.dart';

// A row as PowerSync actually delivers it: every value flattened to text,
// integer or real. Booleans arrive as 0/1 integers and dates as ISO text.
Map<String, Object?> _row({
  Object? active = 1,
  Object? condemned = 0,
  Object? nextService = '2026-12-01',
}) => {
  'id': '4711',
  'AssetID': 4711,
  'AssetEquipmentType': 'Infusion Pump',
  'AssetManufacturer': 'Braun',
  'AssetModel': 'Infusomat',
  'AssetSerialNo': 'SN-001',
  'AssetBarcode': 'BC-001',
  'AssetHospital': 'UNIVERSITAS HOSPITAL',
  'AssetLocation': 'ICU',
  'AssetCondition': 'Good',
  'AssetActive': active,
  'AssetCondemned': condemned,
  'AssetNextServiceDate': nextService,
  'AssetUserDate': '2026-09-01',
};

void main() {
  group('assetFromPowerSync', () {
    test('maps the columns the app displays', () {
      final asset = assetFromPowerSync(_row());

      expect(asset.assetId, 4711);
      expect(asset.equipmentType, 'Infusion Pump');
      expect(asset.manufacturer, 'Braun');
      expect(asset.model, 'Infusomat');
      expect(asset.serialNumber, 'SN-001');
      expect(asset.barcode, 'BC-001');
      expect(asset.hospital, 'UNIVERSITAS HOSPITAL');
      expect(asset.location, 'ICU');
      expect(asset.condition, 'Good');
    });

    // Postgres booleans cross the stream as 0/1 integers, never as bools.
    test('reads active and condemned from 0/1 integers', () {
      expect(assetFromPowerSync(_row(active: 1)).isActive, isTrue);
      expect(assetFromPowerSync(_row(active: 0)).isActive, isFalse);
      expect(assetFromPowerSync(_row(condemned: 1)).isCondemned, isTrue);
      expect(assetFromPowerSync(_row(condemned: 0)).isCondemned, isFalse);
    });

    test('parses dates arriving as ISO text', () {
      final asset = assetFromPowerSync(_row(nextService: '2026-12-01'));
      expect(asset.nextServiceDate, DateTime(2026, 12, 1));
    });

    // A malformed value in one column must not take out the whole list.
    test('survives a null or unparseable date', () {
      expect(assetFromPowerSync(_row(nextService: null)).nextServiceDate,
          isNull);
      expect(assetFromPowerSync(_row(nextService: '')).nextServiceDate, isNull);
      expect(assetFromPowerSync(_row(nextService: 'not a date')).nextServiceDate,
          isNull);
    });

    // Everything from the server is registered; provisional means created on
    // the device and not yet known to the server.
    test('is never provisional, because it came from the server', () {
      expect(assetFromPowerSync(_row()).isProvisional, isFalse);
    });

    test('tolerates a missing optional column rather than throwing', () {
      final sparse = <String, Object?>{
        'AssetID': 99,
        'AssetEquipmentType': 'Defibrillator',
      };
      final asset = assetFromPowerSync(sparse);

      expect(asset.assetId, 99);
      expect(asset.equipmentType, 'Defibrillator');
      expect(asset.manufacturer, isNull);
      expect(asset.isActive, isFalse);
    });

    test('falls back to a readable label when equipment type is absent', () {
      final asset = assetFromPowerSync(<String, Object?>{'AssetID': 7});
      expect(asset.equipmentType, isNotEmpty);
    });
  });
}
