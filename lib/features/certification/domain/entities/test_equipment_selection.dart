import 'package:flutter/foundation.dart';

import 'test_equipment_asset.dart';

@immutable
class TestEquipmentSelection {
  const TestEquipmentSelection({
    required this.assetId,
    this.manufacturer,
    this.model,
    this.serialNo,
    this.calDate,
  });

  factory TestEquipmentSelection.fromAsset(TestEquipmentAsset a) =>
      TestEquipmentSelection(
        assetId: a.assetId,
        manufacturer: a.manufacturer,
        model: a.model,
        serialNo: a.serialNo,
        calDate: a.calDate,
      );

  final int assetId;
  final String? manufacturer;
  final String? model;
  final String? serialNo;
  final String? calDate;

  String get displayName =>
      [manufacturer, model].where((s) => s != null && s.isNotEmpty).join(' ');

  String get subtitleText {
    final parts = <String>[];
    if (serialNo != null && serialNo!.isNotEmpty) parts.add('S/N: $serialNo');
    if (calDate != null && calDate!.isNotEmpty) parts.add('Cal: $calDate');
    return parts.join(' · ');
  }
}
