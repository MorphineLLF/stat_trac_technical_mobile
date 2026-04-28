import '../../../../database/database_helper.dart';
import '../../domain/entities/asset.dart';
import '../models/asset_model.dart';

class AssetStats {
  const AssetStats({
    required this.total,
    required this.active,
    required this.serviceDue,
    required this.condemned,
  });
  final int total;
  final int active;
  final int serviceDue;
  final int condemned;
}

abstract interface class AssetLocalDataSource {
  /// Batch upsert synced records by asset_id (INSERT OR REPLACE).
  Future<void> upsertAll(List<AssetModel> assets);

  /// Browse all assets, optionally filtered by hospital name.
  Future<List<Asset>> getAssets({String? hospital});

  /// Search by equipment_type, serial_number, or barcode.
  Future<List<Asset>> searchAssets(String query, {String? hospital});

  /// Single record by local SQLite PK.
  Future<Asset?> getAssetById(int id);

  /// Single record by production AssetID (for barcode scan lookup).
  Future<Asset?> getAssetByAssetId(int assetId);

  /// Single record by barcode value (for scanner).
  Future<Asset?> getAssetByBarcode(String barcode);

  /// Distinct hospital names from synced records.
  Future<List<String>> getHospitals();

  /// Aggregate counts for the overview stats cards.
  Future<AssetStats> getStats();

  /// Create a provisional (offline) asset record.
  Future<Asset> createProvisional({
    required String equipmentType,
    String? model,
    String? manufacturer,
    String? serialNumber,
    String? hospital,
    String? location,
  });

  /// Delete non-provisional local records whose asset_id is not in [serverIds].
  /// Executes deletes in chunks of 900 to stay under SQLite's 999-variable limit.
  /// Returns the list of asset_id values that were deleted.
  Future<List<int>> deleteNotIn(Set<int> serverIds);
}

class AssetLocalDataSourceImpl implements AssetLocalDataSource {
  AssetLocalDataSourceImpl(this._db);
  final DatabaseHelper _db;

  static const _table = 'assets';

  @override
  Future<void> upsertAll(List<AssetModel> assets) async {
    final db = await _db.database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    for (final a in assets) {
      batch.rawInsert('''
        INSERT OR REPLACE INTO $_table
          (asset_id, equipment_type, model, manufacturer, serial_number,
           barcode, hospital, location, condition, is_active, is_condemned,
           next_service_date, is_provisional, synced_at, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?)
      ''', [
        a.assetId,
        a.equipmentType,
        a.model,
        a.manufacturer,
        a.serialNumber,
        a.barcode,
        a.hospital,
        a.location,
        a.condition,
        a.isActive ? 1 : 0,
        a.isCondemned ? 1 : 0,
        a.nextServiceDate?.toIso8601String(),
        // synced_at, created_at, updated_at — all set to local sync time.
        // AssetModel.fromJson also stamps these as now(), so this is consistent.
        now, now, now,
      ]);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<List<Asset>> getAssets({String? hospital}) async {
    final db = await _db.database;
    final rows = await db.query(
      _table,
      where: hospital != null ? 'hospital = ?' : null,
      whereArgs: hospital != null ? [hospital] : null,
      orderBy: 'is_provisional ASC, equipment_type ASC',
    );
    return rows.map((r) => AssetModel.fromMap(r)).toList();
  }

  @override
  Future<List<Asset>> searchAssets(String query, {String? hospital}) async {
    final db = await _db.database;
    final like = '%${query.toLowerCase()}%';

    final where = StringBuffer(
      '(LOWER(equipment_type) LIKE ? OR LOWER(serial_number) LIKE ? OR LOWER(barcode) LIKE ?)',
    );
    final args = <dynamic>[like, like, like];

    if (hospital != null) {
      where.write(' AND hospital = ?');
      args.add(hospital);
    }

    final rows = await db.query(
      _table,
      where: where.toString(),
      whereArgs: args,
      orderBy: 'is_provisional ASC, equipment_type ASC',
      limit: 50,
    );
    return rows.map((r) => AssetModel.fromMap(r)).toList();
  }

  @override
  Future<Asset?> getAssetById(int id) async {
    final db = await _db.database;
    final rows = await db.query(_table, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return AssetModel.fromMap(rows.first);
  }

  @override
  Future<Asset?> getAssetByAssetId(int assetId) async {
    final db = await _db.database;
    final rows =
        await db.query(_table, where: 'asset_id = ?', whereArgs: [assetId]);
    if (rows.isEmpty) return null;
    return AssetModel.fromMap(rows.first);
  }

  @override
  Future<Asset?> getAssetByBarcode(String barcode) async {
    final db = await _db.database;
    final rows =
        await db.query(_table, where: 'barcode = ?', whereArgs: [barcode]);
    if (rows.isEmpty) return null;
    return AssetModel.fromMap(rows.first);
  }

  @override
  Future<List<String>> getHospitals() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT DISTINCT hospital
      FROM $_table
      WHERE hospital IS NOT NULL AND is_provisional = 0
      ORDER BY hospital ASC
    ''');
    return rows.map((r) => r['hospital'] as String).toList();
  }

  @override
  Future<AssetStats> getStats() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT
        COUNT(*)                                                                   AS total,
        SUM(CASE WHEN is_condemned = 0 AND is_provisional = 0 THEN 1 ELSE 0 END) AS active,
        SUM(CASE WHEN next_service_date IS NOT NULL
                  AND next_service_date <= date('now', '+30 days')
                  AND is_condemned = 0 THEN 1 ELSE 0 END)                         AS service_due,
        SUM(CASE WHEN is_condemned = 1 THEN 1 ELSE 0 END)                         AS condemned
      FROM $_table
      WHERE is_provisional = 0
    ''');
    final r = rows.first;
    return AssetStats(
      total:      (r['total']       as int?) ?? 0,
      active:     (r['active']      as int?) ?? 0,
      serviceDue: (r['service_due'] as int?) ?? 0,
      condemned:  (r['condemned']   as int?) ?? 0,
    );
  }

  @override
  Future<Asset> createProvisional({
    required String equipmentType,
    String? model,
    String? manufacturer,
    String? serialNumber,
    String? hospital,
    String? location,
  }) async {
    final db = await _db.database;
    final now = DateTime.now();
    final draft = AssetModel(
      id: 0,
      equipmentType: equipmentType,
      model: model,
      manufacturer: manufacturer,
      serialNumber: serialNumber,
      hospital: hospital,
      location: location,
      isActive: true,
      isCondemned: false,
      isProvisional: true,
      createdAt: now,
      updatedAt: now,
    );
    final id = await db.insert(_table, draft.toMap());
    return AssetModel.fromMap({...draft.toMap(), 'id': id});
  }

  @override
  Future<List<int>> deleteNotIn(Set<int> serverIds) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT asset_id FROM $_table WHERE is_provisional = 0 AND asset_id IS NOT NULL',
    );
    final localIds = rows.map((r) => r['asset_id'] as int).toSet();
    final orphans = localIds.difference(serverIds).toList();
    if (orphans.isEmpty) return [];

    for (var i = 0; i < orphans.length; i += 900) {
      final chunk = orphans.sublist(i, (i + 900).clamp(0, orphans.length));
      final placeholders = List.filled(chunk.length, '?').join(', ');
      await db.rawDelete(
        'DELETE FROM $_table WHERE asset_id IN ($placeholders) AND is_provisional = 0',
        chunk,
      );
    }
    return orphans;
  }
}
