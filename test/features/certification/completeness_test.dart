import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/features/certification/domain/entities/test_output.dart';
import 'package:stat_trac_technical/features/certification/presentation/widgets/certificate_completeness.dart';

TestOutput _line({
  bool pass = true,
  String? actual = '12.3',
}) => TestOutput(
  id: 0,
  certificateId: 0,
  description: 'a test',
  actualValue: actual,
  pass: pass,
  fail: false,
  na: !pass,
);

void main() {
  // The server's three refusals, checked on the device so a technician hears
  // them at the machine instead of after driving away. All three are 422 and
  // permanent, and one rejection refuses the whole batch — readings included.
  test('a certificate with no tests on it cannot be issued', () {
    expect(
      certificateCompletenessError(outputs: const [], allItemsComplete: true),
      contains('no tests'),
    );
  });

  test('every test must be marked pass, fail or N/A', () {
    expect(
      certificateCompletenessError(
        outputs: [_line()],
        allItemsComplete: false,
      ),
      contains('pass, fail'),
    );
  });

  test('a complete certificate has nothing to say', () {
    expect(
      certificateCompletenessError(
        outputs: [_line()],
        allItemsComplete: true,
      ),
      isNull,
    );
  });

  // The dash is the register saying there is nothing to measure on that line.
  // The server counts it as a complete reading, so the device must too — a
  // check stricter than the server's blocks work the register would accept.
  test('a dash is a reading, not a missing one', () {
    expect(
      certificateCompletenessError(
        outputs: [_line(actual: '-')],
        allItemsComplete: true,
      ),
      isNull,
    );
  });

  test('an empty reading is not one', () {
    expect(
      certificateCompletenessError(
        outputs: [_line(actual: '  ')],
        allItemsComplete: true,
      ),
      contains('reading'),
    );
  });

  // Nothing said about a reading that was never asked for: a line whose
  // actual value is absent because the template does not want one is
  // complete, and the grid has already decided that.
  test('says nothing about a line with no reading expected', () {
    expect(
      certificateCompletenessError(
        outputs: [_line(actual: null)],
        allItemsComplete: true,
      ),
      isNull,
    );
  });
}
