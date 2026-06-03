import '../../domain/entities/test_equipment_asset.dart';

class TestEquipmentAssetModel extends TestEquipmentAsset {
  const TestEquipmentAssetModel({
    required super.id,
    required super.assetId,
    super.manufacturer,
    super.model,
    super.serialNo,
    super.calDate,
    required super.syncedAt,
  });

  factory TestEquipmentAssetModel.fromJson(Map<String, dynamic> j) =>
      TestEquipmentAssetModel(
        id: 0,
        assetId: j['asset_id'] as int,
        manufacturer: j['manufacturer'] as String?,
        model: j['model'] as String?,
        serialNo: j['serial_no'] as String?,
        calDate: j['cal_date'] as String?,
        syncedAt: DateTime.now(),
      );

  factory TestEquipmentAssetModel.fromMap(Map<String, dynamic> m) =>
      TestEquipmentAssetModel(
        id: m['id'] as int,
        assetId: m['asset_id'] as int,
        manufacturer: m['manufacturer'] as String?,
        model: m['model'] as String?,
        serialNo: m['serial_no'] as String?,
        calDate: m['cal_date'] as String?,
        syncedAt: DateTime.parse(m['synced_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        if (id != 0) 'id': id,
        'asset_id': assetId,
        'manufacturer': manufacturer,
        'model': model,
        'serial_no': serialNo,
        'cal_date': calDate,
        'synced_at': syncedAt.toIso8601String(),
      };
}
