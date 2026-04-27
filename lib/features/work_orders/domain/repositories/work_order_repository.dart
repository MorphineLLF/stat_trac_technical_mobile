import '../entities/work_order.dart';
import '../entities/work_order_enums.dart';

abstract interface class WorkOrderRepository {
  /// Returns all WOs for the current technician, optionally filtered since
  /// [since] for incremental sync.
  Future<List<WorkOrder>> getWorkOrders({DateTime? since});

  /// Returns WOs with a scheduled start or SLA due date matching today.
  Future<List<WorkOrder>> getTodaysWorkOrders();

  Future<WorkOrder?> getWorkOrderById(int id);

  /// Creates an ad-hoc CM work order (technician-created, §3.3).
  Future<WorkOrder> createWorkOrder(WorkOrder wo);

  /// Writes a status transition to local DB and appends a change-log entry.
  Future<void> transitionStatus(
    int workOrderId,
    WoStatus toStatus, {
    String? notes,
    double? gpsLat,
    double? gpsLng,
  });

  /// Pulls WO updates from the Horse API and reconciles into local DB.
  Future<void> syncFromRemote();
}
