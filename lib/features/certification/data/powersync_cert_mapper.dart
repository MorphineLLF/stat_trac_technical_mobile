import '../../../sync/powersync_types.dart';
import '../domain/entities/asset_pm_task.dart';
import '../domain/entities/test_equipment_asset.dart';
import '../domain/entities/test_output.dart';
import 'models/certificate_summary.dart';

/// Maps a row from PowerSync's `TestCertificate` table onto the list summary.
///
/// Every row here came from the server, so it is synced by definition. The
/// `pending` state belonged to the Horse-era push queue, which is retired.
CertificateSummary certificateSummaryFromPowerSync(Map<String, Object?> row) {
  final serverId = psInt(row['TestCertificateID']);

  return CertificateSummary(
    // The server key is the identity now — there is no separate local id.
    id: serverId ?? 0,
    certificateNo: serverId,
    certType: psInt(row['TestCertType']) ?? 1,
    syncStatus: 'synced',
    // Falls back to the epoch rather than throwing: a certificate with no
    // date is still a certificate, and dropping it from the list would hide
    // a record rather than surface a problem.
    createdAt: psDate(row['TestDate']) ?? DateTime(1970),
    templateName: row['TestCertificateDescription'] as String?,
    certName: row['TestCertificateDescription'] as String?,
    patientSafe: psInt(row['TestCertPatientSafe']),
    pmTaskDescription: row['TestServiceDescription'] as String?,
  );
}

/// Maps a row from PowerSync's `TestOutput` table onto a measurement line.
///
/// `TestPass` / `TestFail` / `TestNA` are Postgres booleans and arrive as 0/1
/// integers, so they go through [psBool].
///
/// `TestDescriptionID` is a **free-text section heading**, not an identifier
/// and not a key — 102 distinct values server-side, none numeric, no lookup
/// table, and not unique within a certificate. Group by it; never key on it.
///
/// `TestActualValue` is passed through verbatim, including the `'-'` sentinel.
/// The dash is the register saying there is nothing to measure on that line,
/// not a missing reading: the server counts a line as valued when the actual
/// value is non-empty, so a dash is a complete line.
TestOutput testOutputFromPowerSync(Map<String, Object?> row) {
  return TestOutput(
    id: psInt(row['TestOutPutID']) ?? 0,
    certificateId: psInt(row['TestOutputCertID']) ?? 0,
    assetId: psInt(row['TestOutputAssetID']),
    descriptionId: row['TestDescriptionID'] as String?,
    description: row['TestDescription'] as String?,
    expectedValue: row['TestValue'] as String?,
    actualValue: row['TestActualValue'] as String?,
    notes: row['TestNote'] as String?,
    pass: psBool(row['TestPass']),
    fail: psBool(row['TestFail']),
    na: psBool(row['TestNA']),
  );
}

/// Maps a row from PowerSync's `AssetPmTask` table.
///
/// `PmTaskInterval` is an integer column while the entity carries interval as
/// text, so it is rendered rather than cast — "6", never "6.0" and never an
/// exception.
AssetPmTask assetPmTaskFromPowerSync(Map<String, Object?> row) {
  final interval = psInt(row['PmTaskInterval']);

  return AssetPmTask(
    pmTaskId: psInt(row['PmTaskID']) ?? 0,
    assetId: psInt(row['PmAssetID']) ?? 0,
    // Never blank: this is the line the technician picks from, and an empty
    // row is indistinguishable from a broken one.
    description:
        (row['PmTaskDescription'] as String?)?.trim().isNotEmpty == true
        ? (row['PmTaskDescription']! as String).trim()
        : 'Unnamed PM task',
    scheduleDate: psDate(row['PmTaskScheduleDate']),
    active: psBool(row['PmTaskActive']),
    interval: interval?.toString(),
    intervalType: row['PmTaskIntervalType'] as String?,
    taskType: psInt(row['PmTaskType']),
  );
}

/// Maps a calibrated test instrument.
///
/// These are `Asset` rows flagged `AssetTestEquipment = 1` — company property
/// rather than a separate register, which is why the columns are Asset's.
///
/// `AssetNextServiceDate` carries the calibration due date for an instrument:
/// what "next service" means for an analyser is when its calibration expires.
TestEquipmentAsset testEquipmentFromPowerSync(Map<String, Object?> row) {
  final assetId = psInt(row['AssetID']) ?? 0;

  return TestEquipmentAsset(
    // The server key is the identity; there is no separate local row now.
    id: assetId,
    assetId: assetId,
    equipmentType: row['AssetEquipmentType'] as String?,
    manufacturer: row['AssetManufacturer'] as String?,
    model: row['AssetModel'] as String?,
    serialNo: row['AssetSerialNo'] as String?,
    calDate: psDate(row['AssetNextServiceDate']),
    // The row is on the device because sync put it there, so "when did this
    // reach us" is now, not a stored column.
    syncedAt: DateTime.now(),
  );
}
