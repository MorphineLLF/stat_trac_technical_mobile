import 'package:flutter/material.dart';

@immutable
class CertificateSummary {
  const CertificateSummary({
    required this.id,
    required this.certType,
    required this.syncStatus,
    required this.createdAt,
    this.certificateNo,
    this.certName,
    this.equipmentType,
    this.patientSafe,
    this.templateNameId,
    this.templateName,
    this.pmTaskDescription,
    this.hospital,
    this.mobileId,
    this.isLocal = false,
  });

  final int id;
  final int? certificateNo; // TestCertificateID on server
  final int certType; // 1=Test, 2=QA, 3=Commission
  final String syncStatus; // 'pending' | 'synced'
  final DateTime createdAt;
  final String? certName; // test_template_names.test_template_cert_name
  final String?
  templateName; // test_template_names.test_template_name (fallback)
  final String? equipmentType; // assets.equipment_type
  // 0 = Non-Compliant, 1 = Compliant, 2 = Incomplete
  final int? patientSafe;
  final int? templateNameId;
  final String? pmTaskDescription;

  /// The facility the equipment lives in, from the asset.
  ///
  /// Shown as the headline in the list: a technician looking for a
  /// certificate knows which hospital they were standing in long before they
  /// remember what the template was called.
  final String? hospital;

  /// The uuid this certificate travelled under, from TestMobileID.
  ///
  /// It is how a signature added later names the certificate — the server
  /// resolves it from the table, so one uploaded last week signs today. A
  /// certificate created in the office has none and cannot be signed here.
  final String? mobileId;

  /// Finished on this device and not yet confirmed by the server.
  ///
  /// A local certificate's readings live in local storage only, so every
  /// screen showing one must read them from there — the server has nothing to
  /// give back yet. It is also the flag that keeps the list from showing the
  /// same certificate twice once the server's copy arrives.
  final bool isLocal;

  /// The same summary, marked as this device's own copy.
  CertificateSummary asLocal() => CertificateSummary(
    id: id,
    certificateNo: certificateNo,
    certType: certType,
    syncStatus: syncStatus,
    createdAt: createdAt,
    certName: certName,
    templateName: templateName,
    equipmentType: equipmentType,
    patientSafe: patientSafe,
    templateNameId: templateNameId,
    pmTaskDescription: pmTaskDescription,
    isLocal: true,
  );

  /// Resolved display name for the template.
  /// Null when no name can be determined — callers should fall back to
  /// [equipmentType] or another contextual label.
  String? get resolvedTemplateName {
    if (certName != null && certName!.isNotEmpty) return certName!;
    if (templateName != null && templateName!.isNotEmpty) return templateName!;
    return null;
  }

  /// Title shown in lists and headers — template name when available,
  /// otherwise a generic cert-type label for historical certs.
  String get displayTitle => resolvedTemplateName ?? '$typeLabel Certificate';

  String get complianceLabel {
    switch (patientSafe) {
      case 1:
        return 'Compliant';
      case 0:
        return 'Non-Compliant';
      case 2:
        return 'Incomplete';
      default:
        return '';
    }
  }

  Color get complianceColor {
    switch (patientSafe) {
      case 1:
        return const Color(0xFF2E7D32);
      case 0:
        return const Color(0xFFC62828);
      case 2:
        return const Color(0xFFF57F17);
      default:
        return const Color(0xFF8A9BAE);
    }
  }

  String get typeLabel {
    switch (certType) {
      case 2:
        return 'QA';
      case 3:
        return 'CS';
      default:
        return 'TEST';
    }
  }

  bool get isPending => syncStatus == 'pending';

  factory CertificateSummary.fromMap(Map<String, dynamic> m) =>
      CertificateSummary(
        id: m['id'] as int,
        certificateNo: m['certificate_no'] as int?,
        certType: m['cert_type'] as int? ?? 1,
        syncStatus: m['sync_status'] as String? ?? 'pending',
        createdAt: DateTime.parse(m['created_at'] as String),
        certName: m['cert_name'] as String?,
        templateName: m['template_name'] as String?,
        equipmentType: m['equipment_type'] as String?,
        patientSafe: m['patient_safe'] as int?,
        templateNameId: m['template_name_id'] as int?,
        pmTaskDescription: m['pm_task_description'] as String?,
      );

  /// A copy with the facility attached, once the asset lookup has run.
  CertificateSummary copyWith({String? hospital, String? equipmentType}) =>
      CertificateSummary(
        id: id,
        certificateNo: certificateNo,
        certType: certType,
        syncStatus: syncStatus,
        createdAt: createdAt,
        certName: certName,
        templateName: templateName,
        equipmentType: equipmentType ?? this.equipmentType,
        patientSafe: patientSafe,
        templateNameId: templateNameId,
        pmTaskDescription: pmTaskDescription,
        hospital: hospital ?? this.hospital,
        mobileId: mobileId,
        isLocal: isLocal,
      );
}
