import 'dart:convert';
import 'dart:typed_data'; // Uint8List used in fetchCertificatePdf return type

import 'package:dio/dio.dart';

import '../../domain/entities/test_certificate.dart';
import '../../domain/entities/test_equipment_selection.dart';
import '../../domain/entities/test_output.dart';
import '../../domain/entities/test_template_item.dart';
import '../../domain/entities/test_template_name.dart';
import '../../domain/repositories/certificate_repository.dart';
import '../datasources/cert_local_data_source.dart';
import '../datasources/cert_remote_data_source.dart';
import '../models/test_certificate_model.dart';
import '../models/test_output_model.dart';

class CertificateRepositoryImpl implements CertificateRepository {
  CertificateRepositoryImpl({required this.local, required this.remote});
  final CertLocalDataSource local;
  final CertRemoteDataSource remote;

  @override
  Future<List<TestTemplateName>> getTemplatesByType(CertType type) =>
      local.getTemplatesByType(type);

  @override
  Future<List<TestTemplateItem>> getTemplateItems(int templateNameId) =>
      local.getTemplateItems(templateNameId);

  @override
  Future<int> issueCertificate({
    required TestCertificate cert,
    required List<TestOutput> outputs,
    List<TestEquipmentSelection> equipment = const [],
  }) async {
    final certModel = TestCertificateModel(
      id: 0,
      certType: cert.certType,
      syncStatus: 'pending',
      createdAt: cert.createdAt,
      assetId: cert.assetId,
      testDate: cert.testDate,
      templateNameId: cert.templateNameId,
      technician: cert.technician,
      technicianId: cert.technicianId,
      nextService: cert.nextService,
      woNumber: cert.woNumber,
      jobcardNo: cert.jobcardNo,
      docNo: cert.docNo,
      serviceInterval: cert.serviceInterval,
      serviceType: cert.serviceType,
      techSignature: cert.techSignature,
      clientSignature: cert.clientSignature,
      clientName: cert.clientName,
      notes: cert.notes,
      patientSafe: cert.patientSafe,
      certName: cert.certName,
      pmTaskDescription: cert.pmTaskDescription,
    );
    final certId = await local.saveCertificate(certModel);

    final outputModels = outputs
        .map(
          (o) => TestOutputModel(
            id: 0,
            certificateId: certId,
            assetId: o.assetId,
            descriptionId: o.descriptionId,
            description: o.description,
            expectedValue: o.expectedValue,
            actualValue: o.actualValue,
            notes: o.notes,
            pass: o.pass,
            fail: o.fail,
            na: o.na,
          ),
        )
        .toList();

    await local.saveOutputs(outputModels);
    await local.saveEquipmentSelections(certId, equipment);
    return certId;
  }

  @override
  Future<int> pushPendingCertificates() async {
    final pending = await local.getPendingSyncCertificates();
    var pushed = 0;
    for (final cert in pending) {
      await _pushSingleCertificate(cert);
      pushed++;
    }
    return pushed;
  }

  Future<void> _pushSingleCertificate(TestCertificate cert) async {
    final outputs = await local.getOutputsByCertId(cert.id);
    final equipment = await local.getEquipmentForCert(cert.id);
    final payload = {
      'asset_id': cert.assetId,
      'cert_type': cert.certType,
      'template_name_id': cert.templateNameId,
      'technician': cert.technician,
      'technician_id': cert.technicianId,
      'test_date': cert.testDate?.toIso8601String().substring(0, 10),
      'doc_no': cert.docNo,
      'tech_signature': cert.techSignature != null
          ? base64Encode(cert.techSignature!)
          : null,
      'client_signature': cert.clientSignature != null
          ? base64Encode(cert.clientSignature!)
          : null,
      'client_name': cert.clientName,
      'patient_safe': cert.patientSafe,
      'notes': cert.notes,
      'pm_task_description': cert.pmTaskDescription,
      'test_equipment': equipment
          .map(
            (e) => {
              'asset_id': e.assetId,
              'serial_no': e.serialNo,
              'model': e.model,
              'manufacturer': e.manufacturer,
              'cal_date': e.calDate?.toIso8601String().substring(0, 10),
            },
          )
          .toList(),
      'description': cert.certName,
      'outputs': outputs
          .map(
            (o) => {
              'description_id': o.descriptionId,
              'description': o.description,
              'expected_value': o.expectedValue,
              'actual_value': o.actualValue,
              'pass': o.pass,
              'fail': o.fail,
              'na': o.na,
            },
          )
          .toList(),
    };
    try {
      final serverId = await remote.pushCertificate(payload);
      await local.markSynced(cert.id, serverId);
    } on DioException catch (e) {
      final body = e.response?.data?.toString() ?? e.message ?? e.toString();
      throw Exception('cert ${cert.id}: $body');
    }
  }

  @override
  Future<void> updateSignatures(
    int certId,
    List<int> techSignature,
    List<int>? clientSignature,
    String? clientName,
  ) => local.updateSignatures(
    certId,
    techSignature,
    clientSignature,
    clientName,
  );

  @override
  Future<void> syncTemplatesFromRemote() async {
    for (final typeInt in [1, 2, 3]) {
      final templates = await remote.fetchTemplates(typeInt);
      if (templates.isEmpty) continue;

      await local.upsertTemplates(templates);

      for (final template in templates) {
        try {
          final items = await remote.fetchTemplateItems(template.id);
          if (items.isNotEmpty) {
            await local.upsertTemplateItems(items);
          }
        } catch (_) {
          // Skip items for this template and continue with the next.
        }
      }
    }
  }

  @override
  Future<({List<int> deletedIds, int added})> pullCertificatesFromRemote(
    int technicianId,
  ) async {
    // Option B: compare full ID sets to detect server-side deletes.
    final serverIds = (await remote.fetchCertificateIds(technicianId)).toSet();
    final localServerIds = await local.getSyncedServerIds();
    final deletedIds = <int>[];
    for (final id in localServerIds) {
      if (!serverIds.contains(id)) {
        try {
          await local.deleteCertificateByServerId(id);
          deletedIds.add(id);
        } catch (_) {}
      }
    }

    // Use cursor 0 when existing certs are missing cert_name so the full
    // history is re-pulled and insertCertificateFromServer can backfill them.
    final needsBackfill = await local.hasCertsWithNullCertName();
    var cursor = needsBackfill ? 0 : await local.getMaxServerId();
    var added = 0;
    const pageSize = 100;

    while (true) {
      final page = await remote.fetchCertificateHistory(
        technicianId,
        cursor,
        pageSize: pageSize,
      );

      for (final (cert, outputs) in page) {
        try {
          final localId = await local.insertCertificateFromServer(cert);
          if (localId != null) {
            if (outputs.isNotEmpty) {
              await local.insertOutputsForCert(localId, outputs);
            }
            added++;
          }
        } catch (_) {}
        // Advance cursor to the last seen server ID so the next page
        // starts where this one ended.
        if (cert.serverId != null && cert.serverId! > cursor) {
          cursor = cert.serverId!;
        }
      }

      if (page.length < pageSize) break;
    }

    return (deletedIds: deletedIds, added: added);
  }

  @override
  Future<int> syncTestEquipmentAssets() async {
    final assets = await remote.fetchTestEquipmentAssets();
    await local.upsertTestEquipmentAssets(assets);
    return assets.length;
  }

  @override
  Future<int> syncAssetPmTasks() async {
    final tasks = await remote.fetchAssetPmTasks();
    await local.upsertAssetPmTasks(tasks);
    return tasks.length;
  }

  @override
  Future<Uint8List> fetchCertificatePdf(int serverId) =>
      remote.fetchCertificatePdf(serverId);

  @override
  Future<void> emailCertificate(int serverId, String toEmail) =>
      remote.emailCertificate(serverId, toEmail);
}
