import 'package:sqflite/sqflite.dart';

import '../../../../database/database_helper.dart';
import '../../domain/entities/test_template_name.dart';
import '../../domain/entities/test_template_item.dart';
import '../../domain/entities/test_certificate.dart';
import '../../domain/entities/test_output.dart';
import '../../domain/entities/test_equipment_asset.dart';
import '../../domain/entities/test_equipment_selection.dart';
import '../models/test_template_name_model.dart';
import '../models/test_template_item_model.dart';
import '../models/test_certificate_model.dart';
import '../models/test_output_model.dart';
import '../models/certificate_summary.dart';
import '../models/test_equipment_asset_model.dart';
import '../../domain/entities/asset_pm_task.dart';
import '../models/asset_pm_task_model.dart';

abstract interface class CertLocalDataSource {
  Future<List<TestTemplateName>> getTemplatesByType(CertType type);
  Future<List<TestTemplateItem>> getTemplateItems(int templateNameId);
  Future<void> upsertTemplates(List<TestTemplateNameModel> templates);
  Future<void> upsertTemplateItems(List<TestTemplateItemModel> items);
  Future<int> saveCertificate(TestCertificateModel cert);
  Future<void> saveOutputs(List<TestOutputModel> outputs);
  Future<List<TestCertificate>> getPendingSyncCertificates();
  Future<List<TestOutput>> getOutputsByCertId(int certId);
  Future<void> markSynced(int certificateId, int serverId);
  Future<void> updateSignatures(
    int certId,
    List<int> techSignature,
    List<int>? clientSignature,
    String? clientName,
  );
  Future<List<CertificateSummary>> getCertificates();
  Future<CertificateSummary?> getCertificateById(int id);

  /// Returns the highest server_id stored locally (0 if none).
  /// Used as the after_id cursor for GET /certificates/history.
  Future<int> getMaxServerId();

  /// Inserts a server-sourced cert if it is not already in local SQLite
  /// (checked by server_id). Returns the new local autoincrement id, or
  /// null if the cert was skipped because it already exists.
  Future<int?> insertCertificateFromServer(TestCertificateModel cert);

  /// Bulk-inserts outputs for a cert that was just inserted by
  /// insertCertificateFromServer. certificateId in each model is ignored —
  /// localCertId is used instead.
  Future<void> insertOutputsForCert(
      int localCertId, List<TestOutputModel> outputs);

  /// Deletes a certificate and its outputs from local SQLite by server_id.
  Future<void> deleteCertificateByServerId(int serverId);

  /// Returns all server_ids stored locally (excludes NULLs / pending certs).
  /// Used by Option B pull to detect certs deleted on the server.
  Future<List<int>> getSyncedServerIds();

  /// True if any synced cert is missing cert_name — triggers full re-pull
  /// to backfill cert_name from the updated Horse API.
  Future<bool> hasCertsWithNullCertName();

  /// Full-replace upsert of test equipment assets from server sync.
  Future<void> upsertTestEquipmentAssets(List<TestEquipmentAssetModel> assets);

  /// Returns all test equipment assets ordered by manufacturer.
  Future<List<TestEquipmentAsset>> getTestEquipmentAssets();

  /// Saves equipment selections to test_cert_equipment for [certId].
  Future<void> saveEquipmentSelections(
      int certId, List<TestEquipmentSelection> equipment);

  /// Returns equipment selections for [certId] ordered by slot_no.
  Future<List<TestEquipmentSelection>> getEquipmentForCert(int certId);

  /// Full-replace upsert of PM tasks for all assets.
  Future<void> upsertAssetPmTasks(List<AssetPmTaskModel> tasks);

  /// Returns active PM tasks for [assetId] ordered by description.
  Future<List<AssetPmTask>> getAssetPmTasks(int assetId);
}

class CertLocalDataSourceImpl implements CertLocalDataSource {
  CertLocalDataSourceImpl(this._db);
  final DatabaseHelper _db;

  @override
  Future<List<TestTemplateName>> getTemplatesByType(CertType type) async {
    final db = await _db.database;
    final typeInt = TestTemplateName.typeToInt(type);
    final rows = await db.query(
      'test_template_names',
      where: 'test_template_type = ?',
      whereArgs: [typeInt],
      orderBy: 'test_template_cert_name ASC',
    );
    return rows.map(TestTemplateNameModel.fromMap).toList();
  }

  @override
  Future<List<TestTemplateItem>> getTemplateItems(int templateNameId) async {
    final db = await _db.database;
    final rows = await db.query(
      'test_template_items',
      where: 'certificate_name_id = ?',
      whereArgs: [templateNameId],
      orderBy: 'description_no ASC, id ASC',
    );
    return rows.map(TestTemplateItemModel.fromMap).toList();
  }

  @override
  Future<void> upsertTemplates(List<TestTemplateNameModel> templates) async {
    final db = await _db.database;
    final batch = db.batch();
    for (final t in templates) {
      batch.insert(
        'test_template_names',
        t.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> upsertTemplateItems(List<TestTemplateItemModel> items) async {
    final db = await _db.database;
    final batch = db.batch();
    for (final item in items) {
      batch.insert(
        'test_template_items',
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<int> saveCertificate(TestCertificateModel cert) async {
    final db = await _db.database;
    return db.insert('test_certificates', cert.toMap());
  }

  @override
  Future<void> saveOutputs(List<TestOutputModel> outputs) async {
    final db = await _db.database;
    final batch = db.batch();
    for (final o in outputs) {
      batch.insert('test_outputs', o.toMap());
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<List<TestOutput>> getOutputsByCertId(int certId) async {
    final db = await _db.database;
    final rows = await db.query(
      'test_outputs',
      where: 'certificate_id = ?',
      whereArgs: [certId],
    );
    return rows.map(TestOutputModel.fromMap).toList();
  }

  @override
  Future<List<TestCertificate>> getPendingSyncCertificates() async {
    final db = await _db.database;
    final rows = await db.query(
      'test_certificates',
      where: 'sync_status = ?',
      whereArgs: ['pending'],
    );
    return rows.map(TestCertificateModel.fromMap).toList();
  }

  @override
  Future<void> markSynced(int certificateId, int serverId) async {
    final db = await _db.database;
    await db.update(
      'test_certificates',
      {'sync_status': 'synced', 'server_id': serverId},
      where: 'id = ?',
      whereArgs: [certificateId],
    );
  }

  @override
  Future<void> updateSignatures(
    int certId,
    List<int> techSignature,
    List<int>? clientSignature,
    String? clientName,
  ) async {
    final db = await _db.database;
    await db.update(
      'test_certificates',
      {
        'tech_signature': techSignature,
        'client_signature': clientSignature,
        'client_name': clientName,
      },
      where: 'id = ?',
      whereArgs: [certId],
    );
  }

  static const _certSummarySelect = '''
    SELECT
      tc.id,
      tc.server_id AS certificate_no,
      tc.cert_type,
      tc.sync_status,
      tc.created_at,
      tc.patient_safe,
      tc.template_name_id,
      tc.pm_task_description,
      COALESCE(
        tn1.test_template_cert_name,
        tn2.test_template_cert_name,
        tc.cert_name
      ) AS cert_name,
      COALESCE(tn1.test_template_name, tn2.test_template_name) AS template_name,
      a.equipment_type
    FROM test_certificates tc
    LEFT JOIN test_template_names tn1 ON tn1.id = tc.template_name_id
    LEFT JOIN test_template_names tn2 ON tn2.id = tc.cert_type
    LEFT JOIN assets a ON a.asset_id = tc.asset_id
  ''';

  @override
  Future<List<CertificateSummary>> getCertificates() async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '$_certSummarySelect ORDER BY certificate_no DESC, tc.created_at DESC',
    );
    return rows.map(CertificateSummary.fromMap).toList();
  }

  @override
  Future<CertificateSummary?> getCertificateById(int id) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '$_certSummarySelect WHERE tc.id = ?',
      [id],
    );
    return rows.isEmpty ? null : CertificateSummary.fromMap(rows.first);
  }

  @override
  Future<int> getMaxServerId() async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT MAX(server_id) AS max_id FROM test_certificates',
    );
    return (result.first['max_id'] as int?) ?? 0;
  }

  @override
  Future<int?> insertCertificateFromServer(TestCertificateModel cert) async {
    if (cert.serverId == null) return null;
    final db = await _db.database;
    final existing = await db.query(
      'test_certificates',
      columns: ['id'],
      where: 'server_id = ?',
      whereArgs: [cert.serverId],
    );
    if (existing.isNotEmpty) {
      // Backfill cert_name if the server now provides it and we didn't have it.
      if (cert.certName != null) {
        await db.update(
          'test_certificates',
          {'cert_name': cert.certName},
          where: 'server_id = ? AND cert_name IS NULL',
          whereArgs: [cert.serverId],
        );
      }
      return null;
    }
    return db.insert('test_certificates', cert.toMap());
  }

  @override
  Future<void> insertOutputsForCert(
      int localCertId, List<TestOutputModel> outputs) async {
    final db = await _db.database;
    final batch = db.batch();
    for (final o in outputs) {
      batch.insert('test_outputs', {...o.toMap(), 'certificate_id': localCertId});
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> deleteCertificateByServerId(int serverId) async {
    final db = await _db.database;
    final rows = await db.query(
      'test_certificates',
      columns: ['id'],
      where: 'server_id = ?',
      whereArgs: [serverId],
    );
    if (rows.isEmpty) return;
    final localId = rows.first['id'] as int;
    await db.delete('test_outputs',
        where: 'certificate_id = ?', whereArgs: [localId]);
    await db.delete('test_certificates',
        where: 'id = ?', whereArgs: [localId]);
  }

  @override
  Future<List<int>> getSyncedServerIds() async {
    final db = await _db.database;
    final rows = await db.query(
      'test_certificates',
      columns: ['server_id'],
      where: 'server_id IS NOT NULL',
    );
    return rows.map((r) => r['server_id'] as int).toList();
  }

  @override
  Future<bool> hasCertsWithNullCertName() async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM test_certificates '
      'WHERE server_id IS NOT NULL AND cert_name IS NULL',
    );
    return ((result.first['c'] as int?) ?? 0) > 0;
  }

  @override
  Future<void> upsertTestEquipmentAssets(
      List<TestEquipmentAssetModel> assets) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.delete('test_equipment_assets');
      if (assets.isEmpty) return;
      final batch = txn.batch();
      for (final a in assets) {
        batch.insert('test_equipment_assets', a.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<List<TestEquipmentAsset>> getTestEquipmentAssets() async {
    final db = await _db.database;
    final rows = await db.query(
      'test_equipment_assets',
      orderBy: 'manufacturer ASC',
    );
    return rows.map(TestEquipmentAssetModel.fromMap).toList();
  }

  @override
  Future<void> saveEquipmentSelections(
      int certId, List<TestEquipmentSelection> equipment) async {
    if (equipment.isEmpty) return;
    final db = await _db.database;
    final batch = db.batch();
    for (var i = 0; i < equipment.length; i++) {
      final e = equipment[i];
      batch.insert(
        'test_cert_equipment',
        {
          'certificate_id': certId,
          'slot_no': i + 1,
          'asset_id': e.assetId,
          'equipment_type': e.equipmentType,
          'manufacturer': e.manufacturer,
          'model': e.model,
          'serial_no': e.serialNo,
          'cal_date': e.calDate?.toIso8601String().substring(0, 10),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<List<TestEquipmentSelection>> getEquipmentForCert(int certId) async {
    final db = await _db.database;
    final rows = await db.query(
      'test_cert_equipment',
      where: 'certificate_id = ?',
      whereArgs: [certId],
      orderBy: 'slot_no ASC',
    );
    return rows
        .map((r) => TestEquipmentSelection(
              assetId: r['asset_id'] as int,
              equipmentType: r['equipment_type'] as String?,
              manufacturer: r['manufacturer'] as String?,
              model: r['model'] as String?,
              serialNo: r['serial_no'] as String?,
              calDate: r['cal_date'] != null
                  ? DateTime.tryParse(r['cal_date'] as String)
                  : null,
            ))
        .toList();
  }

  @override
  Future<void> upsertAssetPmTasks(List<AssetPmTaskModel> tasks) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.delete('asset_pm_tasks');
      if (tasks.isEmpty) return;
      final batch = txn.batch();
      for (final t in tasks) {
        batch.insert('asset_pm_tasks', t.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<List<AssetPmTask>> getAssetPmTasks(int assetId) async {
    final db = await _db.database;
    final rows = await db.query(
      'asset_pm_tasks',
      where: 'asset_id = ? AND active = 1',
      whereArgs: [assetId],
      orderBy: 'description ASC',
    );
    return rows.map(AssetPmTaskModel.fromMap).toList();
  }
}
