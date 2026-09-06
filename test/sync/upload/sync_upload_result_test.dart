import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/sync/upload/sync_upload_result.dart';

void main() {
  group('200 — applied', () {
    test('reads the assigned server keys and the issued certificates', () {
      final r = SyncUploadResult.fromResponse(200, const {
        'applied': 2,
        'assigned': {'cert-uuid': 5031, 'line-uuid': 90210},
        'issued': ['cert-uuid'],
      });

      expect(r, isA<UploadApplied>());
      final a = r as UploadApplied;
      expect(a.applied, 2);
      expect(a.assigned['cert-uuid'], 5031);
      expect(a.issued, contains('cert-uuid'));
    });

    test('tolerates a response with no issued list', () {
      final r = SyncUploadResult.fromResponse(200, const {
        'applied': 1,
        'assigned': {'a': 1},
      });
      expect((r as UploadApplied).issued, isEmpty);
    });
  });

  group('409 — conflict', () {
    test('carries both sides of every field, differing or not', () {
      final r = SyncUploadResult.fromResponse(409, const {
        'applied': 0,
        'conflicts': [
          {
            'table': 'TestCertificate',
            'mobile_id': '9ba75859',
            'seen_at': '2020-01-01T00:00:00Z',
            'server_at': '2026-09-05T12:44:27Z',
            'fields': [
              {
                'field': 'TestDate',
                'mine': '2026-09-05',
                'server': '2026-01-31',
                'differs': true,
              },
              {
                'field': 'TestTech',
                'mine': 'A Tech',
                'server': 'A Tech',
                'differs': false,
              },
            ],
          },
        ],
      });

      expect(r, isA<UploadConflict>());
      final c = (r as UploadConflict).conflicts.single;
      expect(c.table, 'TestCertificate');
      expect(c.mobileId, '9ba75859');
      expect(c.fields, hasLength(2));

      // Agreeing fields are kept deliberately: someone choosing between two
      // versions of a certificate needs to see the readings that match as
      // well as the one that does not.
      expect(c.differingFields.single.field, 'TestDate');
      expect(c.fields.last.differs, isFalse);
    });

    // differs is PostgreSQL's `is distinct from` with the device's value bound
    // as a parameter. The app sends JSON, so an int column arrives as a double
    // and a date as a string — re-deriving this client-side would call 9304
    // and 9304.0 different and show a conflict that does not exist.
    test('trusts the differs flag even when the text renderings differ', () {
      final r = SyncUploadResult.fromResponse(409, const {
        'conflicts': [
          {
            'table': 'Repair',
            'mobile_id': 'x',
            'fields': [
              {
                'field': 'RepairAssetID',
                'mine': '9304.0',
                'server': '9304',
                'differs': false,
              },
            ],
          },
        ],
      });

      expect((r as UploadConflict).conflicts.single.differingFields, isEmpty);
    });
  });

  group('422 — rejected', () {
    // Understood perfectly, and the answer is no. Retrying never helps.
    test('carries a reason code and a sentence for the technician', () {
      final r = SyncUploadResult.fromResponse(422, const {
        'applied': 0,
        'rejections': [
          {
            'table': 'TestCertificate',
            'mobile_id': 'cert-uuid',
            'reason': 'incomplete_tests',
            'message': 'not every test has been marked pass, fail or N/A',
          },
        ],
      });

      expect(r, isA<UploadRejected>());
      final j = (r as UploadRejected).rejections.single;
      expect(j.reason, 'incomplete_tests');
      expect(j.message, contains('pass, fail or N/A'));
      expect(r.isRetryable, isFalse);
    });

    test('exposes the offending field when the reason is invalid', () {
      final r = SyncUploadResult.fromResponse(422, const {
        'rejections': [
          {
            'table': 'TestCertificate',
            'mobile_id': 'c',
            'reason': 'invalid',
            'field': 'next_service',
            'message': 'the next service falls before the test date',
          },
        ],
      });
      expect((r as UploadRejected).rejections.single.field, 'next_service');
    });
  });

  group('400 — client bug', () {
    // 400 and 422 need different screens: 400 means the app is broken and
    // no technician can act on it; 422 is an answer they can.
    test('is distinguished from a rejection', () {
      final r = SyncUploadResult.fromResponse(400, const {
        'error': 'op 2: unknown field "complete_pm_workorder"',
      });

      expect(r, isA<UploadClientError>());
      expect((r as UploadClientError).message, contains('unknown field'));
      expect(r.isRetryable, isFalse);
    });
  });

  group('413 — too large', () {
    // The batch exceeded the server's 1 MB body or its 500 op cap. Sending the
    // identical batch again gets the identical answer for ever, so this must
    // not land in the retryable default: that is a device that has silently
    // stopped uploading, reporting itself as out of signal.
    test('is permanent — the batch has to be split, not resent', () {
      final r = SyncUploadResult.fromResponse(413, const {
        'error': 'body exceeds 1048576 bytes',
      });

      expect(r, isA<UploadTooLarge>());
      expect((r as UploadTooLarge).message, contains('1048576'));
      expect(r.isRetryable, isFalse);
    });
  });

  group('401 — the device token is dead', () {
    // This test previously asserted the opposite, on the belief that the token
    // could be refreshed in the background. It cannot: the upload endpoint
    // authenticates with the ninety-day DEVICE token, and the only way to get
    // one is POST /{company}/device/token with a username and password. The
    // hourly background refresh is the PowerSync JWT, which this route does
    // not use. So a 401 here needs a person, not a retry.
    test('is not resent with the same dead token', () {
      final r = SyncUploadResult.fromResponse(401, const {
        'error': 'sign in first',
      });

      expect(r, isA<UploadAuthExpired>());
      expect(r.isRetryable, isFalse);
    });
  });

  group('transport failures', () {
    test('5xx is retryable', () {
      expect(SyncUploadResult.fromResponse(503, const {}).isRetryable, isTrue);
    });
  });
}
