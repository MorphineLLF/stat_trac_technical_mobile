import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../database/database_helper.dart';
import '../../../assets/data/datasources/asset_local_data_source.dart';
import '../../data/datasources/wo_local_data_source.dart';
import '../../data/datasources/wo_remote_data_source.dart';
import '../../data/repositories/work_order_repository_impl.dart';
import '../../domain/entities/work_order.dart';
import '../../domain/entities/work_order_enums.dart';
import '../../domain/repositories/work_order_repository.dart';

part 'work_order_providers.g.dart';

// ── Infrastructure ────────────────────────────────────────────────────────────

@riverpod
DatabaseHelper databaseHelper(Ref ref) => DatabaseHelper.instance;

@riverpod
WoLocalDataSource woLocalDataSource(Ref ref) =>
    WoLocalDataSourceImpl(ref.watch(databaseHelperProvider));

@riverpod
WoRemoteDataSource woRemoteDataSource(Ref ref) =>
    WoRemoteDataSourceImpl(Dio());

@riverpod
WorkOrderRepository workOrderRepository(Ref ref) => WorkOrderRepositoryImpl(
      local: ref.watch(woLocalDataSourceProvider),
      remote: ref.watch(woRemoteDataSourceProvider),
    );

@riverpod
AssetLocalDataSource assetLocalDataSource(Ref ref) =>
    AssetLocalDataSourceImpl(ref.watch(databaseHelperProvider));

// ── Today's work orders ───────────────────────────────────────────────────────

@riverpod
class TodaysWorkOrders extends _$TodaysWorkOrders {
  @override
  Future<List<WorkOrder>> build() =>
      ref.watch(workOrderRepositoryProvider).getTodaysWorkOrders();

  Future<void> refresh() {
    ref.invalidateSelf();
    return future;
  }
}

// ── WO detail ────────────────────────────────────────────────────────────────

@riverpod
Future<WorkOrder?> workOrderDetail(Ref ref, int id) =>
    ref.watch(workOrderRepositoryProvider).getWorkOrderById(id);

@riverpod
Future<List<WorkOrderStatusHistory>> workOrderStatusHistory(
    Ref ref, int workOrderId) async {
  final local = ref.watch(woLocalDataSourceProvider);
  return local.getStatusHistory(workOrderId);
}

// ── Status transition ─────────────────────────────────────────────────────────

@riverpod
class WorkOrderActions extends _$WorkOrderActions {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> transition(
    int workOrderId,
    WoStatus toStatus, {
    String? notes,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(workOrderRepositoryProvider).transitionStatus(
            workOrderId,
            toStatus,
            notes: notes,
          );
      ref.invalidate(workOrderDetailProvider(workOrderId));
      ref.invalidate(workOrderStatusHistoryProvider(workOrderId));
      ref.invalidate(todaysWorkOrdersProvider);
    });
  }

  Future<WorkOrder?> createWorkOrder({
    required int assetId,
    required WoType type,
    required WoPriority priority,
    required String symptomDescription,
  }) async {
    state = const AsyncLoading();
    WorkOrder? created;
    state = await AsyncValue.guard(() async {
      final now = DateTime.now();
      final woNumber =
          'WO-${now.year}-${now.month.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch % 100000}';
      // CM created by technician goes straight to in_progress (business rule #9).
      // All other types start as created pending dispatcher scheduling.
      final initialStatus =
          type == WoType.cm ? WoStatus.inProgress : WoStatus.created;
      final wo = WorkOrder(
        id: 0,
        woNumber: woNumber,
        type: type,
        priority: priority,
        status: initialStatus,
        origin: WoOrigin.technician,
        assetId: assetId,
        symptomDescription: symptomDescription,
        startedAt: type == WoType.cm ? now : null,
        createdAt: now,
        updatedAt: now,
      );
      created = await ref.read(workOrderRepositoryProvider).createWorkOrder(wo);
      ref.invalidate(todaysWorkOrdersProvider);
    });
    return created;
  }
}
