import 'package:flutter/foundation.dart';

enum CertType { test, qa, commission }

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
      case CertType.test:
        return 1;
    }
  }
}
