import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/sync/powersync_types.dart';

void main() {
  // Postgres numeric crosses the sync stream as a STRING. This is the trap
  // the generated schema's header warns about: "parse it, never assume a num".
  group('psNum', () {
    test('parses a numeric arriving as a string', () {
      expect(psNum('125896.00'), 125896.0);
      expect(psNum('2.00'), 2.0);
      expect(psNum('0'), 0.0);
      expect(psNum('-1.5'), -1.5);
    });

    test('accepts a real number unchanged', () {
      expect(psNum(42), 42.0);
      expect(psNum(1.5), 1.5);
    });

    test('returns null for null, empty and unparseable values', () {
      expect(psNum(null), isNull);
      expect(psNum(''), isNull);
      expect(psNum('   '), isNull);
      expect(psNum('not a number'), isNull);
    });
  });

  group('psInt', () {
    // "2.00" is what TestTemplateTestEquipQty actually arrives as, and a
    // direct `as int` cast on it throws.
    test('parses a whole numeric arriving as a decimal string', () {
      expect(psInt('2.00'), 2);
      expect(psInt('0.00'), 0);
    });

    test('truncates toward zero rather than throwing', () {
      expect(psInt('2.75'), 2);
      expect(psInt('-2.75'), -2);
    });

    test('accepts an int unchanged and defaults null safely', () {
      expect(psInt(7), 7);
      expect(psInt(null), isNull);
      expect(psInt('rubbish'), isNull);
    });
  });

  // Postgres boolean arrives as 0/1 integer.
  group('psBool', () {
    test('reads 0 and 1 as false and true', () {
      expect(psBool(1), isTrue);
      expect(psBool(0), isFalse);
    });

    test('accepts a real bool and treats null as false', () {
      expect(psBool(true), isTrue);
      expect(psBool(false), isFalse);
      expect(psBool(null), isFalse);
    });

    test('reads a numeric string, since numeric may arrive as text', () {
      expect(psBool('1'), isTrue);
      expect(psBool('0'), isFalse);
    });
  });

  // Dates, times and timestamps all arrive as ISO 8601 text.
  group('psDate', () {
    test('parses an ISO timestamp', () {
      expect(
        psDate('2026-09-05T13:03:41Z'),
        DateTime.utc(2026, 9, 5, 13, 3, 41),
      );
    });

    test('parses a bare date', () {
      expect(psDate('2026-09-05'), DateTime(2026, 9, 5));
    });

    test('returns null rather than throwing on empty or malformed input', () {
      expect(psDate(null), isNull);
      expect(psDate(''), isNull);
      expect(psDate('not a date'), isNull);
    });
  });
}
