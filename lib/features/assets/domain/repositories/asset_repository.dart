import '../entities/asset.dart';
import '../entities/asset_detail.dart';

abstract interface class AssetRepository {
  /// Paginated sync from Horse API → local SQLite.
  Future<void> syncAssets();

  /// All local assets, optionally filtered by hospital.
  Future<List<Asset>> getAssets({String? hospital});

  /// Search local assets by equipment_type, serial_number, or barcode.
  Future<List<Asset>> searchAssets(String query, {String? hospital});

  /// Lookup by local SQLite PK.
  Future<Asset?> getAssetById(int id);

  /// Lookup by barcode value (for scanner).
  Future<Asset?> getAssetByBarcode(String barcode);

  /// Fetch full asset record from Horse API (not stored locally).
  Future<AssetDetail> getAssetDetail(int assetId);

  /// Create a provisional record offline.
  Future<Asset> createProvisional({
    required String equipmentType,
    String? model,
    String? manufacturer,
    String? serialNumber,
    String? hospital,
    String? location,
  });
}
