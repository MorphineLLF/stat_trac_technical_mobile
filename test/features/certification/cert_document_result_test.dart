import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/features/certification/data/cert_document_result.dart';

void main() {
  group('the PDF', () {
    test('a draft is not ready rather than broken', () {
      final r = certPdfResultFromResponse(
        409,
        'A certificate cannot be printed until it has been saved.',
      );

      expect(r, isA<CertPdfNotReady>());
      expect(r.isRetryable, isFalse);
    });

    // Out of the technician's places answers as missing, which is the
    // convention everywhere on that server. Retrying cannot change it.
    test('missing or refused is permanent', () {
      expect(certPdfResultFromResponse(404, 'not found').isRetryable, isFalse);
      expect(certPdfResultFromResponse(403, 'no').isRetryable, isFalse);
    });

    // A dead Chrome on the server relaunches itself with a backoff, so this
    // one really is worth trying again.
    test('a server fault is worth retrying', () {
      final r = certPdfResultFromResponse(500, 'boom');

      expect(r, isA<CertPdfUnavailable>());
      expect(r.isRetryable, isTrue);
    });

    // Errors on that route are text/plain or HTML because it is an office
    // route, EXCEPT a refusal to a Bearer caller, which is JSON. Both must
    // reach the technician as a sentence rather than as markup.
    test('reads a JSON refusal without showing the technician braces', () {
      final r = certPdfResultFromResponse(
        403,
        '{"error":"this application is not available to the mobile app"}',
      );

      expect((r as CertPdfRefused).message, 'this application is not '
          'available to the mobile app');
      expect(r.message, isNot(contains('{')));
    });

    test('keeps a plain-text error as it stands', () {
      final r = certPdfResultFromResponse(409, 'not saved yet');
      expect((r as CertPdfNotReady).message, 'not saved yet');
    });
  });

  group('the email', () {
    test('a send reports what went where', () {
      final r = certEmailResultFromResponse(200, const {
        'sent': true,
        'certificate': 8475,
        'number': '8475',
        'to': ['sister@hospital.example'],
      });

      expect(r, isA<CertEmailSent>());
      expect((r as CertEmailSent).to, ['sister@hospital.example']);
      expect(r.isRetryable, isFalse);
    });

    // Park these: the same request gets the same answer for ever.
    test('a refusal carries its reason and never retries', () {
      final r = certEmailResultFromResponse(422, const {
        'reason': 'no_recipient',
        'field': 'to',
        'error': 'an address is needed — the To box is empty',
      });

      expect(r, isA<CertEmailRefused>());
      final refused = r as CertEmailRefused;
      expect(refused.reason, 'no_recipient');
      expect(refused.field, 'to');
      expect(refused.message, contains('To box is empty'));
      expect(refused.isRetryable, isFalse);
    });

    test('a malformed request is a refusal, not a retry', () {
      final r = certEmailResultFromResponse(400, const {
        'reason': 'bad_request',
        'error': 'the request could not be read',
      });

      expect(r.isRetryable, isFalse);
    });

    test('a 503 is retryable — the renderer or the mail host is down', () {
      final r = certEmailResultFromResponse(503, const {
        'reason': 'send_failed',
        'error': 'could not reach the mail host',
      });

      expect(r, isA<CertEmailUnavailable>());
      expect(r.isRetryable, isTrue);
    });

    // The server answers 200 even when its own audit write fails, because
    // answering "failed" would have the technician send the certificate
    // twice. So a 200 means it left, and nothing more is claimed.
    test('a send with no body is still a send', () {
      expect(certEmailResultFromResponse(200, const {}), isA<CertEmailSent>());
    });
  });
}
