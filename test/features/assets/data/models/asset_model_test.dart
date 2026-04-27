import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/features/assets/data/models/asset_model.dart';

void main() {
  group('AssetModel.fromMap', () {
    test('maps all SQLite columns', () {
      final m = {
        'id': 1,
        'asset_id': 42,
        'equipment_type': 'Defibrillator',
        'model': 'AED Plus',
        'manufacturer': 'ZOLL',
        'serial_number': 'SN001',
        'barcode': 'BC001',
        'hospital': 'St. Mary',
        'location': 'ICU',
        'condition': 'Good',
        'is_active': 1,
        'is_condemned': 0,
        'next_service_date': '2026-06-01T00:00:00.000',
        'is_provisional': 0,
        'synced_at': '2026-04-27T10:00:00.000',
        'created_at': '2026-04-27T08:00:00.000',
        'updated_at': '2026-04-27T08:00:00.000',
      };

      final asset = AssetModel.fromMap(m);

      expect(asset.id, 1);
      expect(asset.assetId, 42);
      expect(asset.equipmentType, 'Defibrillator');
      expect(asset.model, 'AED Plus');
      expect(asset.isActive, isTrue);
      expect(asset.isCondemned, isFalse);
      expect(asset.isProvisional, isFalse);
      expect(asset.nextServiceDate, isNotNull);
    });

    test('handles null optionals', () {
      final m = {
        'id': 2,
        'asset_id': null,
        'equipment_type': 'Unknown',
        'model': null,
        'manufacturer': null,
        'serial_number': null,
        'barcode': null,
        'hospital': null,
        'location': null,
        'condition': null,
        'is_active': 1,
        'is_condemned': 0,
        'next_service_date': null,
        'is_provisional': 1,
        'synced_at': null,
        'created_at': '2026-01-01T00:00:00.000',
        'updated_at': '2026-01-01T00:00:00.000',
      };

      final asset = AssetModel.fromMap(m);

      expect(asset.assetId, isNull);
      expect(asset.isProvisional, isTrue);
      expect(asset.syncedAt, isNull);
    });

    test('toMap round-trips through fromMap', () {
      final m = {
        'id': 3,
        'asset_id': 99,
        'equipment_type': 'Ventilator',
        'model': null,
        'manufacturer': 'Philips',
        'serial_number': null,
        'barcode': 'BAR99',
        'hospital': 'Netcare',
        'location': 'ICU',
        'condition': null,
        'is_active': 1,
        'is_condemned': 0,
        'next_service_date': null,
        'is_provisional': 0,
        'synced_at': null,
        'created_at': '2026-01-01T00:00:00.000',
        'updated_at': '2026-01-01T00:00:00.000',
      };

      final asset = AssetModel.fromMap(m);
      final roundTripped = AssetModel.fromMap(asset.toMap()..['id'] = 3);

      expect(roundTripped.assetId, asset.assetId);
      expect(roundTripped.equipmentType, asset.equipmentType);
      expect(roundTripped.hospital, asset.hospital);
    });
  });

  group('AssetModel.fromJson', () {
    test('maps API response fields', () {
      final j = {
        'asset_id': 55,
        'equipment_type': 'Monitor',
        'model': 'X200',
        'manufacturer': 'GE',
        'serial_number': 'SN55',
        'barcode': 'BC55',
        'hospital': 'Mediclinic',
        'location': 'Ward 3',
        'condition': 'Fair',
        'is_active': true,
        'is_condemned': false,
        'next_service_date': '2026-09-01',
      };

      final asset = AssetModel.fromJson(j);

      expect(asset.assetId, 55);
      expect(asset.equipmentType, 'Monitor');
      expect(asset.isActive, isTrue);
      expect(asset.isProvisional, isFalse);
      expect(asset.syncedAt, isNotNull);
    });
  });
}
