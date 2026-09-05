import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/sync/upload/certificate_upload.dart';

CertificateUpload _upload({
  CertificateIssue? issue,
  int lines = 1,
}) => CertificateUpload(
  mobileId: 'cert-uuid',
  certificate: const {'TestAssetID': 9304, 'TestDate': '2026-09-05'},
  lines: [
    for (var i = 0; i < lines; i++)
      CertificateLineUpload(
        mobileId: 'line-$i',
        data: {'TestDescription': 'Reading $i', 'TestPass': true},
      ),
  ],
  issue: issue,
);

void main() {
  group('batch assembly', () {
    test('puts the certificate first, then its lines', () {
      final ops = _upload(lines: 2).toBatch().toJson()['ops']! as List;

      expect(ops, hasLength(3));
      expect((ops[0] as Map)['table'], 'TestCertificate');
      expect((ops[1] as Map)['table'], 'TestOutput');
      expect((ops[2] as Map)['table'], 'TestOutput');
    });

    // The line names the CERTIFICATE's uuid, never its own and never a
    // server key the device cannot know.
    test('links every line to the certificate by mobile id', () {
      final ops = _upload(lines: 2).toBatch().toJson()['ops']! as List;

      for (final op in ops.skip(1)) {
        final data = (op as Map)['data']! as Map;
        expect(data['TestOutputCertMobileID'], 'cert-uuid');
        expect(data.containsKey('TestOutputCertID'), isFalse);
      }
      expect((ops[1] as Map)['mobile_id'], 'line-0');
    });

    test('adds no issue op when the certificate is only being saved', () {
      final ops = _upload().toBatch().toJson()['ops']! as List;
      expect(ops.any((o) => (o as Map).containsKey('action')), isFalse);
    });
  });

  group('issuing', () {
    test('appends the issue op last, after the readings', () {
      final ops = _upload(
        lines: 2,
        issue: const CertificateIssue(verdict: 1),
      ).toBatch().toJson()['ops']! as List;

      expect(ops, hasLength(4));
      final last = ops.last as Map;
      expect(last['action'], 'issue');
      expect(last['table'], 'TestCertificate');
      // Named by the same mobile id as its row op — that is the link.
      expect(last['mobile_id'], 'cert-uuid');
    });

    test('carries the technician decisions', () {
      final ops = _upload(
        issue: const CertificateIssue(
          verdict: 0,
          notes: 'pump failed leakage',
          nextService: '2027-03-01',
          completePmWorkOrder: true,
          completePmJobCard: true,
        ),
      ).toBatch().toJson()['ops']! as List;

      final data = (ops.last as Map)['data']! as Map;
      expect(data['verdict'], 0);
      expect(data['notes'], 'pump failed leakage');
      expect(data['next_service'], '2027-03-01');
      expect(data['complete_pm_work_order'], isTrue);
      expect(data['complete_pm_job_card'], isTrue);
    });
  });

  group('what the queue must refuse to send', () {
    // The server computes TestTotalTest and TestTotalDone from the actual
    // lines. Sending our own would be a second opinion on a fact, and the
    // column is not writable anyway.
    test('rejects totals in the certificate payload', () {
      expect(
        () => CertificateUpload(
          mobileId: 'c',
          certificate: const {'TestTotalTest': 12},
          lines: const [],
        ),
        throwsArgumentError,
      );
    });

    // TestNextService is written by the issue op from next_service. Setting
    // it as a column would bypass the design switch and the PM schedule move.
    test('rejects a next-service column on the certificate row', () {
      expect(
        () => CertificateUpload(
          mobileId: 'c',
          certificate: const {'TestNextService': '2027-01-01'},
          lines: const [],
        ),
        throwsArgumentError,
      );
    });

    // A certificate with no readings cannot be issued — the server refuses it
    // with incomplete_tests — so catching it here saves a round trip and
    // gives the technician the message before they leave the site.
    test('refuses to issue a certificate with no lines', () {
      expect(
        () => CertificateUpload(
          mobileId: 'c',
          certificate: const {},
          lines: const [],
          issue: const CertificateIssue(verdict: 1),
        ),
        throwsArgumentError,
      );
    });
  });
}
