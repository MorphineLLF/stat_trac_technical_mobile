import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/features/certification/presentation/widgets/signature_step_validation.dart';

void main() {
  test('a technician signature is always required', () {
    expect(
      signatureStepError(
        techSigned: false,
        requiresCustomerSig: false,
        clientSigned: false,
        clientName: '',
      ),
      contains('Technician signature'),
    );
  });

  test('a certificate that asks for a facility signature must have one', () {
    expect(
      signatureStepError(
        techSigned: true,
        requiresCustomerSig: true,
        clientSigned: false,
        clientName: '',
      ),
      contains('Facility signature'),
    );
  });

  // Somebody signed, so a name is asked for before saving — that signature
  // cannot be sent without one and used to be discarded on the way to the
  // server, with a debug line as the only trace that a real signature from a
  // real person had been thrown away.
  test('a facility signature with no name asks for one before saving', () {
    final error = signatureStepError(
      techSigned: true,
      requiresCustomerSig: false,
      clientSigned: true,
      clientName: '   ',
    );

    expect(error, isNotNull);
    expect(error, contains('name'));
  });

  // The certificate itself is valid without a facility signature, so nothing
  // is asked for when nobody signed.
  test('a certificate with no facility signature saves without a name', () {
    expect(
      signatureStepError(
        techSigned: true,
        requiresCustomerSig: false,
        clientSigned: false,
        clientName: '',
      ),
      isNull,
    );
  });

  test('nothing is wrong when the facility signed and was named', () {
    expect(
      signatureStepError(
        techSigned: true,
        requiresCustomerSig: true,
        clientSigned: true,
        clientName: 'A Nurse',
      ),
      isNull,
    );
  });

  test('a name is not demanded when nobody from the facility signed', () {
    expect(
      signatureStepError(
        techSigned: true,
        requiresCustomerSig: false,
        clientSigned: false,
        clientName: '',
      ),
      isNull,
    );
  });
}
