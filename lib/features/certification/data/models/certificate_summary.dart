import 'package:flutter/material.dart';

@immutable
class CertificateSummary {
  const CertificateSummary({
    required this.id,
    required this.certType,
    required this.syncStatus,
    required this.createdAt,
    this.certName,
    this.equipmentType,
    this.patientSafe,
  });

  final int id;
  final int certType;           // 1=Test, 2=QA, 3=Commission
  final String syncStatus;      // 'pending' | 'synced'
  final DateTime createdAt;
  final String? certName;       // test_template_names.test_template_cert_name
  final String? equipmentType;  // assets.equipment_type
  // 0 = Non-Compliant, 1 = Compliant, 2 = Incomplete
  final int? patientSafe;

  String get complianceLabel {
    switch (patientSafe) {
      case 1: return 'Compliant';
      case 0: return 'Non-Compliant';
      case 2: return 'Incomplete';
      default: return '';
    }
  }

  Color get complianceColor {
    switch (patientSafe) {
      case 1: return const Color(0xFF2E7D32);
      case 0: return const Color(0xFFC62828);
      case 2: return const Color(0xFFF57F17);
      default: return const Color(0xFF8A9BAE);
    }
  }

  String get typeLabel {
    switch (certType) {
      case 2: return 'QA';
      case 3: return 'CS';
      default: return 'TEST';
    }
  }

  bool get isPending => syncStatus == 'pending';

  factory CertificateSummary.fromMap(Map<String, dynamic> m) =>
      CertificateSummary(
        id: m['id'] as int,
        certType: m['cert_type'] as int? ?? 1,
        syncStatus: m['sync_status'] as String? ?? 'pending',
        createdAt: DateTime.parse(m['created_at'] as String),
        certName: m['cert_name'] as String?,
        equipmentType: m['equipment_type'] as String?,
        patientSafe: m['patient_safe'] as int?,
      );
}
