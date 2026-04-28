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

  // Hard cap prevents an infinite loop if the server never returns < 500 records.
  static const _maxSyncPages = 200;

  @override
  Future<({int rowCount, int pageCount, List<int> removedIds})>
      syncAssets() async {
    var page = 1;
    var totalRows = 0;
    final serverIds = <int>{};

    while (page <= _maxSyncPages) {
      final batch = await _remote.getAssets(page: page, pageSize: 500);
      for (final a in batch) {
        if (a.assetId != null) serverIds.add(a.assetId!);
      }
      await _local.upsertAll(batch);
      totalRows += batch.length;
      if (batch.length < 500) break;
      page++;
    }

    final removedIds = await _local.deleteNotIn(serverIds);
    return (rowCount: totalRows, pageCount: page, removedIds: removedIds);
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
