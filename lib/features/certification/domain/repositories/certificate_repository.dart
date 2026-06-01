import '../entities/test_template_name.dart';
import '../entities/test_template_item.dart';
import '../entities/test_certificate.dart';
import '../entities/test_output.dart';

abstract class CertificateRepository {
  Future<List<TestTemplateName>> getTemplatesByType(CertType type);
  Future<List<TestTemplateItem>> getTemplateItems(int templateNameId);
  Future<int> issueCertificate({
    required TestCertificate cert,
    required List<TestOutput> outputs,
  });
  Future<int> pushPendingCertificates();
  Future<void> updateSignatures(
    int certId,
    List<int> techSignature,
    List<int>? clientSignature,
    String? clientName,
  );
  Future<void> syncTemplatesFromRemote();
}
