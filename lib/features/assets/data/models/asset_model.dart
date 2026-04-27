import '../../domain/entities/asset.dart';

class AssetModel extends Asset {
  const AssetModel({
    required super.id,
    required super.equipmentType,
    required super.isActive,
    required super.isCondemned,
    required super.isProvisional,
    required super.createdAt,
    required super.updatedAt,
    super.assetId,
    super.model,
    super.manufacturer,
    super.serialNumber,
    super.barcode,
    super.hospital,
    super.location,
    super.condition,
    super.nextServiceDate,
    super.syncedAt,
  });

  /// From SQLite row.
  factory AssetModel.fromMap(Map<String, dynamic> m) => AssetModel(
        id: m['id'] as int,
        assetId: m['asset_id'] as int?,
        equipmentType: m['equipment_type'] as String,
        model: m['model'] as String?,
        manufacturer: m['manufacturer'] as String?,
        serialNumber: m['serial_number'] as String?,
        barcode: m['barcode'] as String?,
        hospital: m['hospital'] as String?,
        location: m['location'] as String?,
        condition: m['condition'] as String?,
        isActive: (m['is_active'] as int? ?? 1) == 1,
        isCondemned: (m['is_condemned'] as int? ?? 0) == 1,
        nextServiceDate: m['next_service_date'] != null
            ? DateTime.parse(m['next_service_date'] as String)
            : null,
        isProvisional: (m['is_provisional'] as int? ?? 0) == 1,
        syncedAt: m['synced_at'] != null
            ? DateTime.parse(m['synced_at'] as String)
            : null,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );

  /// From Horse API slim list response (GET /assets?page=N).
  factory AssetModel.fromJson(Map<String, dynamic> j) {
    final now = DateTime.now();
    return AssetModel(
      id: 0,
      assetId: j['asset_id'] as int?,
      equipmentType: j['equipment_type'] as String? ?? '',
      model: j['model'] as String?,
      manufacturer: j['manufacturer'] as String?,
      serialNumber: j['serial_number'] as String?,
      barcode: j['barcode'] as String?,
      hospital: j['hospital'] as String?,
      location: j['location'] as String?,
      condition: j['condition'] as String?,
      isActive: j['is_active'] as bool? ?? true,
      isCondemned: j['is_condemned'] as bool? ?? false,
      nextServiceDate: j['next_service_date'] != null
          ? DateTime.tryParse(j['next_service_date'] as String)
          : null,
      isProvisional: false,
      syncedAt: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != 0) 'id': id,
        'asset_id': assetId,
        'equipment_type': equipmentType,
        'model': model,
        'manufacturer': manufacturer,
        'serial_number': serialNumber,
        'barcode': barcode,
        'hospital': hospital,
        'location': location,
        'condition': condition,
        'is_active': isActive ? 1 : 0,
        'is_condemned': isCondemned ? 1 : 0,
        'next_service_date': nextServiceDate?.toIso8601String(),
        'is_provisional': isProvisional ? 1 : 0,
        'synced_at': syncedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
