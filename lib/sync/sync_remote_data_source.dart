import 'package:dio/dio.dart';

abstract interface class SyncRemoteDataSource {
  /// POST /sync/log — records a sync cycle result in the server AppSyncLog.
  /// Failures are silently swallowed so they never break a sync cycle.
  Future<void> postSyncLog({
    required String entity,
    required int rowCount,
    required String status,
    required String message,
  });
}

class SyncRemoteDataSourceImpl implements SyncRemoteDataSource {
  SyncRemoteDataSourceImpl(this._dio);
  final Dio _dio;

  @override
  Future<void> postSyncLog({
    required String entity,
    required int rowCount,
    required String status,
    required String message,
  }) async {
    try {
      await _dio.post<void>(
        '/sync/log',
        data: {
          'entity': entity,
          'row_count': rowCount,
          'status': status,
          'message': message,
        },
      );
    } catch (_) {
      // Swallow — log failures must never break a sync cycle.
    }
  }
}
