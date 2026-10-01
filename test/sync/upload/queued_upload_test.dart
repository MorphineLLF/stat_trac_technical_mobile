import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/sync/upload/certificate_upload.dart';
import 'package:stat_trac_technical/sync/upload/queued_upload.dart';

void main() {
  CertificateUpload cert() => CertificateUpload(
    mobileId: 'cert-1',
    certificate: const {'TestAssetID': 9304},
    lines: const [CertificateLineUpload(mobileId: 'l', data: {'TestPass': true})],
  );

  test('a certificate is stored with its kind', () {
    expect(cert().toJson()['kind'], 'certificate');
  });

  // Rows queued by builds before this one carry no kind. They are
  // certificates, and they must still go.
  test('a payload with no kind restores as a certificate', () {
    final json = cert().toJson()..remove('kind');
    final restored = fromQueuedJson(json);
    expect(restored, isA<CertificateUpload>());
    expect(restored.mobileId, 'cert-1');
  });

  test('an unknown kind is refused loudly', () {
    expect(
      () => fromQueuedJson({'kind': 'mystery', 'mobile_id': 'x'}),
      throwsFormatException,
    );
  });
}
