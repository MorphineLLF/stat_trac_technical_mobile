import '../../../../sync/change_log_entry.dart';
import '../../domain/entities/work_order.dart';
import '../../domain/entities/work_order_enums.dart';
import '../../domain/repositories/work_order_repository.dart';
import '../datasources/wo_local_data_source.dart';
import '../datasources/wo_remote_data_source.dart';
import '../models/work_order_model.dart';

class WorkOrderRepositoryImpl implements WorkOrderRepository {
  WorkOrderRepositoryImpl({
    required WoLocalDataSource local,
    required WoRemoteDataSource remote,
  })  : _local = local,
        _remote = remote;

  final WoLocalDataSource _local;
  final WoRemoteDataSource _remote;

  // TODO(phase1): inject current user ID from auth state.
  static const _currentUserId = 0;

  @override
  Future<List<WorkOrder>> getWorkOrders({DateTime? since}) =>
      _local.getAll(since: since);

  @override
  Future<List<WorkOrder>> getTodaysWorkOrders() => _local.getTodays();

  @override
  Future<WorkOrder?> getWorkOrderById(int id) => _local.getById(id);

  @override
  Future<WorkOrder> createWorkOrder(WorkOrder wo) async {
    final model = WorkOrderModel.fromMap(_woToMap(wo));
    final localId = await _local.insert(model);

    await _local.insertChangeLog(
      tableName: 'work_orders',
      rowId: localId,
      operation: ChangeOperation.insert,
      payload: _woToMap(wo),
      userId: _currentUserId,
    );

    await _local.insertStatusHistory(
      workOrderId: localId,
      oldStatus: null,
      newStatus: wo.status,
      changedBy: _currentUserId,
    );

    return (await _local.getById(localId))!;
  }

  @override
  Future<void> transitionStatus(
    int workOrderId,
    WoStatus toStatus, {
    String? notes,
    double? gpsLat,
    double? gpsLng,
  }) async {
    final existing = await _local.getById(workOrderId);
    if (existing == null) return;

    final now = DateTime.now().toIso8601String();
    final updated = WorkOrderModel.fromMap({
      ..._woToMap(existing),
      'id': existing.id,
      'status': toStatus.value,
      'updated_at': now,
      _timestampColumn(toStatus): now,
    });

    await _local.upsert(updated);

    await _local.insertStatusHistory(
      workOrderId: workOrderId,
      oldStatus: existing.status,
      newStatus: toStatus,
      changedBy: _currentUserId,
      notes: notes,
      gpsLat: gpsLat,
      gpsLng: gpsLng,
    );

    await _local.insertChangeLog(
      tableName: 'work_orders',
      rowId: workOrderId,
      operation: ChangeOperation.update,
      payload: {'status': toStatus.value, 'updated_at': now},
      userId: _currentUserId,
    );
  }

  @override
  Future<void> syncFromRemote() async {
    // TODO(phase1): read last-sync cursor from local prefs, call
    // _remote.getWorkOrders(since: cursor), upsert results, advance cursor.
    await _remote.getWorkOrders();
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  static Map<String, dynamic> _woToMap(WorkOrder wo) => {
        'wo_number': wo.woNumber,
        'type': wo.type.value,
        'priority': wo.priority.value,
        'status': wo.status.value,
        'origin': wo.origin.value,
        'created_at': wo.createdAt.toIso8601String(),
        'updated_at': wo.updatedAt.toIso8601String(),
        'sla_due_at': wo.slaDueAt?.toIso8601String(),
        'account_id': wo.accountId,
        'asset_id': wo.assetId,
        'reporter_user_id': wo.reporterUserId,
        'assigned_user_id': wo.assignedUserId,
        'scheduled_start': wo.scheduledStart?.toIso8601String(),
        'accepted_at': wo.acceptedAt?.toIso8601String(),
        'en_route_at': wo.enRouteAt?.toIso8601String(),
        'on_site_at': wo.onSiteAt?.toIso8601String(),
        'started_at': wo.startedAt?.toIso8601String(),
        'completed_at': wo.completedAt?.toIso8601String(),
        'reviewed_at': wo.reviewedAt?.toIso8601String(),
        'closed_at': wo.closedAt?.toIso8601String(),
        'cancelled_at': wo.cancelledAt?.toIso8601String(),
        'cancel_reason': wo.cancelReason,
        'symptom_description': wo.symptomDescription,
        'resolution_narrative': wo.resolutionNarrative,
        'root_cause_code': wo.rootCauseCode,
        'failure_mode_code': wo.failureModeCode,
        'outcome': wo.outcome?.value,
        'billing_flag': wo.billingFlag?.value,
        'travel_km': wo.travelKm,
        'travel_minutes': wo.travelMinutes,
        'labour_minutes': wo.labourMinutes,
        'wait_minutes': wo.waitMinutes,
      };

  static String _timestampColumn(WoStatus s) => switch (s) {
        WoStatus.accepted => 'accepted_at',
        WoStatus.enRoute => 'en_route_at',
        WoStatus.onSite => 'on_site_at',
        WoStatus.inProgress => 'started_at',
        WoStatus.completed => 'completed_at',
        WoStatus.reviewed => 'reviewed_at',
        WoStatus.closed => 'closed_at',
        WoStatus.cancelled => 'cancelled_at',
        _ => 'updated_at',
      };
}
