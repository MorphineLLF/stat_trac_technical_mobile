import '../../domain/entities/test_certificate.dart';
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
    );
    final certId = await local.saveCertificate(certModel);

    final outputModels = outputs.map((o) => TestOutputModel(
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
        )).toList();

    await local.saveOutputs(outputModels);
    return certId;
  }

  @override
  Future<void> updateSignatures(
    int certId,
    List<int> techSignature,
    List<int>? clientSignature,
    String? clientName,
  ) =>
      local.updateSignatures(certId, techSignature, clientSignature, clientName);

  @override
  Future<void> syncTemplatesFromRemote() async {
    for (final typeInt in [1, 2, 3]) {
      final templates = await remote.fetchTemplates(typeInt);
      if (templates.isEmpty) continue;

      await local.upsertTemplates(templates);

      for (final template in templates) {
        final items = await remote.fetchTemplateItems(template.id);
        if (items.isNotEmpty) {
          await local.upsertTemplateItems(items);
        }
      }
    }
  }
}
