import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/features/certification/domain/entities/test_equipment_asset.dart';

TestEquipmentAsset _analyser({DateTime? calDate}) => TestEquipmentAsset(
  id: 1,
  assetId: 1,
  equipmentType: 'ELECTRICAL SAFETY ANALYSER',
  calDate: calDate,
  syncedAt: DateTime(2026, 9, 5),
);

void main() {
  final now = DateTime(2026, 9, 5);

  test('an instrument calibrated into the future can be used', () {
    final a = _analyser(calDate: DateTime(2026, 12, 1));
    expect(a.isCalExpiredAt(now), isFalse);
    expect(a.isUsableAt(now), isTrue);
  });

  test('an instrument past its calibration date cannot be used', () {
    final a = _analyser(calDate: DateTime(2026, 6, 1));
    expect(a.isCalExpiredAt(now), isTrue);
    expect(a.isUsableAt(now), isFalse);
  });

  test('calibration falling due today still counts as in calibration', () {
    expect(_analyser(calDate: now).isUsableAt(now), isTrue);
  });

  // The live cause. All 11 analysers on the device carry no calibration date,
  // so an expiry check that only rejects past dates rejects nothing and every
  // one of them stays selectable.
  //
  // An instrument with no recorded calibration is not proven to be in
  // calibration, and a certificate naming it is not defensible. Unknown is
  // not the same as valid.
  test('an instrument with no calibration date cannot be used', () {
    expect(_analyser(calDate: null).isUsableAt(now), isFalse);
  });

  // It is unusable without being expired, and the two need different wording:
  // "EXPIRED" on an instrument that was never dated sends a technician looking
  // for a lapsed certificate that never existed.
  test('an undated instrument is unusable but not expired', () {
    final a = _analyser(calDate: null);
    expect(a.isCalExpiredAt(now), isFalse);
    expect(a.hasCalDate, isFalse);
  });
}
