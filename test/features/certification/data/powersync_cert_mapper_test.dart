import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/features/certification/data/powersync_cert_mapper.dart';

void main() {
  group('certificateSummaryFromPowerSync', () {
    test('maps the columns the list shows', () {
      final c = certificateSummaryFromPowerSync(const {
        'TestCertificateID': 5030,
        'TestCertType': 1,
        'TestDate': '2026-06-04',
        'TestCertificateDescription': 'Electrical Safety Test IEC 62353',
        'TestCertPatientSafe': 1,
        'TestServiceDescription': '6 Monthly Service',
        'TestAssetID': 4711,
      });

      expect(c.certificateNo, 5030);
      expect(c.certType, 1);
      expect(c.patientSafe, 1);
      expect(c.pmTaskDescription, '6 Monthly Service');
      expect(c.createdAt, DateTime(2026, 6, 4));
    });

    // Everything visible here came from the server, so it is already synced.
    // The pending state belonged to the Horse-era push queue.
    test('is always synced, never pending', () {
      final c = certificateSummaryFromPowerSync(const {
        'TestCertificateID': 1,
        'TestCertType': 1,
      });
      expect(c.syncStatus, 'synced');
    });

    test('survives a missing date rather than throwing', () {
      final c = certificateSummaryFromPowerSync(const {
        'TestCertificateID': 2,
        'TestCertType': 2,
        'TestDate': null,
      });
      expect(c.certificateNo, 2);
      expect(c.createdAt, isNotNull);
    });
  });

  group('testOutputFromPowerSync', () {
    // TestPass/TestFail/TestNA are Postgres booleans and arrive as 0/1.
    test('reads the three verdict flags from 0/1 integers', () {
      final pass = testOutputFromPowerSync(const {
        'TestOutPutID': 1,
        'TestOutputCertID': 5030,
        'TestPass': 1,
        'TestFail': 0,
        'TestNA': 0,
      });
      expect(pass.pass, isTrue);
      expect(pass.fail, isFalse);
      expect(pass.na, isFalse);

      final na = testOutputFromPowerSync(const {
        'TestOutPutID': 2,
        'TestOutputCertID': 5030,
        'TestPass': 0,
        'TestFail': 0,
        'TestNA': 1,
      });
      expect(na.na, isTrue);
    });

    test('maps the measurement columns', () {
      final o = testOutputFromPowerSync(const {
        'TestOutPutID': 7,
        'TestOutputCertID': 5030,
        'TestOutputAssetID': 4711,
        'TestDescriptionID': 'ELECTRICAL SAFETY TESTS',
        'TestDescription': 'Earth resistance',
        'TestValue': '< 0.3 ohm',
        'TestActualValue': '0.12',
        'TestNote': 'from template',
      });

      expect(o.id, 7);
      expect(o.certificateId, 5030);
      expect(o.assetId, 4711);
      // A free-text section heading, not an identifier and not a key.
      expect(o.descriptionId, 'ELECTRICAL SAFETY TESTS');
      expect(o.description, 'Earth resistance');
      expect(o.expectedValue, '< 0.3 ohm');
      expect(o.actualValue, '0.12');
      expect(o.notes, 'from template');
    });

    // The dash is the register saying there is nothing to measure here. It
    // must survive verbatim: the server counts a line as valued when the
    // actual value is non-empty, so a dash is a complete line, not a gap.
    test('preserves the dash sentinel verbatim', () {
      final o = testOutputFromPowerSync(const {
        'TestOutPutID': 8,
        'TestOutputCertID': 5030,
        'TestActualValue': '-',
      });
      expect(o.actualValue, '-');
    });
  });
}
