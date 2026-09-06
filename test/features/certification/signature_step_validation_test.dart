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

  // A certificate is valid without a facility signature, so nothing about one
  // may stand between the technician and issuing it.
  test('an unnamed facility signature does not block the certificate', () {
    expect(
      signatureStepError(
        techSigned: true,
        requiresCustomerSig: false,
        clientSigned: true,
        clientName: '   ',
      ),
      isNull,
    );
  });

  // But it must not vanish either. It used to be discarded on the way to the
  // server with only a debug line recording that a real signature from a real
  // person had been thrown away.
  test('an unnamed facility signature is said out loud instead', () {
    final warning = signatureStepWarning(clientSigned: true, clientName: '  ');

    expect(warning, isNotNull);
    expect(warning, contains('name'));
  });

  test('nothing is said when the facility signed and was named', () {
    expect(
      signatureStepWarning(clientSigned: true, clientName: 'A Nurse'),
      isNull,
    );
  });

  test('nothing is said when nobody from the facility signed', () {
    expect(signatureStepWarning(clientSigned: false, clientName: ''), isNull);
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
