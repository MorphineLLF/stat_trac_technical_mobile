import '../../domain/entities/test_template_name.dart';

class TestTemplateNameModel extends TestTemplateName {
  const TestTemplateNameModel({
    required super.id,
    required super.certType,
    super.templateName,
    super.certName,
    super.customerSigRequired,
    super.docNo,
    super.note,
    super.lastSyncedAt,
  });

  factory TestTemplateNameModel.fromMap(Map<String, dynamic> m) =>
      TestTemplateNameModel(
        id: m['id'] as int,
        certType: TestTemplateName.typeFromInt(m['test_template_type'] as int?),
        templateName: m['test_template_name'] as String?,
        certName: m['test_template_cert_name'] as String?,
        customerSigRequired: (m['test_template_customer_sig'] as int? ?? 0) != 0,
        docNo: m['test_template_doc_no'] as String?,
        note: m['test_template_note'] as String?,
        lastSyncedAt: m['last_synced_at'] != null
            ? DateTime.parse(m['last_synced_at'] as String)
            : null,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'test_template_name': templateName,
        'test_template_cert_name': certName,
        'test_template_type': TestTemplateName.typeToInt(certType),
        'test_template_customer_sig': customerSigRequired ? 1 : 0,
        'test_template_doc_no': docNo,
        'test_template_note': note,
        'last_synced_at': lastSyncedAt?.toIso8601String(),
      };
}
