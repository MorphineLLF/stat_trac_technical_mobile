import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/config/app_config.dart';
import '../../data/datasources/auth_local_data_source.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/datasources/sync_token_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';
import 'login_error.dart';

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
  return AuthRemoteDataSourceImpl(
    Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        headers: {'Content-Type': 'application/json'},
      ),
    ),
  );
}

/// The Go application's token endpoints. No interceptor: sign-in is what
/// produces the token, so it cannot require one.
@riverpod
SyncTokenRemoteDataSource syncTokenRemoteDataSource(Ref ref) {
  return SyncTokenRemoteDataSourceImpl(
    Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
      ),
    ),
  );
}

@riverpod
AuthRepository authRepository(Ref ref) {
  return AuthRepositoryImpl(
    syncTokens: ref.watch(syncTokenRemoteDataSourceProvider),
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
    state = user != null
        ? AuthAuthenticated(user)
        : const AuthUnauthenticated();
  }

  Future<void> login(String username, String password, String company) async {
    state = const AuthInitial();
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .login(username, password, company);
      state = AuthAuthenticated(user);
    } on Exception catch (e) {
      state = AuthUnauthenticated(errorMessage: loginErrorMessage(e));
    }
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AuthUnauthenticated();
  }
}
