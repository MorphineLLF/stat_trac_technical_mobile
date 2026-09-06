import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/features/certification/presentation/widgets/issue_inputs.dart';

void main() {
  group('the verdict', () {
    // Three fixed constants and no arithmetic anywhere. PatientSafe 3 is
    // VOID — TestCertificate.Void() is PatientSafe == 3 — so an off-by-one on
    // a computed verdict would void a certificate rather than merely get the
    // verdict wrong. IssueCertificate refuses anything but 0, 1 and 2, which
    // makes the wire safe; this makes the app safe.
    test('is one of exactly three values, none of them void', () {
      expect(IssueVerdict.values.map((v) => v.wire).toList(), [1, 2, 0]);
      expect(IssueVerdict.values.map((v) => v.wire), isNot(contains(3)));
    });

    test('names each one the way a technician would read it', () {
      expect(IssueVerdict.compliant.wire, 1);
      expect(IssueVerdict.incomplete.wire, 2);
      expect(IssueVerdict.nonCompliant.wire, 0);
      expect(IssueVerdict.nonCompliant.label, 'Non-Compliant');
    });
  });

  group('the next service date', () {
    final testDate = DateTime(2026, 9, 6);

    test('is the test date plus the PM interval in months', () {
      expect(
        defaultNextService(
          testDate: testDate,
          interval: 6,
          intervalType: 'Months',
        ),
        DateTime(2027, 3, 6),
      );
    });

    test('handles a yearly interval', () {
      expect(
        defaultNextService(
          testDate: testDate,
          interval: 1,
          intervalType: 'Years',
        ),
        DateTime(2027, 9, 6),
      );
    });

    // A meter task comes round on readings rather than months, so there is no
    // date to compute and the technician is asked instead of being offered a
    // guess dressed up as an answer.
    test('offers nothing for a meter task', () {
      expect(
        defaultNextService(
          testDate: testDate,
          interval: 500,
          intervalType: 'Hours',
        ),
        isNull,
      );
    });

    test('offers nothing when there is no interval to go on', () {
      expect(
        defaultNextService(
          testDate: testDate,
          interval: null,
          intervalType: 'Months',
        ),
        isNull,
      );
    });

    // The server refuses a next service that falls before the test date. A
    // default that trips that refusal would hand the technician a pre-filled
    // rejection, which is worse than offering nothing.
    test('never offers a date before the test date', () {
      final d = defaultNextService(
        testDate: testDate,
        interval: -6,
        intervalType: 'Months',
      );

      expect(d == null || !d.isBefore(testDate), isTrue);
    });
  });

  group('what stops the certificate being issued', () {
    test('a verdict must be chosen', () {
      expect(
        issueInputsError(
          verdict: null,
          needsNextService: false,
          nextService: null,
          testDate: DateTime(2026, 9, 6),
        ),
        contains('verdict'),
      );
    });

    test('a design that asks for a next service date must have one', () {
      expect(
        issueInputsError(
          verdict: IssueVerdict.compliant,
          needsNextService: true,
          nextService: null,
          testDate: DateTime(2026, 9, 6),
        ),
        contains('next service'),
      );
    });

    test('the next service cannot fall before the test date', () {
      expect(
        issueInputsError(
          verdict: IssueVerdict.compliant,
          needsNextService: true,
          nextService: DateTime(2026, 9, 5),
          testDate: DateTime(2026, 9, 6),
        ),
        contains('before'),
      );
    });

    test('a design that does not ask for one is complete without it', () {
      expect(
        issueInputsError(
          verdict: IssueVerdict.nonCompliant,
          needsNextService: false,
          nextService: null,
          testDate: DateTime(2026, 9, 6),
        ),
        isNull,
      );
    });

    test('nothing is wrong when everything was answered', () {
      expect(
        issueInputsError(
          verdict: IssueVerdict.compliant,
          needsNextService: true,
          nextService: DateTime(2027, 3, 6),
          testDate: DateTime(2026, 9, 6),
        ),
        isNull,
      );
    });
  });

  test('a date reaches the wire as the server spells it', () {
    expect(wireDate(DateTime(2027, 3, 6)), '2027-03-06');
    expect(wireDate(DateTime(2027, 12, 31)), '2027-12-31');
  });
}
