import 'package:flutter/foundation.dart';

@immutable
class Asset {
  const Asset({
    required this.id,
    required this.equipmentType,
    required this.isActive,
    required this.isCondemned,
    required this.isProvisional,
    required this.createdAt,
    required this.updatedAt,
    this.assetId,
    this.model,
    this.manufacturer,
    this.serialNumber,
    this.barcode,
    this.hospital,
    this.location,
    this.condition,
    this.nextServiceDate,
    this.syncedAt,
  });

  final int id;
  final int? assetId;
  final String equipmentType;
  final String? model;
  final String? manufacturer;
  final String? serialNumber;
  final String? barcode;
  final String? hospital;
  final String? location;
  final String? condition;
  final bool isActive;
  final bool isCondemned;
  final DateTime? nextServiceDate;
  final bool isProvisional;
  final DateTime? syncedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayName =>
      assetId != null ? '$assetId — $equipmentType' : 'PROV — $equipmentType';

  bool get isServiceDue {
    if (nextServiceDate == null) return false;
    return nextServiceDate!
        .isBefore(DateTime.now().add(const Duration(days: 30)));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Asset && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
