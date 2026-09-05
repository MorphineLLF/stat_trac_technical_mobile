import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/features/certification/data/powersync_cert_mapper.dart';

void main() {
  group('assetPmTaskFromPowerSync', () {
    test('maps the columns the picker shows', () {
      final t = assetPmTaskFromPowerSync(const {
        'PmTaskID': 901,
        'PmAssetID': 4711,
        'PmTaskDescription': '6 Monthly Service',
        'PmTaskScheduleDate': '2026-12-01',
        'PmTaskActive': 1,
        'PmTaskInterval': 6,
        'PmTaskIntervalType': 'Months',
        'PmTaskType': 1,
      });

      expect(t.pmTaskId, 901);
      expect(t.assetId, 4711);
      expect(t.description, '6 Monthly Service');
      expect(t.scheduleDate, DateTime(2026, 12, 1));
      expect(t.active, isTrue);
      expect(t.intervalType, 'Months');
    });

    test('reads active from a 0/1 integer', () {
      expect(assetPmTaskFromPowerSync(const {'PmTaskID': 1, 'PmTaskActive': 1})
          .active, isTrue);
      expect(assetPmTaskFromPowerSync(const {'PmTaskID': 1, 'PmTaskActive': 0})
          .active, isFalse);
    });

    // PmTaskInterval is an integer column, but interval is a String on the
    // entity. It must arrive as usable text, not "6.0" or an exception.
    test('renders the interval as text', () {
      expect(
        assetPmTaskFromPowerSync(const {'PmTaskID': 1, 'PmTaskInterval': 6})
            .interval,
        '6',
      );
    });

    test('survives an absent description rather than throwing', () {
      final t = assetPmTaskFromPowerSync(const {'PmTaskID': 5});
      expect(t.pmTaskId, 5);
      expect(t.description, isNotEmpty);
    });

    // A meter-based task comes round on readings, not months, so no interval
    // arithmetic applies. The server refuses to propose a date for one
    // (NextServiceProposal returns false), and the technician must be asked.
    // The app has to be able to tell them apart.
    test('distinguishes a meter-based task from a dated one', () {
      expect(
        assetPmTaskFromPowerSync(const {'PmTaskID': 1, 'PmTaskType': 2})
            .isMeterBased,
        isTrue,
      );
      expect(
        assetPmTaskFromPowerSync(const {'PmTaskID': 1, 'PmTaskType': 1})
            .isMeterBased,
        isFalse,
      );
    });
  });
}
