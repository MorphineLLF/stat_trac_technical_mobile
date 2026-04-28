import '../../domain/entities/auth_token.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required AuthLocalDataSource local,
  })  : _remote = remote,
        _local = local;

  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;

  @override
  Future<AuthToken> login(String username, String password, String dbName) async {
    final result = await _remote.login(username, password, dbName);
    await _local.saveToken(result.token);
    await _local.saveUser(result.user);
    await _local.saveDbName(dbName);
    return result.token;
  }

  @override
  Future<void> logout() async {
    final token = await _local.readToken();
    if (token != null) {
      await _remote.logout(token.accessToken);
    }
    await _local.clearToken();
    await _local.clearUser();
    await _local.clearDbName();
  }

  @override
  Future<AuthToken> refreshToken(String refreshToken) async {
    final newToken = await _remote.refreshToken(refreshToken);
    await _local.saveToken(newToken);
    return newToken;
  }

  @override
  Future<User?> getCurrentUser() async {
    final token = await _local.readToken();
    if (token == null || token.isExpired) return null;
    return _local.readUser();
  }
}
