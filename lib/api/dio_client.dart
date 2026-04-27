import 'package:dio/dio.dart';

import '../core/config/app_config.dart';
import 'auth_interceptor.dart';

Dio buildDioClient(AuthInterceptor authInterceptor) {
  return Dio(
    BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: {'Content-Type': 'application/json'},
    ),
  )..interceptors.add(authInterceptor);
}
