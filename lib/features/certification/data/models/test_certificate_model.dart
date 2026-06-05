import '../../domain/entities/test_certificate.dart';

class TestCertificateModel extends TestCertificate {
  const TestCertificateModel({
    required super.id,
    required super.certType,
    required super.syncStatus,
    required super.createdAt,
    super.serverId,
    super.assetId,
    super.testDate,
    super.templateNameId,
    super.technician,
    super.technicianId,
    super.nextService,
    super.woNumber,
    super.jobcardNo,
    super.docNo,
    super.serviceInterval,
    super.serviceType,
    super.techSignature,
    super.clientSignature,
    super.clientName,
    super.notes,
    super.patientSafe,
    super.certName,
    super.pmTaskDescription,
  });

  factory TestCertificateModel.fromMap(Map<String, dynamic> m) =>
      TestCertificateModel(
        id: m['id'] as int,
        serverId: m['server_id'] as int?,
        assetId: m['asset_id'] as int?,
        testDate: m['test_date'] != null
            ? DateTime.parse(m['test_date'] as String)
            : null,
        certType: m['cert_type'] as int? ?? 1,
        templateNameId: m['template_name_id'] as int?,
        technician: m['technician'] as String?,
        technicianId: m['technician_id'] as int?,
        nextService: m['next_service'] != null
            ? DateTime.parse(m['next_service'] as String)
            : null,
        woNumber: m['wo_number'] as int?,
        jobcardNo: m['jobcard_no'] as String?,
        docNo: m['doc_no'] as String?,
        serviceInterval: m['service_interval'] as String?,
        serviceType: m['service_type'] as String?,
        techSignature: m['tech_signature'] != null
            ? List<int>.from(m['tech_signature'] as List)
            : null,
        clientSignature: m['client_signature'] != null
            ? List<int>.from(m['client_signature'] as List)
            : null,
        clientName: m['client_name'] as String?,
        notes: m['notes'] as String?,
        syncStatus: m['sync_status'] as String? ?? 'pending',
        createdAt: DateTime.parse(m['created_at'] as String),
        patientSafe: m['patient_safe'] as int?,
        certName: m['cert_name'] as String?,
        pmTaskDescription: m['pm_task_description'] as String?,
      );

  factory TestCertificateModel.fromJson(Map<String, dynamic> j) {
    final testDateStr = j['test_date'] as String?;
    final nextServiceStr = j['next_service'] as String?;
    final testDate = testDateStr != null
        ? DateTime.tryParse(testDateStr)
        : null;
    final nextService = nextServiceStr != null
        ? DateTime.tryParse(nextServiceStr)
        : null;
    return TestCertificateModel(
      id: 0,
      serverId: j['id'] as int?,
      assetId: j['asset_id'] as int?,
      testDate: testDate,
      certType: j['cert_type'] as int? ?? 1,
      templateNameId: j['template_name_id'] as int?,
      technician: j['technician'] as String?,
      technicianId: j['technician_id'] as int?,
      nextService: nextService,
      woNumber: j['wo_number'] as int?,
      jobcardNo: j['jobcard_no'] as String?,
      docNo: j['doc_no'] as String?,
      serviceInterval: j['service_interval'] as String?,
      serviceType: j['service_type'] as String?,
      clientName: j['client_name'] as String?,
      syncStatus: 'synced',
      createdAt: testDate ?? DateTime.now(),
      patientSafe: j['patient_safe'] as int?,
      certName: j['cert_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    if (id != 0) 'id': id,
    'server_id': serverId,
    'asset_id': assetId,
    'test_date': testDate?.toIso8601String(),
    'cert_type': certType,
    'template_name_id': templateNameId,
    'technician': technician,
    'technician_id': technicianId,
    'next_service': nextService?.toIso8601String(),
    'wo_number': woNumber,
    'jobcard_no': jobcardNo,
    'doc_no': docNo,
    'service_interval': serviceInterval,
    'service_type': serviceType,
    'tech_signature': techSignature,
    'client_signature': clientSignature,
    'client_name': clientName,
    'notes': notes,
    'sync_status': syncStatus,
    'created_at': createdAt.toIso8601String(),
    'patient_safe': patientSafe,
    'cert_name': certName,
    'pm_task_description': pmTaskDescription,
  };
}
