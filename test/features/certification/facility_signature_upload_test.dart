import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/features/certification/presentation/screens/facility_signature_upload.dart';

final _png = Uint8List.fromList(List<int>.filled(9, 7));

void main() {
  test('sends one sign op and nothing else', () {
    final batch = facilitySignatureUpload(
      certificateMobileId: 'cert-uuid',
      png: _png,
      clientName: 'A Nurse',
    ).toBatch();

    expect(batch.ops, hasLength(1));

    final op = batch.ops.single.toJson();
    expect(op['table'], 'TestCertificate');
    expect(op['mobile_id'], 'cert-uuid');
    expect(op['action'], 'sign');
  });

  test('signs the client side and names who signed', () {
    final op = facilitySignatureUpload(
      certificateMobileId: 'cert-uuid',
      png: _png,
      clientName: '  A Nurse  ',
    ).toBatch().ops.single.toJson();

    final data = op['data']! as Map<String, Object?>;
    expect(data['which'], 'client');
    expect(data['client_name'], 'A Nurse');
    expect(data['png'], base64Encode(_png));
  });

  // Standard, padded base64 — the server refuses URL-safe or unpadded rather
  // than guessing at it.
  test('encodes the signature as standard padded base64', () {
    final op = facilitySignatureUpload(
      certificateMobileId: 'cert-uuid',
      png: _png,
      clientName: 'A Nurse',
    ).toBatch().ops.single.toJson();

    final png = (op['data']! as Map<String, Object?>)['png']! as String;
    expect(png, isNot(contains('-')));
    expect(png, isNot(contains('_')));
    expect(png.length % 4, 0);
  });

  // A signature added later must not collide with the batch sent when the
  // certificate was issued — the outbox is keyed, and a repeated key would
  // replace work still waiting to go rather than queue beside it.
  test('queues under its own key, not the one the issue-time batch used', () {
    final later = facilitySignatureUpload(
      certificateMobileId: 'cert-uuid',
      png: _png,
      clientName: 'A Nurse',
    );

    expect(later.queueKey, isNot('cert-uuid'));
    expect(later.queueKey, isNot('cert-uuid:sign'));
    expect(later.mobileId, 'cert-uuid');
  });

  test('carries no certificate fields and no readings', () {
    final upload = facilitySignatureUpload(
      certificateMobileId: 'cert-uuid',
      png: _png,
      clientName: 'A Nurse',
    );

    expect(upload.certificate, isEmpty);
    expect(upload.lines, isEmpty);
  });
}
