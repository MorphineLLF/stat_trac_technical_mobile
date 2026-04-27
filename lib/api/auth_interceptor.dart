import 'package:dio/dio.dart';

import '../features/auth/data/datasources/auth_local_data_source.dart';
import '../features/auth/data/datasources/auth_remote_data_source.dart';

class AuthInterceptor extends QueuedInterceptorsWrapper {
  AuthInterceptor({
    required AuthLocalDataSource local,
    required AuthRemoteDataSource remote,
  })  : _local = local,
        _remote = remote;

  final AuthLocalDataSource _local;
  final AuthRemoteDataSource _remote;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _local.readToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer ${token.accessToken}';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    final stored = await _local.readToken();
    if (stored == null) return handler.next(err);

    try {
      final newToken = await _remote.refreshToken(stored.refreshToken);
      await _local.saveToken(newToken);

      // Retry original request with new token.
      final opts = err.requestOptions
        ..headers['Authorization'] = 'Bearer ${newToken.accessToken}';
      final response = await Dio().fetch<dynamic>(opts);
      return handler.resolve(response);
    } on DioException catch (_) {
      await _local.clearToken();
      return handler.next(err);
    }
  }
}
