import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/features/certification/presentation/screens/tech_signature_gate.dart';

void main() {
  test('offered on this phone\'s own unsigned certificate', () {
    expect(
      techSignatureState(
        mobileId: 'cert-uuid',
        local: (technicianId: 31, techSigned: false),
        currentUserId: 31,
      ),
      TechSignatureState.available,
    );
  });

  // The first signature stands — the server answers already_signed.
  test('not offered once the technician has signed', () {
    expect(
      techSignatureState(
        mobileId: 'cert-uuid',
        local: (technicianId: 31, techSigned: true),
        currentUserId: 31,
      ),
      TechSignatureState.alreadySigned,
    );
  });

  // The server does not check who signs on the technician's side, so the
  // phone does: a signature is evidence of the person who did the work.
  test('not offered to anybody but the certificate\'s technician', () {
    expect(
      techSignatureState(
        mobileId: 'cert-uuid',
        local: (technicianId: 31, techSigned: false),
        currentUserId: 35,
      ),
      TechSignatureState.notYours,
    );
    expect(
      techSignatureState(
        mobileId: 'cert-uuid',
        local: (technicianId: null, techSigned: false),
        currentUserId: 31,
      ),
      TechSignatureState.notYours,
    );
    expect(
      techSignatureState(
        mobileId: 'cert-uuid',
        local: (technicianId: 31, techSigned: false),
        currentUserId: null,
      ),
      TechSignatureState.notYours,
    );
  });

  // Signatures do not come down the sync stream, so for a certificate this
  // phone did not make there is no way to know whether it is signed — and the
  // register holds thousands signed from a desk. Offering the pen on every one
  // of them would ask for signatures that are refused as already_signed.
  test('not offered on a certificate this phone did not make', () {
    expect(
      techSignatureState(mobileId: 'cert-uuid', local: null, currentUserId: 31),
      TechSignatureState.notFromThisPhone,
    );
    expect(
      techSignatureState(
        mobileId: null,
        local: (technicianId: 31, techSigned: false),
        currentUserId: 31,
      ),
      TechSignatureState.notFromThisPhone,
    );
    expect(
      techSignatureState(
        mobileId: '',
        local: (technicianId: 31, techSigned: false),
        currentUserId: 31,
      ),
      TechSignatureState.notFromThisPhone,
    );
  });
}
