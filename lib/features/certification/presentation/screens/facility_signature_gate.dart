/// Whether a facility signature can be added to a certificate at all.
enum FacilitySignatureState {
  /// The design asks for a client signature and nobody has given one.
  available,

  /// That side has already signed. **The first signature stands** and is
  /// never overwritten, so a second cannot land.
  alreadySigned,

  /// This certificate's design does not ask for a client signature.
  notRequired,

  /// No mobile id, so there is nothing to name the certificate by. A
  /// certificate raised in the office has none.
  cannotBeSigned,
}

/// What the certificate detail screen may offer.
///
/// **Checked here so a signature is never taken and then thrown away.** The
/// server refuses a client signature on a design that never asked for one
/// (`no_client_signature`) and refuses a second one outright
/// (`already_signed`) — and a technician who has watched somebody sign
/// believes it is filed. Capturing a real signature from a real person and
/// discarding it is worse than not offering the pen, which is the lesson the
/// wizard already taught once.
///
/// [testType] is the certificate's `TestType`: 1 means a client signature is
/// required, anything else means it is not. [clientNameSignature] is
/// `TestClientNameSignature` — the name recorded when the client signed, so a
/// non-blank one is the evidence that they have.
FacilitySignatureState facilitySignatureState({
  required int? testType,
  required String? clientNameSignature,
  required String? mobileId,
}) {
  // Reported first because it is the most specific thing true about the
  // certificate, and the most useful thing to tell somebody standing in
  // front of the person who signed it.
  if ((clientNameSignature ?? '').trim().isNotEmpty) {
    return FacilitySignatureState.alreadySigned;
  }

  if (testType != 1) {
    return FacilitySignatureState.notRequired;
  }

  if (mobileId == null || mobileId.isEmpty) {
    return FacilitySignatureState.cannotBeSigned;
  }

  return FacilitySignatureState.available;
}

/// What to tell somebody about [state], on the button that will not open.
String facilitySignatureTooltip(FacilitySignatureState state) =>
    switch (state) {
      FacilitySignatureState.available => 'Add facility signature',
      FacilitySignatureState.alreadySigned =>
        'The facility has already signed — the first signature stands',
      FacilitySignatureState.notRequired =>
        'This certificate does not ask for a facility signature',
      FacilitySignatureState.cannotBeSigned =>
        'This certificate cannot be signed from the app',
    };
