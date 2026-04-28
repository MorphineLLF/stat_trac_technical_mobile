import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/config/app_config.dart';
import '../../data/datasources/auth_local_data_source.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

part 'auth_providers.g.dart';

// ── Infrastructure ───────────────────────────────────────────────────────────

@riverpod
FlutterSecureStorage secureStorage(Ref ref) {
  return const FlutterSecureStorage();
}

@riverpod
AuthLocalDataSource authLocalDataSource(Ref ref) {
  return AuthLocalDataSourceImpl(ref.watch(secureStorageProvider));
}

@riverpod
AuthRemoteDataSource authRemoteDataSource(Ref ref) {
  // Auth endpoints (login, refresh) don't need the JWT interceptor.
  return AuthRemoteDataSourceImpl(Dio(BaseOptions(
    baseUrl: AppConfig.baseUrl,
    connectTimeout: AppConfig.connectTimeout,
    receiveTimeout: AppConfig.receiveTimeout,
    headers: {'Content-Type': 'application/json'},
  )));
}

@riverpod
AuthRepository authRepository(Ref ref) {
  return AuthRepositoryImpl(
    remote: ref.watch(authRemoteDataSourceProvider),
    local: ref.watch(authLocalDataSourceProvider),
  );
}

// ── Notifier ─────────────────────────────────────────────────────────────────

@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  AuthState build() {
    _checkStoredToken();
    return const AuthInitial();
  }

  Future<void> _checkStoredToken() async {
    final repo = ref.read(authRepositoryProvider);
    final user = await repo.getCurrentUser();
    state = user != null ? AuthAuthenticated(user) : const AuthUnauthenticated();
  }

  Future<void> login(String username, String password) async {
    state = const AuthInitial();
    try {
      await ref.read(authRepositoryProvider).login(username, password);
      final user = await ref.read(authRepositoryProvider).getCurrentUser();
      state = AuthAuthenticated(user ?? _unknownUser);
    } on Exception catch (e) {
      state = AuthUnauthenticated(errorMessage: _friendlyError(e));
    }
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AuthUnauthenticated();
  }
}

// Placeholder until /auth/me endpoint is available (§6 of spec).
const _unknownUser = User(
  id: 0,
  name: '',
  email: '',
  role: UserRole.technician,
  technicianCode: '',
);

String _friendlyError(Exception e) {
  final msg = e.toString().toLowerCase();
  if (msg.contains('401') || msg.contains('unauthorized')) {
    return 'Invalid username or password.';
  }
  if (msg.contains('socket') || msg.contains('connection')) {
    return 'Cannot reach server. Check your connection.';
  }
  return 'Login failed. Please try again.';
}
