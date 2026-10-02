import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/core/documents/document_result.dart';

void main() {
  group('the PDF', () {
    test('a draft is not ready rather than broken', () {
      final r = docPdfResultFromResponse(
        409,
        'A certificate cannot be printed until it has been saved.',
      );

      expect(r, isA<DocPdfNotReady>());
      expect(r.isRetryable, isFalse);
    });

    // Out of the technician's places answers as missing, which is the
    // convention everywhere on that server. Retrying cannot change it.
    test('missing or refused is permanent', () {
      expect(docPdfResultFromResponse(404, 'not found').isRetryable, isFalse);
      expect(docPdfResultFromResponse(403, 'no').isRetryable, isFalse);
    });

    // A dead Chrome on the server relaunches itself with a backoff, so this
    // one really is worth trying again.
    test('a server fault is worth retrying', () {
      final r = docPdfResultFromResponse(500, 'boom');

      expect(r, isA<DocPdfUnavailable>());
      expect(r.isRetryable, isTrue);
    });

    // Errors on that route are text/plain or HTML because it is an office
    // route, EXCEPT a refusal to a Bearer caller, which is JSON. Both must
    // reach the technician as a sentence rather than as markup.
    test('reads a JSON refusal without showing the technician braces', () {
      final r = docPdfResultFromResponse(
        403,
        '{"error":"this application is not available to the mobile app"}',
      );

      expect(
        (r as DocPdfRefused).message,
        'this application is not '
        'available to the mobile app',
      );
      expect(r.message, isNot(contains('{')));
    });

    test('keeps a plain-text error as it stands', () {
      final r = docPdfResultFromResponse(409, 'not saved yet');
      expect((r as DocPdfNotReady).message, 'not saved yet');
    });
  });

  group('the email', () {
    // The work order route names its id `work_order`, the certificate route
    // `certificate`. One result type reads both.
    test('a work order send reads its id', () {
      final r = docEmailResultFromResponse(200, const {
        'sent': true,
        'work_order': 7144,
        'to': ['sister@hospital.example'],
      });

      expect((r as DocEmailSent).id, 7144);
    });

    test('a certificate send reads its id', () {
      final r = docEmailResultFromResponse(200, const {
        'sent': true,
        'certificate': 8475,
        'number': '8475',
        'to': ['a@b.example'],
      });

      expect((r as DocEmailSent).id, 8475);
    });

    test('a send reports what went where', () {
      final r = docEmailResultFromResponse(200, const {
        'sent': true,
        'certificate': 8475,
        'number': '8475',
        'to': ['sister@hospital.example'],
      });

      expect(r, isA<DocEmailSent>());
      expect((r as DocEmailSent).to, ['sister@hospital.example']);
      expect(r.isRetryable, isFalse);
    });

    // Park these: the same request gets the same answer for ever.
    test('a refusal carries its reason and never retries', () {
      final r = docEmailResultFromResponse(422, const {
        'reason': 'no_recipient',
        'field': 'to',
        'error': 'an address is needed — the To box is empty',
      });

      expect(r, isA<DocEmailRefused>());
      final refused = r as DocEmailRefused;
      expect(refused.reason, 'no_recipient');
      expect(refused.field, 'to');
      expect(refused.message, contains('To box is empty'));
      expect(refused.isRetryable, isFalse);
    });

    test('a malformed request is a refusal, not a retry', () {
      final r = docEmailResultFromResponse(400, const {
        'reason': 'bad_request',
        'error': 'the request could not be read',
      });

      expect(r.isRetryable, isFalse);
    });

    test('a 503 is retryable — the renderer or the mail host is down', () {
      final r = docEmailResultFromResponse(503, const {
        'reason': 'send_failed',
        'error': 'could not reach the mail host',
      });

      expect(r, isA<DocEmailUnavailable>());
      expect(r.isRetryable, isTrue);
    });

    // The server answers 200 even when its own audit write fails, because
    // answering "failed" would have the technician send the certificate
    // twice. So a 200 means it left, and nothing more is claimed.
    test('a send with no body is still a send', () {
      expect(docEmailResultFromResponse(200, const {}), isA<DocEmailSent>());
    });
  });

  // Asked for 2026-10-01: the box opens with the technician's own CC and
  // sign-off, the way the office's does. They live on the Admin row, which
  // does not sync, so the server is asked when the box opens.
  group('what the email box opens with', () {
    test("the sender's own CC, reply address and sign-off", () {
      final d = docEmailDefaultsFromResponse(200, const {
        'cc': 'records@example.com',
        'reply_to': 'athi@example.com',
        'signature': 'Regards\r\nAthi',
      });

      expect(d, isNotNull);
      expect(d!.cc, 'records@example.com');
      expect(d.replyTo, 'athi@example.com');
      // Under two blank lines the cursor starts in, as the office's box, and
      // in the line endings a text box on a phone uses.
      expect(d.initialBody, '\n\nRegards\nAthi');
    });

    test('no sign-off set opens an empty box', () {
      expect(docEmailDefaultsFromResponse(200, const {})!.initialBody, '');
    });

    // The box still opens and the send still works — the server fills in
    // what was left out, as it did before the box showed anything.
    test('a refusal or a fault is no defaults, not an error', () {
      expect(docEmailDefaultsFromResponse(503, const {}), isNull);
      expect(docEmailDefaultsFromResponse(404, const {}), isNull);
    });
  });

  // **What is in the boxes when Send is pressed is what goes.** Left out, the
  // server fills a field from the Admin row; sent empty, it stays empty. So
  // once the defaults were shown everything is sent as it stands — a CC the
  // technician cleared must not come back. Not shown, an empty box is left
  // out so the server still signs it.
  group('what the send carries', () {
    test('defaults shown: the boxes as they stand, even empty', () {
      final f = docEmailFields(defaultsShown: true, cc: ' ', body: '');
      expect(f.cc, '');
      expect(f.body, '');
    });

    test('defaults never arrived: empty boxes are left to the server', () {
      final f = docEmailFields(defaultsShown: false, cc: '', body: '  ');
      expect(f.cc, isNull);
      expect(f.body, isNull);
    });

    test('whatever was typed goes either way', () {
      for (final shown in [true, false]) {
        final f = docEmailFields(
          defaultsShown: shown,
          cc: 'boss@example.com',
          body: 'Attached.',
        );
        expect(f.cc, 'boss@example.com');
        expect(f.body, 'Attached.');
      }
    });
  });
}
