import 'package:sqflite/sqflite.dart';

import '../../../../database/database_helper.dart';
import '../../domain/entities/test_template_name.dart';
import '../../domain/entities/test_template_item.dart';
import '../../domain/entities/test_certificate.dart';
import '../../domain/entities/test_output.dart';
import '../models/test_template_name_model.dart';
import '../models/test_template_item_model.dart';
import '../models/test_certificate_model.dart';
import '../models/test_output_model.dart';
import '../models/certificate_summary.dart';

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
      tc.cert_type,
      tc.sync_status,
      tc.created_at,
      tn.test_template_cert_name AS cert_name,
      a.equipment_type
    FROM test_certificates tc
    LEFT JOIN test_template_names tn ON tn.id = tc.template_name_id
    LEFT JOIN assets a ON a.asset_id = tc.asset_id
  ''';

  @override
  Future<List<CertificateSummary>> getCertificates() async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '$_certSummarySelect ORDER BY tc.created_at DESC',
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
}
