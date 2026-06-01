import 'package:flutter/foundation.dart';

@immutable
class CertificateSummary {
  const CertificateSummary({
    required this.id,
    required this.certType,
    required this.syncStatus,
    required this.createdAt,
    this.certName,
    this.equipmentType,
  });

  final int id;
  final int certType;           // 1=Test, 2=QA, 3=Commission
  final String syncStatus;      // 'pending' | 'synced'
  final DateTime createdAt;
  final String? certName;       // test_template_names.test_template_cert_name
  final String? equipmentType;  // assets.equipment_type

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
      );
}
