import 'package:flutter/foundation.dart';

@immutable
class TestCertificate {
  const TestCertificate({
    required this.id,
    required this.certType,
    required this.syncStatus,
    required this.createdAt,
    this.serverId,
    this.assetId,
    this.testDate,
    this.templateNameId,
    this.technician,
    this.technicianId,
    this.nextService,
    this.woNumber,
    this.jobcardNo,
    this.docNo,
    this.serviceInterval,
    this.serviceType,
    this.techSignature,
    this.clientSignature,
    this.clientName,
    this.notes,
  });

  final int id;
  final int? serverId;
  final int? assetId;
  final DateTime? testDate;
  final int certType;
  final int? templateNameId;
  final String? technician;
  final int? technicianId;
  final DateTime? nextService;
  final int? woNumber;
  final String? jobcardNo;
  final String? docNo;
  final String? serviceInterval;
  final String? serviceType;
  final List<int>? techSignature;    // PNG bytes
  final List<int>? clientSignature;  // PNG bytes
  final String? clientName;
  final String? notes;
  final String syncStatus;           // 'pending' | 'synced' | 'error'
  final DateTime createdAt;
}
