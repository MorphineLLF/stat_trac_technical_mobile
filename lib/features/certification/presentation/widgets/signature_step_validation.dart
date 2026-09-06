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

  return null;
}

/// Something the technician should know, which must NOT stop the certificate.
///
/// **A certificate is valid without a facility signature**, so nothing about
/// one may block issuing. But a facility signature with no name cannot be
/// sent — the server refuses it, because a signature with no record of who
/// gave it is not evidence of anything — and it used to be discarded in
/// silence, with a debug line as the only trace.
///
/// So it is said out loud and the certificate goes anyway. Telling somebody
/// what happened is not the same as standing in their way.
String? signatureStepWarning({
  required bool clientSigned,
  required String clientName,
}) {
  if (clientSigned && clientName.trim().isEmpty) {
    return 'The facility signature needs a contact name to be sent — the '
        'certificate will go without it';
  }
  return null;
}
