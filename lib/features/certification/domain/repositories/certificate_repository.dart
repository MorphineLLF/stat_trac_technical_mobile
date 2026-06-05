import 'dart:typed_data';

import '../entities/test_template_name.dart';
import '../entities/test_template_item.dart';
import '../entities/test_certificate.dart';
import '../entities/test_output.dart';
import '../entities/test_equipment_selection.dart';

abstract class CertificateRepository {
  Future<List<TestTemplateName>> getTemplatesByType(CertType type);
  Future<List<TestTemplateItem>> getTemplateItems(int templateNameId);
  Future<int> issueCertificate({
    required TestCertificate cert,
    required List<TestOutput> outputs,
    List<TestEquipmentSelection> equipment = const [],
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

  /// Fetches test equipment asset list from the server and upserts locally.
  /// Returns the number of assets synced.
  Future<int> syncTestEquipmentAssets();

  /// Fetches PM task list from the server and upserts locally.
  /// Returns the number of tasks synced.
  Future<int> syncAssetPmTasks();

  /// Downloads the PDF for [serverId] from the server. Returns raw bytes.
  Future<Uint8List> fetchCertificatePdf(int serverId);

  /// Sends the certificate PDF to [toEmail] via server-side SMTP.
  Future<void> emailCertificate(int serverId, String toEmail);
}
