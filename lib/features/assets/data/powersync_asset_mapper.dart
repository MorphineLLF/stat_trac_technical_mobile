import '../../../sync/powersync_types.dart';
import '../domain/entities/asset.dart';

/// Maps a row from PowerSync's `Asset` table onto the app's [Asset].
///
/// Everything arrives flattened: booleans as 0/1 integers, dates as ISO text.
/// Reading those with direct casts throws, so every field goes through the
/// coercions in `powersync_types.dart`.
///
/// Missing columns yield nulls rather than exceptions. One malformed value in
/// one row should not empty a technician's whole asset list.
Asset assetFromPowerSync(Map<String, Object?> row) {
  final assetId = psInt(row['AssetID']);

  return Asset(
    // The app's local `id` was a device autoincrement under the old engine.
    // PowerSync rows carry the server key, so it is used for both — there is
    // no separate local identity to reconcile any more.
    id: assetId ?? 0,
    assetId: assetId,
    equipmentType: (row['AssetEquipmentType'] as String?)?.trim().isNotEmpty ==
            true
        ? (row['AssetEquipmentType']! as String).trim()
        // Never blank: the picker renders this as the primary line, and an
        // empty row is indistinguishable from a broken one.
        : 'Unspecified equipment',
    manufacturer: row['AssetManufacturer'] as String?,
    model: row['AssetModel'] as String?,
    serialNumber: row['AssetSerialNo'] as String?,
    barcode: row['AssetBarcode'] as String?,
    hospital: row['AssetHospital'] as String?,
    location: row['AssetLocation'] as String?,
    condition: row['AssetCondition'] as String?,
    isActive: psBool(row['AssetActive']),
    isCondemned: psBool(row['AssetCondemned']),
    nextServiceDate: psDate(row['AssetNextServiceDate']),
    // A row that arrived over sync is registered by definition. Provisional
    // means created on this device and not yet known to the server.
    isProvisional: false,
    syncedAt: psDate(row['AssetUserDate']),
    createdAt: psDate(row['AssetUserDate']) ?? DateTime(1970),
    updatedAt: psDate(row['AssetUserDate']) ?? DateTime(1970),
  );
}
