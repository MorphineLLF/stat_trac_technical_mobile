import '../../domain/entities/asset.dart';
import '../../domain/entities/asset_detail.dart';
import '../../domain/repositories/asset_repository.dart';
import '../datasources/asset_local_data_source.dart';
import '../datasources/asset_remote_data_source.dart';
import '../models/asset_model.dart';

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
  Future<({
    int rowCount,
    int pageCount,
    List<int> removedIds,
    List<({int assetId, List<String> fields})> changes,
  })> syncAssets() async {
    var page = 1;
    var totalRows = 0;
    final serverIds = <int>{};
    final allChanges = <({int assetId, List<String> fields})>[];

    while (page <= _maxSyncPages) {
      final batch = await _remote.getAssets(page: page, pageSize: 500);

      // Detect field-level changes against current local state.
      final batchIds = batch
          .where((a) => a.assetId != null)
          .map((a) => a.assetId!)
          .toSet();
      if (batchIds.isNotEmpty) {
        final existing = await _local.getByAssetIds(batchIds);
        final existingMap = {for (final e in existing) e.assetId!: e};
        for (final incoming in batch) {
          if (incoming.assetId == null) continue;
          final current = existingMap[incoming.assetId];
          if (current == null) continue; // new record, not a change
          final changed = _diffAsset(current, incoming);
          if (changed.isNotEmpty) {
            allChanges.add((assetId: incoming.assetId!, fields: changed));
          }
        }
      }

      for (final a in batch) {
        if (a.assetId != null) serverIds.add(a.assetId!);
      }
      await _local.upsertAll(batch);
      totalRows += batch.length;
      if (batch.length < 500) break;
      page++;
    }

    final removedIds = await _local.deleteNotIn(serverIds);
    return (
      rowCount: totalRows,
      pageCount: page,
      removedIds: removedIds,
      changes: allChanges,
    );
  }

  static List<String> _diffAsset(AssetModel current, AssetModel incoming) {
    final changed = <String>[];
    if (current.serialNumber != incoming.serialNumber) changed.add('serial_number');
    if (current.hospital != incoming.hospital) changed.add('hospital');
    if (current.manufacturer != incoming.manufacturer) changed.add('manufacturer');
    if (current.model != incoming.model) changed.add('model');
    if (current.equipmentType != incoming.equipmentType) changed.add('equipment_type');
    if (current.barcode != incoming.barcode) changed.add('barcode');
    if (current.location != incoming.location) changed.add('location');
    if (current.condition != incoming.condition) changed.add('condition');
    if (current.isActive != incoming.isActive) changed.add('is_active');
    if (current.isCondemned != incoming.isCondemned) changed.add('is_condemned');
    return changed;
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
