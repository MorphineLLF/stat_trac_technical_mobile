import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/features/certification/data/powersync_cert_mapper.dart';
import 'package:stat_trac_technical/features/certification/domain/entities/test_template_name.dart';

void main() {
  group('templateNameFromPowerSync', () {
    test('maps the header columns', () {
      final t = templateNameFromPowerSync(const {
        'TestTemplateNameID': 12,
        'TestTemplateName': 'Electrical Safety Test IEC 62353',
        'TestTemplateCertName': 'OVP',
        'TestTemplateType': 1,
        'TestTemplateDocNo': 'DOC-001',
        'TestTemplateNote': 'Annual',
      });

      expect(t.id, 12);
      expect(t.templateName, 'Electrical Safety Test IEC 62353');
      expect(t.certName, 'OVP');
      expect(t.certType, CertType.test);
      expect(t.docNo, 'DOC-001');
    });

    test('maps the three certificate types', () {
      CertType typeOf(int v) =>
          templateNameFromPowerSync({'TestTemplateNameID': 1,
              'TestTemplateType': v}).certType;

      expect(typeOf(1), CertType.test);
      expect(typeOf(2), CertType.qa);
      expect(typeOf(3), CertType.commission);
    });

    // THE trap. TestTemplateTestEquipQty is a Postgres numeric, so it crosses
    // the sync stream as the STRING "2.00". The Horse-era model cast it with
    // `as int?`, which throws on a string — that cast is the bug this mapper
    // exists to not repeat.
    test('reads the equipment quantity from a numeric string', () {
      expect(
        templateNameFromPowerSync(const {
          'TestTemplateNameID': 1,
          'TestTemplateTestEquipQty': '2.00',
        }).testEquipQty,
        2,
      );
      expect(
        templateNameFromPowerSync(const {
          'TestTemplateNameID': 1,
          'TestTemplateTestEquipQty': null,
        }).testEquipQty,
        0,
      );
    });

    test('reads the boolean switches from 0/1 integers', () {
      final on = templateNameFromPowerSync(const {
        'TestTemplateNameID': 1,
        'TestTemplateCustomerSig': 1,
        'TestTemplateEditDate': 1,
        'TestTemplateNextService': 1,
      });
      expect(on.customerSigRequired, isTrue);
      expect(on.editDate, isTrue);
      expect(on.nextService, isTrue);

      final off = templateNameFromPowerSync(const {
        'TestTemplateNameID': 1,
        'TestTemplateCustomerSig': 0,
      });
      expect(off.customerSigRequired, isFalse);
    });
  });

  group('templateItemFromPowerSync', () {
    test('maps a test line', () {
      final i = templateItemFromPowerSync(const {
        'TestTemplateID': 900,
        'TestTempCertificateNameID': 12,
        'TestTempDescriptionID': 'ELECTRICAL SAFETY TESTS',
        'TestTempDescriptionNo': 2,
        'TestTempDescription': 'Earth resistance',
        'TestTempValue': '< 0.3 ohm',
        'TestTempActualValue': '0.0',
        'TestTempNotes': 'per IEC',
      });

      expect(i.id, 900);
      expect(i.certificateNameId, 12);
      expect(i.descriptionId, 'ELECTRICAL SAFETY TESTS');
      expect(i.descriptionNo, 2);
      expect(i.description, 'Earth resistance');
      expect(i.expectedValue, '< 0.3 ohm');
      expect(i.notes, 'per IEC');
    });

    // The dash means this line takes no reading. It must survive verbatim: the
    // grid pre-populates the actual value from it so the dash reaches
    // TestOutput, and the server counts a dash as a complete line.
    test('preserves the dash sentinel and its meaning', () {
      final dash = templateItemFromPowerSync(const {
        'TestTemplateID': 1,
        'TestTempActualValue': '-',
      });
      expect(dash.actualValueTemplate, '-');
      expect(dash.noActualRequired, isTrue);

      final measured = templateItemFromPowerSync(const {
        'TestTemplateID': 2,
        'TestTempActualValue': '0.0',
      });
      expect(measured.noActualRequired, isFalse);
    });
  });
}
