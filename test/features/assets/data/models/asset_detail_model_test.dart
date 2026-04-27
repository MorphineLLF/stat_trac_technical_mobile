import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/features/assets/data/models/asset_detail_model.dart';

void main() {
  group('AssetDetailModel.fromJson', () {
    test('maps all fields from full API response', () {
      final j = {
        'asset_id': 42,
        'equipment_type': 'Defibrillator',
        'model': 'AED Plus',
        'manufacturer': 'ZOLL',
        'serial_number': 'SN001',
        'barcode': 'BC001',
        'hospital': 'St. Mary',
        'hospital_group': 'Netcare Group',
        'location': 'ICU',
        'condition': 'Good',
        'notes': 'Annual service done',
        'software_version': '2.1.0',
        'accessories': 'Pads x2',
        'is_active': true,
        'is_condemned': false,
        'is_loan': false,
        'is_demo': false,
        'risk': 1,
        'asset_type': 1,
        'moduletype': 1,
        'hours': 1200,
        'next_service_date': '2026-09-01',
        'last_service_date': '2025-09-01',
        'warranty_date_start': '2023-01-01',
        'warranty_end_date': '2025-01-01',
        'warranty_period': 24,
        'has_service_plan': true,
        'service_plan_start_date': '2025-01-01',
        'service_plan_exp_date': '2027-01-01',
        'service_plan_value': 5000.0,
        'manufacture_date': '2022-06-01',
        'deliver_date': '2022-12-01',
        'commission_date': '2023-01-15',
      };

      final detail = AssetDetailModel.fromJson(j);

      expect(detail.assetId, 42);
      expect(detail.equipmentType, 'Defibrillator');
      expect(detail.risk, 1);
      expect(detail.hasServicePlan, isTrue);
      expect(detail.warrantyPeriod, 24);
      expect(detail.nextServiceDate, isNotNull);
      expect(detail.servicePlanValue, 5000.0);
      expect(detail.riskLabel, 'High');
      expect(detail.isUnderWarranty, isFalse); // warrantyEndDate 2025-01-01 is in the past
    });

    test('handles all-null optionals gracefully', () {
      final j = {
        'asset_id': 1,
        'equipment_type': null,
        'model': null,
        'manufacturer': null,
        'serial_number': null,
        'barcode': null,
        'hospital': null,
        'hospital_group': null,
        'location': null,
        'condition': null,
        'notes': null,
        'software_version': null,
        'accessories': null,
        'is_active': false,
        'is_condemned': false,
        'is_loan': false,
        'is_demo': false,
        'risk': null,
        'asset_type': null,
        'moduletype': null,
        'hours': null,
        'next_service_date': null,
        'last_service_date': null,
        'warranty_date_start': null,
        'warranty_end_date': null,
        'warranty_period': null,
        'has_service_plan': false,
        'service_plan_start_date': null,
        'service_plan_exp_date': null,
        'service_plan_value': null,
        'manufacture_date': null,
        'deliver_date': null,
        'commission_date': null,
      };

      final detail = AssetDetailModel.fromJson(j);

      expect(detail.assetId, 1);
      expect(detail.equipmentType, isNull);
      expect(detail.risk, isNull);
      expect(detail.servicePlanValue, isNull);
      expect(detail.riskLabel, 'Unknown');
      expect(detail.isUnderWarranty, isFalse); // warrantyEndDate: null
    });
  });
}
