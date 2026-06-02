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

  /// Pulls certs from the server for the given technician.
  /// Uses MAX(server_id) as the cursor for new certs, and diffs the full
  /// server ID set against local to detect and delete orphaned certs.
  /// Returns the IDs of deleted records and count of added records.
  Future<({List<int> deletedIds, int added})> pullCertificatesFromRemote(int technicianId);
}
