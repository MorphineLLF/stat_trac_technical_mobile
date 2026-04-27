import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/asset.dart';
import '../../domain/entities/asset_detail.dart';
import '../../domain/repositories/asset_repository.dart';
import '../datasources/asset_local_data_source.dart';
import '../datasources/asset_remote_data_source.dart';

class AssetRepositoryImpl implements AssetRepository {
  AssetRepositoryImpl({
    required AssetLocalDataSource local,
    required AssetRemoteDataSource remote,
  })  : _local = local,
        _remote = remote;

  final AssetLocalDataSource _local;
  final AssetRemoteDataSource _remote;

  static const _syncKey = 'assets_last_synced';

  // Hard cap prevents an infinite loop if the server never returns < 500 records.
  static const _maxSyncPages = 200;

  @override
  Future<void> syncAssets() async {
    var page = 1;
    while (page <= _maxSyncPages) {
      final batch = await _remote.getAssets(page: page, pageSize: 500);
      await _local.upsertAll(batch);
      if (batch.length < 500) break;
      page++;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_syncKey, DateTime.now().toIso8601String());
  }

  @override
  Future<List<Asset>> getAssets({String? hospital}) =>
      _local.getAssets(hospital: hospital);

  @override
  Future<List<Asset>> searchAssets(String query, {String? hospital}) =>
      _local.searchAssets(query, hospital: hospital);

  @override
  Future<Asset?> getAssetById(int id) => _local.getAssetById(id);

  @override
  Future<Asset?> getAssetByBarcode(String barcode) =>
      _local.getAssetByBarcode(barcode);

  @override
  Future<AssetDetail> getAssetDetail(int assetId) =>
      _remote.getAssetDetail(assetId);

  @override
  Future<Asset> createProvisional({
    required String equipmentType,
    String? model,
    String? manufacturer,
    String? serialNumber,
    String? hospital,
    String? location,
  }) =>
      _local.createProvisional(
        equipmentType: equipmentType,
        model: model,
        manufacturer: manufacturer,
        serialNumber: serialNumber,
        hospital: hospital,
        location: location,
      );
}
