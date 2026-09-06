import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/features/certification/data/models/certificate_summary.dart';
import 'package:stat_trac_technical/features/certification/presentation/screens/certificate_search.dart';

CertificateSummary _cert({
  int id = 8475,
  int? certificateNo = 8475,
  String? hospital = 'Netcare Milpark',
  String? certName = 'Electrical Safety Test',
  String? equipmentType = 'Infusion Pump',
}) => CertificateSummary(
  id: id,
  certificateNo: certificateNo,
  certType: 1,
  syncStatus: 'synced',
  createdAt: DateTime(2026, 9, 6),
  certName: certName,
  equipmentType: equipmentType,
  hospital: hospital,
);

void main() {
  test('an empty search keeps everything', () {
    expect(certificateMatchesSearch(_cert(), ''), isTrue);
    expect(certificateMatchesSearch(_cert(), '   '), isTrue);
  });

  // The hospital is what a technician is standing in, so it is the first
  // thing they will type.
  test('finds a certificate by its hospital', () {
    expect(certificateMatchesSearch(_cert(), 'milpark'), isTrue);
  });

  test('finds a certificate by its number', () {
    expect(certificateMatchesSearch(_cert(), '8475'), isTrue);
  });

  test('finds a certificate by its equipment type', () {
    expect(certificateMatchesSearch(_cert(), 'infusion'), isTrue);
  });

  test('finds a certificate by its name', () {
    expect(certificateMatchesSearch(_cert(), 'electrical'), isTrue);
  });

  test('ignores case and surrounding space, as a thumb on glass will not', () {
    expect(certificateMatchesSearch(_cert(), '  MILPARK '), isTrue);
  });

  test('says no when nothing matches', () {
    expect(certificateMatchesSearch(_cert(), 'ventilator'), isFalse);
  });

  // A certificate with no hospital and no equipment must not crash the list
  // or match everything — it simply does not match a search for a hospital.
  test('a certificate missing every searchable field matches nothing typed',
      () {
    final bare = _cert(
      hospital: null,
      certName: null,
      equipmentType: null,
      certificateNo: null,
    );

    expect(certificateMatchesSearch(bare, 'milpark'), isFalse);
    expect(certificateMatchesSearch(bare, ''), isTrue);
  });
}
