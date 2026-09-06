import 'package:powersync/powersync.dart';

import '../domain/entities/asset_pm_task.dart';
import '../domain/entities/test_equipment_asset.dart';
import '../domain/entities/test_template_item.dart';
import '../domain/entities/test_template_name.dart';
import '../domain/entities/test_output.dart';
import 'models/certificate_summary.dart';
import '../../../sync/powersync_types.dart';
import 'powersync_cert_mapper.dart';

/// Reads certificates from PowerSync's local database.
class PowerSyncCertDataSource {
  PowerSyncCertDataSource(this._db);

  final PowerSyncDatabase _db;

  /// Newest first — a technician looking for a certificate wants a recent one.
  /// The id breaks ties so the order is total: two certificates on the same
  /// date must not swap places between reads.
  Future<List<CertificateSummary>> getCertificates({int limit = 500}) async {
    // **Not joined to Asset, and that is deliberate.** A PowerSync table is a
    // view over JSON with no index on AssetID, so a join scans the whole
    // asset store for every certificate — the list stopped appearing at all,
    // showing a spinner for ever rather than failing, which is the worst way
    // for something to break.
    //
    // The certificates are fetched on their own and the facility is attached
    // afterwards, in one pass, by a lookup that cannot hold the list up.
    final rows = await _db.getAll(
      'SELECT * FROM "TestCertificate" '
      'ORDER BY "TestDate" DESC, "TestCertificateID" DESC LIMIT ?1',
      [limit],
    );
    final certs = rows.map(certificateSummaryFromPowerSync).toList();
    return _withFacilities(certs, rows);
  }

  /// Attaches each certificate's facility and equipment from its asset.
  ///
  /// One query for the assets actually referenced, not a join and not a scan
  /// per row. **If it is slow or fails, the certificates are returned without
  /// it**: a list missing the hospital is worth far more than a list that
  /// never arrives.
  Future<List<CertificateSummary>> _withFacilities(
    List<CertificateSummary> certs,
    List<Map<String, Object?>> rows,
  ) async {
    final assetIds = <int>{for (final row in rows) ?psInt(row['TestAssetID'])};
    if (assetIds.isEmpty) return certs;

    try {
      final placeholders = List.filled(assetIds.length, '?').join(',');
      final assets = await _db
          .getAll(
            'SELECT "AssetID", "AssetHospital", "AssetEquipmentType" '
            'FROM "Asset" WHERE "AssetID" IN ($placeholders)',
            assetIds.toList(),
          )
          .timeout(const Duration(seconds: 5));

      final byId = {
        for (final a in assets)
          psInt(a['AssetID']): (
            hospital: a['AssetHospital'] as String?,
            equipment: a['AssetEquipmentType'] as String?,
          ),
      };

      return [
        for (var i = 0; i < certs.length; i++)
          if (byId[psInt(rows[i]['TestAssetID'])] case final asset?)
            certs[i].copyWith(
              hospital: asset.hospital,
              equipmentType: asset.equipment,
            )
          else
            certs[i],
      ];
    } on Object {
      // The facility is a nicety; the certificates are the point.
      return certs;
    }
  }

  Future<CertificateSummary?> getCertificateById(int certificateId) async {
    // Unjoined, for the same reason as the list above.
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
