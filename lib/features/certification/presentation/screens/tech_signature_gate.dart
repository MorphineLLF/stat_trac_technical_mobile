/// Whether the technician's signature can be added to a certificate here.
enum TechSignatureState {
  /// Made on this phone, by the person signed in, and not yet signed.
  available,

  /// Signed already. **The first signature stands** — the server refuses a
  /// second as `already_signed`.
  alreadySigned,

  /// Somebody else's certificate. The server does not check who signs the
  /// technician's side, so this is where that is checked.
  notYours,

  /// Not made on this phone, or never given a mobile id.
  notFromThisPhone,
}

/// What this phone knows about its own copy of a certificate.
typedef LocalTechSignature = ({int? technicianId, bool techSigned});

/// What the certificate detail screen may offer the technician.
///
/// **Only a certificate this phone made can be signed here, and that is the
/// whole of the rule rather than a limitation.** Signatures are bytea and do
/// not come down the sync stream, so for any other certificate the phone
/// cannot tell signed from unsigned — and the register holds thousands signed
/// from a desk. Offering the pen on all of them would take signatures the
/// server then refuses.
///
/// [local] is this phone's row for [mobileId], or null when it has none.
TechSignatureState techSignatureState({
  required String? mobileId,
  required LocalTechSignature? local,
  required int? currentUserId,
}) {
  if (mobileId == null || mobileId.isEmpty || local == null) {
    return TechSignatureState.notFromThisPhone;
  }

  // Before ownership: a signed certificate is signed whoever is looking.
  if (local.techSigned) return TechSignatureState.alreadySigned;

  // A signature is evidence of the person who did the work. The name on the
  // certificate comes from the server's token, but the picture does not, so
  // another login signing here would put the wrong hand under the right name.
  if (currentUserId == null || local.technicianId != currentUserId) {
    return TechSignatureState.notYours;
  }

  return TechSignatureState.available;
}
