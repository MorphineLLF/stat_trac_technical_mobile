import 'package:flutter/foundation.dart';

@immutable
class TestEquipmentAsset {
  const TestEquipmentAsset({
    required this.id,
    required this.assetId,
    this.equipmentType,
    this.manufacturer,
    this.model,
    this.serialNo,
    this.calDate,
    required this.syncedAt,
  });

  final int id;
  final int assetId;
  final String? equipmentType;
  final String? manufacturer;
  final String? model;
  final String? serialNo;
  final DateTime? calDate;
  final DateTime syncedAt;

  String get displayName =>
      [manufacturer, model].where((s) => s != null && s.isNotEmpty).join(' ');

  /// Whether a calibration due date is recorded at all.
  ///
  /// Measured on the device 2026-09-05: **all 11 analysers carry none.** That
  /// is why an expiry check alone protected nothing — it only rejects dates in
  /// the past, and there were no dates.
  bool get hasCalDate => calDate != null;

  /// Past its calibration date.
  bool isCalExpiredAt(DateTime now) =>
      calDate != null && calDate!.isBefore(_startOfDay(now));

  /// Whether this instrument may be named on a certificate.
  ///
  /// **An instrument with no recorded calibration date is not usable.** It has
  /// not been proven to be in calibration, and a certificate naming it is not
  /// defensible — unknown is not the same as valid. It is unusable without
  /// being *expired*, and the two need different wording on screen: "EXPIRED"
  /// on an instrument that was never dated sends a technician looking for a
  /// lapsed certificate that never existed.
  bool isUsableAt(DateTime now) => hasCalDate && !isCalExpiredAt(now);

  /// Calibration falling due today still counts as in calibration — the
  /// instrument is due, not lapsed.
  static DateTime _startOfDay(DateTime t) => DateTime(t.year, t.month, t.day);

  bool get isCalExpired => isCalExpiredAt(DateTime.now());

  /// Convenience for the picker.
  bool get isUsable => isUsableAt(DateTime.now());
}
