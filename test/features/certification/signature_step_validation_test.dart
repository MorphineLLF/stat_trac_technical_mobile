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

  // The bug this exists for. A client signature was drawn, the name was left
  // blank because the field says "Optional", and the signature was then
  // discarded on the way to the server — silently, with only a log line
  // recording that a real signature had been thrown away.
  test('a facility signature with no name is refused, not silently dropped',
      () {
    final error = signatureStepError(
      techSigned: true,
      requiresCustomerSig: true,
      clientSigned: true,
      clientName: '   ',
    );

    expect(error, isNotNull);
    expect(error, contains('name'));
  });

  // The name is required by the signature, not by the template. Someone who
  // signs on a certificate that never asked them to still has to be named,
  // or their signature is dropped exactly the same way.
  test('an unasked-for facility signature still needs a name', () {
    expect(
      signatureStepError(
        techSigned: true,
        requiresCustomerSig: false,
        clientSigned: true,
        clientName: '',
      ),
      isNotNull,
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
