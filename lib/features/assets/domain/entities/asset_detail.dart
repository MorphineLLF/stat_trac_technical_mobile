import 'package:flutter/foundation.dart';

@immutable
class AssetDetail {
  const AssetDetail({
    required this.assetId,
    required this.isActive,
    required this.isCondemned,
    required this.isLoan,
    required this.isDemo,
    required this.hasServicePlan,
    this.equipmentType,
    this.model,
    this.manufacturer,
    this.serialNumber,
    this.barcode,
    this.hospital,
    this.hospitalGroup,
    this.location,
    this.condition,
    this.notes,
    this.softwareVersion,
    this.accessories,
    this.risk,
    this.assetType,
    this.moduletype,
    this.hours,
    this.nextServiceDate,
    this.lastServiceDate,
    this.warrantyDateStart,
    this.warrantyEndDate,
    this.warrantyPeriod,
    this.servicePlanStartDate,
    this.servicePlanExpDate,
    this.servicePlanValue,
    this.manufactureDate,
    this.deliverDate,
    this.commissionDate,
  });

  final int assetId;
  final String? equipmentType;
  final String? model;
  final String? manufacturer;
  final String? serialNumber;
  final String? barcode;
  final String? hospital;
  final String? hospitalGroup;
  final String? location;
  final String? condition;
  final String? notes;
  final String? softwareVersion;
  final String? accessories;
  final bool isActive;
  final bool isCondemned;
  final bool isLoan;
  final bool isDemo;

  /// AssetRisk: 1=High, 2=Medium, 3=Low
  final int? risk;

  /// AssetType: 0=Non-warranty, 1=Warranty
  final int? assetType;

  /// AssetModuleType: 1=Main, 2=Module
  final int? moduletype;

  final int? hours;
  final DateTime? nextServiceDate;
  final DateTime? lastServiceDate;
  final DateTime? warrantyDateStart;
  final DateTime? warrantyEndDate;
  final int? warrantyPeriod;
  final bool hasServicePlan;
  final DateTime? servicePlanStartDate;
  final DateTime? servicePlanExpDate;
  final double? servicePlanValue;
  final DateTime? manufactureDate;
  final DateTime? deliverDate;
  final DateTime? commissionDate;

  String get riskLabel => switch (risk) {
        1 => 'High',
        2 => 'Medium',
        3 => 'Low',
        _ => 'Unknown',
      };

  bool get isUnderWarranty {
    if (warrantyEndDate == null) return false;
    return warrantyEndDate!.isAfter(DateTime.now());
  }

  bool get isServiceDueSoon {
    if (nextServiceDate == null) return false;
    return nextServiceDate!.isBefore(DateTime.now().add(const Duration(days: 30)));
  }
}
