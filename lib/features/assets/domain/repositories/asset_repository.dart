import '../entities/asset.dart';
import '../entities/asset_detail.dart';

abstract interface class AssetRepository {
  /// Paginated sync from Horse API → local SQLite.
  /// Returns row count, page count, deleted asset_ids, and any field-level changes.
  Future<
    ({
      int rowCount,
      int pageCount,
      List<int> removedIds,
      List<({int assetId, List<String> fields})> changes,
    })
  >
  syncAssets({void Function(int page)? onPage});

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

  // createProvisional removed 2026-09-05: technicians cannot create assets.
  // Registration is the office's. Assets are read-only from the device.
}
