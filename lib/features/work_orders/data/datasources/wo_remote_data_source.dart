import 'package:dio/dio.dart';

import '../models/work_order_model.dart';

abstract interface class WoRemoteDataSource {
  /// GET /workorders — §6.1
  Future<List<WorkOrderModel>> getWorkOrders({DateTime? since});

  /// GET /workorders/{id} — §6.1
  Future<WorkOrderModel> getWorkOrderById(int id);

  /// POST /workorders — ad-hoc CM creation — §6.1
  Future<WorkOrderModel> createWorkOrder(Map<String, dynamic> body);

  /// POST /workorders/{id}/transition — §6.1
  Future<void> transitionStatus(
    int id,
    String toStatus, {
    String? notes,
    double? gpsLat,
    double? gpsLng,
  });
}

class WoRemoteDataSourceImpl implements WoRemoteDataSource {
  WoRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<WorkOrderModel>> getWorkOrders({DateTime? since}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/workorders',
      queryParameters: {
        if (since != null) 'since': since.toIso8601String(),
      },
    );
    final items = response.data!['data'] as List<dynamic>;
    return items
        .cast<Map<String, dynamic>>()
        .map(WorkOrderModel.fromJson)
        .toList();
  }

  @override
  Future<WorkOrderModel> getWorkOrderById(int id) async {
    final response =
        await _dio.get<Map<String, dynamic>>('/workorders/$id');
    return WorkOrderModel.fromJson(response.data!);
  }

  @override
  Future<WorkOrderModel> createWorkOrder(Map<String, dynamic> body) async {
    final response =
        await _dio.post<Map<String, dynamic>>('/workorders', data: body);
    return WorkOrderModel.fromJson(response.data!);
  }

  @override
  Future<void> transitionStatus(
    int id,
    String toStatus, {
    String? notes,
    double? gpsLat,
    double? gpsLng,
  }) async {
    await _dio.post<void>('/workorders/$id/transition', data: {
      'to_state': toStatus,
      'notes': ?notes,
      'gps_lat': ?gpsLat,
      'gps_lng': ?gpsLng,
    });
  }
}
