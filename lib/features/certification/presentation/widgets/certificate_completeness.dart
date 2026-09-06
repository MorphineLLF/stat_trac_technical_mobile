import '../../domain/entities/test_output.dart';

/// What the server would refuse this certificate for, checked on the device.
///
/// **The same three rules `IssueCertificate` enforces**, said at the machine
/// rather than after the technician has driven away. All three are 422 and
/// permanent, and one rejection refuses the whole batch — so a certificate
/// that trips them takes its readings down with it.
///
/// Deliberately no stricter than the server. A device check that refuses work
/// the register would have accepted is its own kind of failure: it stops a
/// technician finishing a job that was fine.
String? certificateCompletenessError({
  required List<TestOutput> outputs,
  required bool allItemsComplete,
}) {
  // A certificate with nothing on it is not a certificate. The server calls
  // this `invalid`, and the device can see it without asking.
  if (outputs.isEmpty) {
    return 'This certificate has no tests on it';
  }

  // Every line marked, and every line that wants a reading given one. The
  // grid already decides both — it knows which lines the template exempts —
  // so this reports its answer rather than second-guessing it.
  if (!allItemsComplete) {
    return 'Not every test has been marked pass, fail or N/A, or has a '
        'reading against it';
  }

  // A reading that was typed and then emptied. The dash is NOT this: it is
  // the register saying there is nothing to measure on that line, and the
  // server counts it as complete.
  for (final o in outputs) {
    final actual = o.actualValue;
    if (actual != null && actual.trim().isEmpty) {
      return 'Not every test has a reading against it';
    }
  }

  return null;
}
