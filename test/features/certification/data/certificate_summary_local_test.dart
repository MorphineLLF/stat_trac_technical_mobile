import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/features/certification/data/models/certificate_summary.dart';

void main() {
  // A signature added later names the certificate by its mobile id. The
  // device's own unconfirmed certificates dropped it on the way to the
  // screen, so the one certificate most likely to need a signature — the one
  // just left unsigned — was the one that could not be signed.
  test('a local certificate keeps its mobile id and TestType', () {
    final summary = CertificateSummary.fromMap({
      'id': 7,
      'cert_type': 1,
      'sync_status': 'draft',
      'created_at': '2026-09-29T10:00:00',
      'mobile_id': 'cert-uuid',
      'test_type': 1,
    }).asLocal();

    expect(summary.isLocal, isTrue);
    expect(summary.mobileId, 'cert-uuid');
    expect(summary.testType, 1);
  });

  // The list's Signed chip. The facility contact's name is the one signature
  // fact that syncs down, so it is the one the chip can be trusted with.
  test('facility signed means a named signer', () {
    CertificateSummary withName(String? name) => CertificateSummary(
      id: 1,
      certType: 1,
      syncStatus: 'synced',
      createdAt: DateTime(2026),
      clientNameSignature: name,
    );

    expect(withName('A Nurse').isFacilitySigned, isTrue);
    expect(withName(null).isFacilitySigned, isFalse);
    expect(withName('   ').isFacilitySigned, isFalse);
  });

  test('a local certificate keeps the facility signer', () {
    final summary = CertificateSummary.fromMap({
      'id': 7,
      'cert_type': 1,
      'sync_status': 'pending',
      'created_at': '2026-09-29T10:00:00',
      'client_name_signature': 'A Nurse',
    }).asLocal();

    expect(summary.isFacilitySigned, isTrue);
  });
}
