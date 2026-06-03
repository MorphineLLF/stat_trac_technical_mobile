import 'package:flutter/foundation.dart';

@immutable
class TestEquipmentAsset {
  const TestEquipmentAsset({
    required this.id,
    required this.assetId,
    this.manufacturer,
    this.model,
    this.serialNo,
    this.calDate,
    required this.syncedAt,
  });

  final int id;
  final int assetId;
  final String? manufacturer;
  final String? model;
  final String? serialNo;
  final String? calDate;
  final DateTime syncedAt;

  String get displayName =>
      [manufacturer, model].where((s) => s != null && s.isNotEmpty).join(' ');
}
