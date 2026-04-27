import 'package:flutter/foundation.dart';

import 'work_order_enums.dart';

@immutable
class WorkOrder {
  const WorkOrder({
    required this.id,
    required this.woNumber,
    required this.type,
    required this.priority,
    required this.status,
    required this.origin,
    required this.createdAt,
    required this.updatedAt,
    this.slaDueAt,
    this.accountId,
    this.assetId,
    this.reporterUserId,
    this.assignedUserId,
    this.scheduledStart,
    this.acceptedAt,
    this.enRouteAt,
    this.onSiteAt,
    this.startedAt,
    this.completedAt,
    this.reviewedAt,
    this.closedAt,
    this.cancelledAt,
    this.cancelReason,
    this.symptomDescription,
    this.resolutionNarrative,
    this.rootCauseCode,
    this.failureModeCode,
    this.outcome,
    this.billingFlag,
    this.travelKm,
    this.travelMinutes,
    this.labourMinutes,
    this.waitMinutes,
  });

  final int id;
  final String woNumber;
  final WoType type;
  final WoPriority priority;
  final WoStatus status;
  final WoOrigin origin;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? slaDueAt;
  final int? accountId;
  final int? assetId;
  final int? reporterUserId;
  final int? assignedUserId;
  final DateTime? scheduledStart;
  final DateTime? acceptedAt;
  final DateTime? enRouteAt;
  final DateTime? onSiteAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? reviewedAt;
  final DateTime? closedAt;
  final DateTime? cancelledAt;
  final String? cancelReason;
  final String? symptomDescription;
  final String? resolutionNarrative;
  final String? rootCauseCode;
  final String? failureModeCode;
  final WoOutcome? outcome;
  final BillingFlag? billingFlag;
  final double? travelKm;
  final int? travelMinutes;
  final int? labourMinutes;
  final int? waitMinutes;

  bool get isOverdue =>
      slaDueAt != null &&
      DateTime.now().isAfter(slaDueAt!) &&
      status != WoStatus.completed &&
      status != WoStatus.closed &&
      status != WoStatus.cancelled;

  Duration? get slaDuration =>
      slaDueAt?.difference(DateTime.now());

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is WorkOrder && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

@immutable
class WorkOrderStatusHistory {
  const WorkOrderStatusHistory({
    required this.id,
    required this.workOrderId,
    required this.newStatus,
    required this.changedBy,
    required this.changedAt,
    this.oldStatus,
    this.notes,
    this.gpsLat,
    this.gpsLng,
  });

  final int id;
  final int workOrderId;
  final WoStatus? oldStatus;
  final WoStatus newStatus;
  final int changedBy;
  final String? notes;
  final double? gpsLat;
  final double? gpsLng;
  final DateTime changedAt;
}
