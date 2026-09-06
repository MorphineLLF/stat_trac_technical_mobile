/// What is wrong with the signature step, or `null` when nothing is.
///
/// **A facility signature with no name is refused here rather than dropped
/// later, and that is the whole reason this exists.** The name field was
/// captioned "Optional", so a technician could take a real signature from a
/// real person, submit, and have it discarded on the way to the server — the
/// certificate went up signed by one side only, and the only record that a
/// signature had been thrown away was a line in a debug log nobody reads.
///
/// The name is required by the *signature*, not by the template. A client
/// signature carries the name of the person who gave it or it is not evidence
/// of anything, so somebody who signs on a certificate that never asked for a
/// facility signature must still be named.
String? signatureStepError({
  required bool techSigned,
  required bool requiresCustomerSig,
  required bool clientSigned,
  required String clientName,
}) {
  if (!techSigned) {
    return 'Technician signature is required';
  }

  if (requiresCustomerSig && !clientSigned) {
    return 'Facility signature is required';
  }

  // Only when somebody actually signed. A certificate with no facility
  // signature at all is valid and saves normally — this asks for a name to go
  // with a signature that exists, because that signature cannot be sent
  // without one and would otherwise be thrown away in silence.
  if (clientSigned && clientName.trim().isEmpty) {
    return 'Add the facility contact name before saving — the signature '
        'cannot be sent without it';
  }

  return null;
}
