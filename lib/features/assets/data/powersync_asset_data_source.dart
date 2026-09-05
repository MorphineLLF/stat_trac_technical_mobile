import 'package:powersync/powersync.dart';

import '../domain/entities/asset.dart';
import 'datasources/asset_local_data_source.dart' show AssetStats;
import 'powersync_asset_mapper.dart';

/// Reads assets from PowerSync's local database.
///
/// This replaces the Horse-era `assets` table, which is now never populated —
/// its sync engine is retired. The rows live in PowerSync's `Asset` table under
/// the generated schema, which is why every identifier here is PascalCase.
///
/// Queries are ordered by hospital then equipment type so the list is stable:
/// PowerSync returns rows in stream order otherwise, which changes between
/// syncs and makes a list appear to shuffle itself.
class PowerSyncAssetDataSource {
  PowerSyncAssetDataSource(this._db);

  final PowerSyncDatabase _db;

  /// Only equipment a technician can work on: active, not condemned.
  static const _liveOnly = '"AssetActive" = 1 AND "AssetCondemned" != 1';

  Future<List<Asset>> getAssets({String? hospital}) async {
    final rows = hospital == null
        ? await _db.getAll(
            'SELECT * FROM "Asset" WHERE $_liveOnly '
            'ORDER BY "AssetHospital", "AssetEquipmentType"',
          )
        : await _db.getAll(
            'SELECT * FROM "Asset" WHERE $_liveOnly AND "AssetHospital" = ? '
            'ORDER BY "AssetEquipmentType"',
            [hospital],
          );
    return rows.map(assetFromPowerSync).toList();
  }

  /// Matches equipment type, manufacturer, model, serial or barcode — the
  /// fields a technician has in front of them when looking at a machine.
  Future<List<Asset>> searchAssets(String query, {String? hospital}) async {
    final term = '%${query.trim()}%';
    // Numbered throughout, deliberately. Mixing an anonymous ? with ?1..?5
    // is a real bug: SQLite gives the anonymous one the next free index, and
    // this clause is emitted BEFORE the numbered ones, so it would collide
    // with ?1 and the parameter count would not match. Hospital-scoped search
    // is the picker's normal path, so it would have failed on first use.
    final scoped = hospital == null ? '' : ' AND "AssetHospital" = ?6';
    final args = <Object?>[term, term, term, term, term];
    if (hospital != null) args.add(hospital);

    final rows = await _db.getAll(
      'SELECT * FROM "Asset" WHERE $_liveOnly$scoped AND ('
      '"AssetEquipmentType" LIKE ?1 OR "AssetManufacturer" LIKE ?2 OR '
      '"AssetModel" LIKE ?3 OR "AssetSerialNo" LIKE ?4 OR '
      '"AssetBarcode" LIKE ?5) '
      'ORDER BY "AssetHospital", "AssetEquipmentType" LIMIT 200',
      args,
    );
    return rows.map(assetFromPowerSync).toList();
  }

  /// The hospitals this technician actually holds equipment for — derived from
  /// the synced rows rather than a separate list, so it can never offer a
  /// hospital whose assets did not reach the device.
  Future<List<String>> getHospitals() async {
    final rows = await _db.getAll(
      'SELECT DISTINCT "AssetHospital" AS h FROM "Asset" '
      'WHERE $_liveOnly AND "AssetHospital" IS NOT NULL '
      'AND "AssetHospital" != \'\' ORDER BY h',
    );
    return rows.map((r) => r['h']! as String).toList();
  }

  Future<Asset?> getAssetById(int assetId) async {
    final rows = await _db.getAll(
      'SELECT * FROM "Asset" WHERE "AssetID" = ? LIMIT 1',
      [assetId],
    );
    return rows.isEmpty ? null : assetFromPowerSync(rows.first);
  }

  Future<Asset?> getAssetByBarcode(String barcode) async {
    final rows = await _db.getAll(
      'SELECT * FROM "Asset" WHERE "AssetBarcode" = ? LIMIT 1',
      [barcode],
    );
    return rows.isEmpty ? null : assetFromPowerSync(rows.first);
  }

  /// Counts for the summary tiles.
  ///
  /// Deliberately one query, not four: these render together, and four round
  /// trips over a table this size is visible as a stutter on a tablet.
  ///
  /// "Service due" is within 30 days, matching what the Horse-era query
  /// counted, so the number a technician sees does not silently change meaning
  /// with the migration. Dates are ISO text here, which compares correctly
  /// lexicographically — date() cannot be used on a text column.
  Future<AssetStats> getStats() async {
    final rows = await _db.getAll('''
      SELECT
        COUNT(*) AS total,
        SUM(CASE WHEN "AssetCondemned" != 1 THEN 1 ELSE 0 END) AS active,
        SUM(CASE WHEN "AssetNextServiceDate" IS NOT NULL
                  AND "AssetNextServiceDate" != ''
                  AND "AssetNextServiceDate" <= date('now', '+30 days')
                  AND "AssetCondemned" != 1 THEN 1 ELSE 0 END) AS service_due,
        SUM(CASE WHEN "AssetCondemned" = 1 THEN 1 ELSE 0 END) AS condemned
      FROM "Asset"
    ''');

    final r = rows.first;
    int n(Object? v) => (v as num?)?.toInt() ?? 0;
    return AssetStats(
      total: n(r['total']),
      active: n(r['active']),
      serviceDue: n(r['service_due']),
      condemned: n(r['condemned']),
    );
  }
}
