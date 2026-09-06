/// The three verdicts a certificate can carry, and nothing else.
///
/// **Three fixed constants, never arithmetic.** `verdict` is written straight
/// to `TestCertPatientSafe`, and `PatientSafe == 3` is VOID — a voided
/// certificate is the end of it. `IssueCertificate` refuses anything but 0, 1
/// and 2, which keeps the wire safe; keeping these as named constants rather
/// than a computed number is what keeps the app safe, because an off-by-one
/// on a computed verdict would void a certificate rather than merely get the
/// verdict wrong.
///
/// **`0` is Non-Compliant and is a real answer**, not an absence. A machine
/// that failed its test has to be certifiable as having failed, which is why
/// it is never a default and the technician must choose.
enum IssueVerdict {
  compliant(1, 'Compliant'),
  incomplete(2, 'Incomplete'),
  nonCompliant(0, 'Non-Compliant');

  const IssueVerdict(this.wire, this.label);

  /// The value the server stores in `TestCertPatientSafe`.
  final int wire;

  /// What the technician reads on the button.
  final String label;
}

/// A next service date to offer, or null when there is nothing honest to
/// offer.
///
/// **The date the device sends is the date that lands.** The server computes
/// nothing: `TestNextService` is written verbatim, and the PM task's schedule
/// date is set to the same value. So a default here is the date the register
/// will hold, which is why offering one is worth doing.
///
/// Null for a meter-based task: it comes round on readings rather than
/// months, so there is no date to compute and a guess dressed up as an answer
/// is worse than an empty box.
///
/// Never before [testDate]. The server refuses that, and a default that trips
/// the refusal hands the technician a pre-filled rejection.
DateTime? defaultNextService({
  required DateTime testDate,
  required int? interval,
  required String? intervalType,
}) {
  if (interval == null || interval <= 0) return null;

  final months = switch (intervalType?.trim().toLowerCase()) {
    'months' || 'month' => interval,
    'years' || 'year' => interval * 12,
    'weeks' || 'week' => null,
    _ => null,
  };
  if (months == null) return null;

  final due = DateTime(testDate.year, testDate.month + months, testDate.day);
  return due.isBefore(testDate) ? null : due;
}

/// What is missing before this certificate can be issued, or null when
/// nothing is.
String? issueInputsError({
  required IssueVerdict? verdict,
  required bool needsNextService,
  required DateTime? nextService,
  required DateTime testDate,
}) {
  if (verdict == null) {
    return 'Choose a verdict before issuing this certificate';
  }

  if (needsNextService) {
    if (nextService == null) {
      return 'This certificate needs a next service date';
    }
    if (nextService.isBefore(testDate)) {
      return 'The next service cannot fall before the test date';
    }
  }

  return null;
}

/// A date as the server spells it: `2006-01-02`.
String wireDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
