import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/config/app_config.dart';
import '../models/auth_token_model.dart';
import '../models/user_model.dart';

abstract interface class AuthRemoteDataSource {
  Future<({AuthTokenModel token, UserModel user})> login(
    String username,
    String password,
  );

  Future<void> logout(String accessToken);

  Future<AuthTokenModel> refreshToken(String refreshToken);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<({AuthTokenModel token, UserModel user})> login(
    String username,
    String password,
  ) async {
    final info = await PackageInfo.fromPlatform();
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {
        'username': username,
        'password': password,
        'db': AppConfig.dbName,
        'app_version': info.version,
        'device_os': 'Android',
      },
    );
    final body = response.data!;
    return (
      token: AuthTokenModel.fromJson(body['token'] as Map<String, dynamic>),
      user: UserModel.fromJson(body['user'] as Map<String, dynamic>),
    );
  }

  @override
  Future<void> logout(String accessToken) async {
    await _dio.post<void>(
      '/auth/logout',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
  }

  @override
  Future<AuthTokenModel> refreshToken(String refreshToken) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {'refresh_token': refreshToken},
    );
    return AuthTokenModel.fromJson(response.data!);
  }
}
