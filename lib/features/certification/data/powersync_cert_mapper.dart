import '../../../sync/powersync_types.dart';
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
