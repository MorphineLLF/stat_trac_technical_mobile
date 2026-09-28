import 'package:flutter/foundation.dart';

// TestTemplateType: 1 Test, 2 QA, 3 Commission, 4 Decontamination. The
// column's pg_description lists only three; the data and the Go side have four.
enum CertType { test, qa, commission, decontamination }

@immutable
class TestTemplateName {
  const TestTemplateName({
    required this.id,
    required this.certType,
    this.templateName,
    this.certName,
    this.customerSigRequired = false,
    this.editDate = false,
    this.nextService = false,
    this.testEquipQty = 0,
    this.docNo,
    this.note,
    this.lastSyncedAt,
  });

  final int id;
  final CertType certType;
  final String? templateName;
  final String? certName;
  final bool customerSigRequired;
  final bool editDate;
  final bool nextService;
  final int testEquipQty;
  final String? docNo;
  final String? note;
  final DateTime? lastSyncedAt;

  String get displayName => certName ?? templateName ?? 'Template $id';

  static CertType typeFromInt(int? v) {
    switch (v) {
      case 2:
        return CertType.qa;
      case 3:
        return CertType.commission;
      case 4:
        return CertType.decontamination;
      default:
        return CertType.test;
    }
  }

  static int typeToInt(CertType t) {
    switch (t) {
      case CertType.qa:
        return 2;
      case CertType.commission:
        return 3;
      case CertType.decontamination:
        return 4;
      case CertType.test:
        return 1;
    }
  }
}
