import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/features/certification/presentation/screens/facility_signature_gate.dart';

void main() {
  test('offered when the design asks for one and nobody has signed', () {
    expect(
      facilitySignatureState(
        testType: 1,
        clientNameSignature: null,
        mobileId: 'cert-uuid',
      ),
      FacilitySignatureState.available,
    );
  });

  // The server refuses a client signature on a design that never asked for
  // one — no_client_signature. Offering it would take a real signature from a
  // real person and then throw it away, which is the exact bug the wizard had.
  test('not offered when the design does not ask for a client signature', () {
    expect(
      facilitySignatureState(
        testType: null,
        clientNameSignature: null,
        mobileId: 'cert-uuid',
      ),
      FacilitySignatureState.notRequired,
    );
    expect(
      facilitySignatureState(
        testType: 0,
        clientNameSignature: null,
        mobileId: 'cert-uuid',
      ),
      FacilitySignatureState.notRequired,
    );
  });

  // The first signature stands and is never overwritten — already_signed.
  // Asking somebody to sign a second time produces a signature that cannot
  // land and a technician who believes it did.
  test('not offered when the client has already signed', () {
    expect(
      facilitySignatureState(
        testType: 1,
        clientNameSignature: 'A Nurse',
        mobileId: 'cert-uuid',
      ),
      FacilitySignatureState.alreadySigned,
    );
  });

  test('a blank name is not a signature', () {
    expect(
      facilitySignatureState(
        testType: 1,
        clientNameSignature: '   ',
        mobileId: 'cert-uuid',
      ),
      FacilitySignatureState.available,
    );
  });

  // Without a mobile id there is nothing to name the certificate by — one
  // raised in the office has none, and the server resolves signatures by it.
  test('not offered when the certificate has no mobile id', () {
    expect(
      facilitySignatureState(
        testType: 1,
        clientNameSignature: null,
        mobileId: null,
      ),
      FacilitySignatureState.cannotBeSigned,
    );
  });

  // Already signed outranks the rest: it is the most specific thing true
  // about the certificate and the most useful thing to tell somebody.
  test('already signed is reported even with no mobile id', () {
    expect(
      facilitySignatureState(
        testType: 1,
        clientNameSignature: 'A Nurse',
        mobileId: null,
      ),
      FacilitySignatureState.alreadySigned,
    );
  });
}
