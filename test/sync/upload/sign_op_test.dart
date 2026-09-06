import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/sync/upload/certificate_upload.dart';
import 'package:stat_trac_technical/sync/upload/sync_upload_batch.dart';
import 'package:stat_trac_technical/sync/upload/sync_upload_result.dart';

const _png = 'iVBORw0KGgo=';

void main() {
  group('sign op', () {
    test('names the side and carries standard padded base64', () {
      final op = SyncUploadOp.sign(
        mobileId: 'cert-1',
        which: SignatureSide.tech,
        png: _png,
      );

      final j = op.toJson();
      expect(j['action'], 'sign');
      expect(j['table'], 'TestCertificate');
      expect(j['mobile_id'], 'cert-1');
      final data = j['data']! as Map<String, Object?>;
      expect(data['which'], 'tech');
      expect(data['png'], _png);
      // Refused server-side as an unknown field on a tech signature.
      expect(data.containsKey('client_name'), isFalse);
    });

    test('a client signature carries the name of the person who gave it', () {
      final data =
          SyncUploadOp.sign(
                mobileId: 'cert-1',
                which: SignatureSide.client,
                png: _png,
                clientName: '  A. Sister  ',
              ).toJson()['data']!
              as Map<String, Object?>;

      expect(data['which'], 'client');
      expect(data['client_name'], 'A. Sister');
    });

    test('a client signature with no name is refused here, not at the wire', () {
      expect(
        () => SyncUploadOp.sign(
          mobileId: 'cert-1',
          which: SignatureSide.client,
          png: _png,
        ),
        throwsArgumentError,
      );
    });

    test('a name on a tech signature is refused, unknown fields are kept', () {
      expect(
        () => SyncUploadOp.sign(
          mobileId: 'cert-1',
          which: SignatureSide.tech,
          png: _png,
          clientName: 'A. Sister',
        ),
        throwsArgumentError,
      );
    });

    test('url-safe base64 is refused rather than guessed at', () {
      final urlSafe = base64Url.encode([251, 255, 190]);
      expect(
        () => SyncUploadOp.sign(
          mobileId: 'cert-1',
          which: SignatureSide.tech,
          png: urlSafe,
        ),
        throwsArgumentError,
      );
    });

    test('unpadded base64 is refused', () {
      expect(
        () => SyncUploadOp.sign(
          mobileId: 'cert-1',
          which: SignatureSide.tech,
          png: 'iVBORw0KGgo',
        ),
        throwsArgumentError,
      );
    });

    test('an empty signature is refused', () {
      expect(
        () => SyncUploadOp.sign(
          mobileId: 'cert-1',
          which: SignatureSide.tech,
          png: '',
        ),
        throwsArgumentError,
      );
    });
  });

  group('batch assembly', () {
    test('sign ops run after the issue op', () {
      final batch = CertificateUpload(
        mobileId: 'cert-1',
        certificate: const {'TestAssetID': 9304},
        lines: const [
          CertificateLineUpload(mobileId: 'l1', data: {'TestPass': true}),
        ],
        issue: const CertificateIssue(verdict: 1),
        signatures: const [
          CertificateSignature(which: SignatureSide.tech, png: _png),
        ],
      ).toBatch();

      final actions = [
        for (final op in batch.ops)
          op.toJson()['action'] ?? op.toJson()['table'],
      ];
      // Certificate, reading, issue, then sign: signing is allowed after
      // issue and is the only write that is.
      expect(actions, ['TestCertificate', 'TestOutput', 'issue', 'sign']);
    });

    test('a signature batch keeps its own queue key', () {
      final upload = CertificateUpload(
        mobileId: 'cert-1',
        queueKey: 'cert-1:sign',
        certificate: const {},
        lines: const [],
        signatures: const [
          CertificateSignature(which: SignatureSide.tech, png: _png),
        ],
      );

      expect(upload.queueKey, 'cert-1:sign');
      // The server still matches it to the certificate by mobile id.
      expect(upload.mobileId, 'cert-1');
    });


    test('a signatures-only batch sends no certificate row op', () {
      // An op naming no known column is refused outright, and a batch is all
      // or nothing — so an empty row op took the signatures down with it.
      final batch = CertificateUpload(
        mobileId: 'cert-1',
        queueKey: 'cert-1:sign',
        certificate: const {},
        lines: const [],
        signatures: const [
          CertificateSignature(which: SignatureSide.tech, png: _png),
        ],
      ).toBatch();

      expect(batch.ops, hasLength(1));
      expect(batch.ops.single.toJson()['action'], 'sign');
    });

    test('a signatures-only batch counts no row ops', () {
      final upload = CertificateUpload(
        mobileId: 'cert-1',
        certificate: const {},
        lines: const [],
        signatures: const [
          CertificateSignature(which: SignatureSide.tech, png: _png),
        ],
      );

      expect(upload.isSignaturesOnly, isTrue);
      // Nothing to be short of: the server applies no rows here.
      expect(upload.rowOpCount, 0);
    });
    test('signatures survive the round trip through the outbox', () {
      final restored = CertificateUpload.fromJson(
        CertificateUpload(
          mobileId: 'cert-1',
          queueKey: 'cert-1:sign',
          certificate: const {},
          lines: const [],
          signatures: const [
            CertificateSignature(which: SignatureSide.tech, png: _png),
            CertificateSignature(
              which: SignatureSide.client,
              png: _png,
              clientName: 'A. Sister',
            ),
          ],
        ).toJson(),
      );

      expect(restored.queueKey, 'cert-1:sign');
      expect(restored.signatures, hasLength(2));
      expect(restored.signatures.last.which, SignatureSide.client);
      expect(restored.signatures.last.clientName, 'A. Sister');
    });
  });

  group('enforces', () {
    test('a response naming cert_ref_required guarantees it', () {
      final r = SyncUploadResult.fromResponse(200, const {
        'applied': 2,
        'assigned': {'cert-1': 5031},
        'signed': ['cert-1'],
        'enforces': ['cert_ref_required', 'sign_action'],
      });

      expect(r.guaranteesCertRef, isTrue);
      expect((r as UploadApplied).signed, ['cert-1']);
    });

    test('a missing enforces means no guarantees, not not-yet-deployed', () {
      final r = SyncUploadResult.fromResponse(200, const {
        'applied': 24,
        'assigned': {'cert-1': 5031},
      });

      // This is the shape of the build that orphaned 46 readings while
      // reporting success.
      expect(r.enforces, isEmpty);
      expect(r.guaranteesCertRef, isFalse);
    });

    test('the refusals carry it too', () {
      final r = SyncUploadResult.fromResponse(422, const {
        'rejections': [
          {
            'table': 'TestCertificate',
            'mobile_id': 'cert-1',
            'reason': 'already_signed',
            'message': 'that side has already signed',
          },
        ],
        'enforces': ['cert_ref_required'],
      });

      expect(r.guaranteesCertRef, isTrue);
      expect((r as UploadRejected).rejections.single.reason, 'already_signed');
    });
  });

  group('rejection reasons', () {
    test('already signed and already issued are benign', () {
      expect(UploadRejectionReason.isBenign('already_signed'), isTrue);
      expect(UploadRejectionReason.isBenign('already_issued'), isTrue);
    });

    test('no_client_signature is not benign', () {
      expect(UploadRejectionReason.isBenign('no_client_signature'), isFalse);
      expect(UploadRejectionReason.isBenign('incomplete_values'), isFalse);
    });
  });
}
