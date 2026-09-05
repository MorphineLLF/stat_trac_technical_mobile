import 'package:powersync/powersync.dart';

import '../domain/entities/asset_pm_task.dart';
import '../domain/entities/test_output.dart';
import 'models/certificate_summary.dart';
import 'powersync_cert_mapper.dart';

/// Reads certificates from PowerSync's local database.
class PowerSyncCertDataSource {
  PowerSyncCertDataSource(this._db);

  final PowerSyncDatabase _db;

  /// Newest first — a technician looking for a certificate wants a recent one.
  /// The id breaks ties so the order is total: two certificates on the same
  /// date must not swap places between reads.
  Future<List<CertificateSummary>> getCertificates({int limit = 500}) async {
    final rows = await _db.getAll(
      'SELECT * FROM "TestCertificate" '
      'ORDER BY "TestDate" DESC, "TestCertificateID" DESC LIMIT ?1',
      [limit],
    );
    return rows.map(certificateSummaryFromPowerSync).toList();
  }

  Future<CertificateSummary?> getCertificateById(int certificateId) async {
    final rows = await _db.getAll(
      'SELECT * FROM "TestCertificate" WHERE "TestCertificateID" = ?1 LIMIT 1',
      [certificateId],
    );
    return rows.isEmpty ? null : certificateSummaryFromPowerSync(rows.first);
  }

  /// A certificate's measurement lines.
  ///
  /// **Ordered by `TestOutPutID` ascending, and that is not a preference.**
  /// It is the server's contract: `certificate.go:593` and
  /// `certificate_chart.go:201` both order by it, the latter commented "The
  /// certificate's own rows, in the order it lists them". The desktop, the PDF
  /// and the printed certificate all render in that order, so this is what
  /// makes the tablet match the office copy.
  ///
  /// Nothing in the schema enforces it — there is no position column — and the
  /// server deletes and re-inserts a certificate's lines when one is edited,
  /// so ids are reallocated. After an edit both sides agree with each other and
  /// both differ from the certificate as it was. That is a schema-level gap,
  /// recorded on both sides, and not fixable in this query.
  ///
  /// The old Horse-era query had **no** ORDER BY at all, which left SQLite free
  /// to return them in any order.
  Future<List<TestOutput>> getOutputsByCertId(int certificateId) async {
    final rows = await _db.getAll(
      'SELECT * FROM "TestOutput" WHERE "TestOutputCertID" = ?1 '
      'ORDER BY "TestOutPutID"',
      [certificateId],
    );
    return rows.map(testOutputFromPowerSync).toList();
  }

  /// How many certificates are on the device — for the dashboard tile.
  Future<int> countCertificates() async {
    final rows = await _db.getAll(
      'SELECT COUNT(*) AS n FROM "TestCertificate"',
    );
    return (rows.first['n'] as num?)?.toInt() ?? 0;
  }

  /// The PM tasks a certificate can be raised against.
  ///
  /// Active only: a deactivated task is off the schedule, and offering one
  /// would let a technician certify against something the office has retired.
  ///
  /// Ordered by schedule date so the most overdue is first — that is the one
  /// the technician is most likely at the machine for — with the description
  /// breaking ties so the order is total.
  Future<List<AssetPmTask>> getAssetPmTasks(int assetId) async {
    final rows = await _db.getAll(
      'SELECT * FROM "AssetPmTask" '
      'WHERE "PmAssetID" = ?1 AND "PmTaskActive" = 1 '
      'ORDER BY "PmTaskScheduleDate", "PmTaskDescription"',
      [assetId],
    );
    return rows.map(assetPmTaskFromPowerSync).toList();
  }
}
