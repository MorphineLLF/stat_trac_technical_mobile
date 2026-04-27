import '../../domain/entities/work_order.dart';
import '../../domain/entities/work_order_enums.dart';

class WorkOrderModel extends WorkOrder {
  const WorkOrderModel({
    required super.id,
    required super.woNumber,
    required super.type,
    required super.priority,
    required super.status,
    required super.origin,
    required super.createdAt,
    required super.updatedAt,
    super.slaDueAt,
    super.accountId,
    super.assetId,
    super.reporterUserId,
    super.assignedUserId,
    super.scheduledStart,
    super.acceptedAt,
    super.enRouteAt,
    super.onSiteAt,
    super.startedAt,
    super.completedAt,
    super.reviewedAt,
    super.closedAt,
    super.cancelledAt,
    super.cancelReason,
    super.symptomDescription,
    super.resolutionNarrative,
    super.rootCauseCode,
    super.failureModeCode,
    super.outcome,
    super.billingFlag,
    super.travelKm,
    super.travelMinutes,
    super.labourMinutes,
    super.waitMinutes,
  });

  factory WorkOrderModel.fromMap(Map<String, dynamic> m) {
    return WorkOrderModel(
      id: m['id'] as int,
      woNumber: m['wo_number'] as String,
      type: WoType.fromValue(m['type'] as String),
      priority: WoPriority.fromValue(m['priority'] as String),
      status: WoStatus.fromValue(m['status'] as String),
      origin: WoOrigin.fromValue(m['origin'] as String),
      createdAt: DateTime.parse(m['created_at'] as String),
      updatedAt: DateTime.parse(m['updated_at'] as String),
      slaDueAt: _dt(m['sla_due_at']),
      accountId: m['account_id'] as int?,
      assetId: m['asset_id'] as int?,
      reporterUserId: m['reporter_user_id'] as int?,
      assignedUserId: m['assigned_user_id'] as int?,
      scheduledStart: _dt(m['scheduled_start']),
      acceptedAt: _dt(m['accepted_at']),
      enRouteAt: _dt(m['en_route_at']),
      onSiteAt: _dt(m['on_site_at']),
      startedAt: _dt(m['started_at']),
      completedAt: _dt(m['completed_at']),
      reviewedAt: _dt(m['reviewed_at']),
      closedAt: _dt(m['closed_at']),
      cancelledAt: _dt(m['cancelled_at']),
      cancelReason: m['cancel_reason'] as String?,
      symptomDescription: m['symptom_description'] as String?,
      resolutionNarrative: m['resolution_narrative'] as String?,
      rootCauseCode: m['root_cause_code'] as String?,
      failureModeCode: m['failure_mode_code'] as String?,
      outcome: m['outcome'] != null
          ? WoOutcome.fromValue(m['outcome'] as String)
          : null,
      billingFlag: m['billing_flag'] != null
          ? BillingFlag.fromValue(m['billing_flag'] as String)
          : null,
      travelKm: m['travel_km'] as double?,
      travelMinutes: m['travel_minutes'] as int?,
      labourMinutes: m['labour_minutes'] as int?,
      waitMinutes: m['wait_minutes'] as int?,
    );
  }

  factory WorkOrderModel.fromJson(Map<String, dynamic> j) =>
      WorkOrderModel.fromMap({
        ...j,
        // API uses snake_case matching SQLite columns — no field remapping needed.
      });

  Map<String, dynamic> toMap() => {
        'id': id,
        'wo_number': woNumber,
        'type': type.value,
        'priority': priority.value,
        'status': status.value,
        'origin': origin.value,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'sla_due_at': slaDueAt?.toIso8601String(),
        'account_id': accountId,
        'asset_id': assetId,
        'reporter_user_id': reporterUserId,
        'assigned_user_id': assignedUserId,
        'scheduled_start': scheduledStart?.toIso8601String(),
        'accepted_at': acceptedAt?.toIso8601String(),
        'en_route_at': enRouteAt?.toIso8601String(),
        'on_site_at': onSiteAt?.toIso8601String(),
        'started_at': startedAt?.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'reviewed_at': reviewedAt?.toIso8601String(),
        'closed_at': closedAt?.toIso8601String(),
        'cancelled_at': cancelledAt?.toIso8601String(),
        'cancel_reason': cancelReason,
        'symptom_description': symptomDescription,
        'resolution_narrative': resolutionNarrative,
        'root_cause_code': rootCauseCode,
        'failure_mode_code': failureModeCode,
        'outcome': outcome?.value,
        'billing_flag': billingFlag?.value,
        'travel_km': travelKm,
        'travel_minutes': travelMinutes,
        'labour_minutes': labourMinutes,
        'wait_minutes': waitMinutes,
      };

  static DateTime? _dt(dynamic v) =>
      v == null ? null : DateTime.parse(v as String);
}
