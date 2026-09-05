import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/auth_token_model.dart';
import '../models/device_token_model.dart';
import '../models/user_model.dart';

abstract interface class AuthLocalDataSource {
  Future<void> saveToken(AuthTokenModel token);
  Future<AuthTokenModel?> readToken();
  Future<void> clearToken();
  Future<void> saveUser(UserModel user);
  Future<UserModel?> readUser();
  Future<void> clearUser();
  Future<void> saveDbName(String dbName);
  Future<String?> readDbName();
  Future<void> clearDbName();

  /// The ninety-day device token from `POST /{company}/device/token`.
  Future<void> saveDeviceToken(DeviceTokenModel token);
  Future<DeviceTokenModel?> readDeviceToken();
  Future<void> clearDeviceToken();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  AuthLocalDataSourceImpl(this._storage);

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  static const _dbNameKey = 'db_name';
  static const _deviceTokenKey = 'device_token';

  @override
  Future<void> saveToken(AuthTokenModel token) async {
    await _storage.write(key: _tokenKey, value: jsonEncode(token.toJson()));
  }

  @override
  Future<AuthTokenModel?> readToken() async {
    final raw = await _storage.read(key: _tokenKey);
    if (raw == null) return null;
    return AuthTokenModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
  }

  @override
  Future<void> saveUser(UserModel user) async {
    await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
  }

  @override
  Future<UserModel?> readUser() async {
    final raw = await _storage.read(key: _userKey);
    if (raw == null) return null;
    return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> clearUser() async {
    await _storage.delete(key: _userKey);
  }

  @override
  Future<void> saveDbName(String dbName) async {
    await _storage.write(key: _dbNameKey, value: dbName);
  }

  @override
  Future<String?> readDbName() async {
    return _storage.read(key: _dbNameKey);
  }

  @override
  Future<void> clearDbName() async {
    await _storage.delete(key: _dbNameKey);
  }

  @override
  Future<void> saveDeviceToken(DeviceTokenModel token) async {
    await _storage.write(
      key: _deviceTokenKey,
      value: jsonEncode(token.toJson()),
    );
  }

  @override
  Future<DeviceTokenModel?> readDeviceToken() async {
    final raw = await _storage.read(key: _deviceTokenKey);
    if (raw == null) return null;
    return DeviceTokenModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> clearDeviceToken() async {
    await _storage.delete(key: _deviceTokenKey);
  }
}
