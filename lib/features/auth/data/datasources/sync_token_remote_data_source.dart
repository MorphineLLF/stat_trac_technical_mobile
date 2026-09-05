import 'package:dio/dio.dart';

import '../models/device_token_model.dart';
import '../models/sync_credentials_model.dart';

/// The Go application's token endpoints.
///
/// Two steps, deliberately separated:
///   1. `POST /{company}/device/token` — ninety-day device token, stored.
///   2. `GET  /{company}/sync/token`   — one-hour PowerSync JWT, held in memory.
///
/// An expiry of the short token is a round trip using the long one, never a
/// password prompt.
abstract interface class SyncTokenRemoteDataSource {
  Future<DeviceTokenModel> fetchDeviceToken({
    required String company,
    required String username,
    required String password,
  });

  Future<SyncCredentialsModel> fetchSyncCredentials({
    required String company,
    required String deviceToken,
  });
}

class SyncTokenRemoteDataSourceImpl implements SyncTokenRemoteDataSource {
  SyncTokenRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<DeviceTokenModel> fetchDeviceToken({
    required String company,
    required String username,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/$company/device/token',
      data: {'username': username, 'password': password},
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    return DeviceTokenModel.fromJson(response.data!);
  }

  @override
  Future<SyncCredentialsModel> fetchSyncCredentials({
    required String company,
    required String deviceToken,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/$company/sync/token',
      options: Options(headers: {'Authorization': 'Bearer $deviceToken'}),
    );
    return SyncCredentialsModel.fromJson(response.data!);
  }
}
