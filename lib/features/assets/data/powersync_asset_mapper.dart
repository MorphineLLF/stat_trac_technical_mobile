import '../../../sync/powersync_types.dart';
import '../domain/entities/asset.dart';
import '../domain/entities/asset_detail.dart';

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
    equipmentType:
        (row['AssetEquipmentType'] as String?)?.trim().isNotEmpty == true
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

/// Maps a row from PowerSync's `Asset` table onto the full detail view.
///
/// This replaces a call to the Horse REST API, which no longer exists — the
/// detail screen was fetching over the network for data already sitting on the
/// device. Reading it locally is also what the offline-first rule requires: a
/// technician opening an asset in a basement should not need signal.
///
/// `AssetPurchasePrice` and `AssetServicePlanValue` are Postgres numerics and
/// arrive as strings, so they go through [psNum].
AssetDetail assetDetailFromPowerSync(Map<String, Object?> row) {
  return AssetDetail(
    assetId: psInt(row['AssetID']) ?? 0,
    equipmentType: row['AssetEquipmentType'] as String?,
    model: row['AssetModel'] as String?,
    manufacturer: row['AssetManufacturer'] as String?,
    serialNumber: row['AssetSerialNo'] as String?,
    barcode: row['AssetBarcode'] as String?,
    hospital: row['AssetHospital'] as String?,
    hospitalGroup: row['AssetHospitalGroup'] as String?,
    location: row['AssetLocation'] as String?,
    condition: row['AssetCondition'] as String?,
    notes: row['AssetNotes'] as String?,
    softwareVersion: row['AssetSoftwareVer'] as String?,
    accessories: row['AssetAccessories'] as String?,
    isActive: psBool(row['AssetActive']),
    isCondemned: psBool(row['AssetCondemned']),
    isLoan: psBool(row['AssetLoan']),
    isDemo: psBool(row['AssetDemo']),
    risk: psInt(row['AssetRisk']),
    assetType: psInt(row['AssetType']),
    moduletype: psInt(row['AssetModuleType']),
    hours: psInt(row['AssetHours']),
    nextServiceDate: psDate(row['AssetNextServiceDate']),
    lastServiceDate: psDate(row['AssetLastServiceDate']),
    warrantyDateStart: psDate(row['AssetWarrantyDateStart']),
    warrantyEndDate: psDate(row['AssetWarrantyEndDate']),
    warrantyPeriod: psInt(row['AssetWarrantyPeriod']),
    hasServicePlan: psBool(row['AssetServicePlan']),
    servicePlanStartDate: psDate(row['AssetServicePlanStartDate']),
    servicePlanExpDate: psDate(row['AssetServicePlanExpDate']),
    servicePlanValue: psNum(row['AssetServicePlanValue']),
    manufactureDate: psDate(row['AssetManufactureDate']),
    deliverDate: psDate(row['AssetDeliverDate']),
    commissionDate: psDate(row['AssetCommissionDate']),
  );
}
