import 'package:powersync/powersync.dart';

import '../domain/entities/asset_pm_task.dart';
import '../domain/entities/test_equipment_asset.dart';
import '../domain/entities/test_template_item.dart';
import '../domain/entities/test_template_name.dart';
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
    // Joined to the asset for the facility and the equipment. Neither lives
    // on the certificate, and the hospital is the first thing a technician
    // looks for — they remember where they were standing long before they
    // remember what the template was called.
    //
    // LEFT, not INNER: a certificate whose asset has not reached this device
    // must still appear. Dropping it would hide a record rather than show a
    // problem.
    final rows = await _db.getAll(
      'SELECT c.*, '
      'a."AssetHospital" AS joined_hospital, '
      'a."AssetEquipmentType" AS joined_equipment_type '
      'FROM "TestCertificate" c '
      'LEFT JOIN "Asset" a ON a."AssetID" = c."TestAssetID" '
      'ORDER BY c."TestDate" DESC, c."TestCertificateID" DESC LIMIT ?1',
      [limit],
    );
    return rows.map(certificateSummaryFromPowerSync).toList();
  }

  Future<CertificateSummary?> getCertificateById(int certificateId) async {
    final rows = await _db.getAll(
      'SELECT c.*, '
      'a."AssetHospital" AS joined_hospital, '
      'a."AssetEquipmentType" AS joined_equipment_type '
      'FROM "TestCertificate" c '
      'LEFT JOIN "Asset" a ON a."AssetID" = c."TestAssetID" '
      'WHERE c."TestCertificateID" = ?1 LIMIT 1',
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

  /// The calibrated instruments a certificate can name.
  ///
  /// `AssetTestEquipment = 1` on the Asset table — company property, not a
  /// separate register.
  ///
  /// **The calibration due date is the instrument's PM task schedule date,
  /// not `AssetNextServiceDate`.** That column is NULL on all 5,121 assets —
  /// dead register-wide rather than sparsely filled — so a check written
  /// against it fires for nothing while looking like it works. This app had
  /// exactly that bug: every analyser stayed selectable because none was ever
  /// expired.
  ///
  /// Matched by `max(PmTaskScheduleDate)` over ALL of the instrument's tasks,
  /// mirroring the desktop. Deliberately **not** by description: the register
  /// already spells it three ways — "Calibration Check", "Calibration
  /// Verification" and "Calibration check" — and a fourth spelling next year
  /// would fail silently, which is the worst way for a calibration check to
  /// fail.
  ///
  /// Deliberately a scalar subquery and **not a join**: joining Asset to
  /// AssetPmTask without narrowing lists an instrument once per task, so one
  /// carrying two could be ticked twice against a design asking for one.
  ///
  /// Open, and latent on the desktop too: `max()` means a second PM task with
  /// a later date would become the calibration date. Every instrument
  /// carrying a task has exactly one today, so it cannot happen on this data
  /// — **if a second one ever appears, stop and ask rather than guessing.**
  Future<List<TestEquipmentAsset>> getTestEquipmentAssets() async {
    final rows = await _db.getAll('''
      SELECT a.*,
             (SELECT max(p."PmTaskScheduleDate") FROM "AssetPmTask" p
               WHERE p."PmAssetID" = a."AssetID") AS cal_due
        FROM "Asset" a
       WHERE a."AssetTestEquipment" = 1 AND a."AssetCondemned" != 1
       ORDER BY cal_due IS NULL, cal_due DESC, a."AssetEquipmentType"
    ''');
    return rows.map(testEquipmentFromPowerSync).toList();
  }

  /// Certificate templates of one kind, by name.
  Future<List<TestTemplateName>> getTemplatesByType(CertType type) async {
    final rows = await _db.getAll(
      'SELECT * FROM "TestTemplateName" WHERE "TestTemplateType" = ?1 '
      'ORDER BY "TestTemplateName"',
      [TestTemplateName.typeToInt(type)],
    );
    return rows.map(templateNameFromPowerSync).toList();
  }

  /// A template's test lines.
  ///
  /// Ordered by section sequence then id, which is the order the office lists
  /// them in. Without it PowerSync returns stream order, and a test grid whose
  /// sections shuffle between syncs is unusable.
  Future<List<TestTemplateItem>> getTemplateItems(int templateNameId) async {
    final rows = await _db.getAll(
      'SELECT * FROM "TestTemplate" WHERE "TestTempCertificateNameID" = ?1 '
      'ORDER BY "TestTempDescriptionNo", "TestTemplateID"',
      [templateNameId],
    );
    return rows.map(templateItemFromPowerSync).toList();
  }
}
