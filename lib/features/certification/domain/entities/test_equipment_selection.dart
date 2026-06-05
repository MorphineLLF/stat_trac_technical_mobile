import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'test_equipment_asset.dart';

@immutable
class TestEquipmentSelection {
  const TestEquipmentSelection({
    required this.assetId,
    this.equipmentType,
    this.manufacturer,
    this.model,
    this.serialNo,
    this.calDate,
  });

  factory TestEquipmentSelection.fromAsset(TestEquipmentAsset a) =>
      TestEquipmentSelection(
        assetId: a.assetId,
        equipmentType: a.equipmentType,
        manufacturer: a.manufacturer,
        model: a.model,
        serialNo: a.serialNo,
        calDate: a.calDate,
      );

  final int assetId;
  final String? equipmentType;
  final String? manufacturer;
  final String? model;
  final String? serialNo;
  final DateTime? calDate;

  bool get isCalExpired => calDate != null && calDate!.isBefore(DateTime.now());

  String get displayName =>
      [manufacturer, model].where((s) => s != null && s.isNotEmpty).join(' ');

  String get subtitleText {
    final parts = <String>[];
    if (serialNo != null && serialNo!.isNotEmpty) parts.add('S/N: $serialNo');
    if (calDate != null) {
      parts.add('Next Cal: ${DateFormat('dd MMM yyyy').format(calDate!)}');
    }
    return parts.join(' · ');
  }
}
