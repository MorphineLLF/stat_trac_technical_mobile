import '../../domain/entities/auth_token.dart';
import '../../domain/entities/user.dart';
import '../../domain/phone_registered_elsewhere.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/sync_token_remote_data_source.dart';
import '../models/phone_owner.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required SyncTokenRemoteDataSource syncTokens,
    required AuthLocalDataSource local,
  }) : _syncTokens = syncTokens,
       _local = local;

  final SyncTokenRemoteDataSource _syncTokens;
  final AuthLocalDataSource _local;

  /// Signs in against the Go application.
  ///
  /// Two calls, deliberately: the device token proves the credentials and is
  /// what gets stored, and the sync-token exchange is what supplies the user
  /// id — the device token endpoint does not return one. Doing both here also
  /// proves the whole sync auth chain at sign-in rather than at first sync.
  ///
  /// [company] is the tenant key, carried by the field the login screen still
  /// labels "DB Name".
  @override
  Future<User> login(String username, String password, String company) async {
    final deviceToken = await _syncTokens.fetchDeviceToken(
      company: company,
      username: username,
      password: password,
    );
    final credentials = await _syncTokens.fetchSyncCredentials(
      company: company,
      deviceToken: deviceToken.token,
    );

    // One technician per phone: the first to sign in. Checked against the
    // user id the server authenticated, before anything is stored, so a
    // refused sign-in leaves no token and no user behind.
    final owner = await _local.readPhoneOwner();
    if (owner != null && owner.userId != credentials.userId) {
      throw PhoneRegisteredElsewhere(owner.name);
    }

    final user = UserModel(
      id: credentials.userId,
      name: deviceToken.name ?? '',
      email: '',
      role: UserRole.technician,
      technicianCode: '',
    );

    await _local.saveDeviceToken(deviceToken);
    await _local.saveUser(user);
    await _local.saveDbName(company);
    if (owner == null) {
      await _local.savePhoneOwner(PhoneOwner(userId: user.id, name: user.name));
    }
    return user;
  }

  /// Clears the session locally.
  ///
  /// There is no server-side revoke call for device tokens, so this is a local
  /// clear only. The token remains valid until it expires.
  ///
  /// **The company is kept.** It is saved only after a login succeeds, so it
  /// is always one that worked, and a technician who has signed in on this
  /// phone is not asked for it again — the user's rule, 2026-09-30.
  @override
  Future<void> logout() async {
    await _local.clearDeviceToken();
    await _local.clearUser();
  }

  @override
  Future<AuthToken> refreshToken(String refreshToken) {
    // Device tokens are not refreshed — they last ninety days and are then
    // re-issued by signing in again. A short sync token is renewed by calling
    // the sync-token endpoint with the device token, which is the sync
    // client's concern, not the auth repository's.
    throw UnsupportedError(
      'Device tokens are not refreshed; sign in again when one expires.',
    );
  }

  @override
  Future<User?> getCurrentUser() async {
    final token = await _local.readDeviceToken();
    if (token == null || !DateTime.now().toUtc().isBefore(token.expiresAt)) {
      return null;
    }
    final user = await _local.readUser();
    // A phone updated while signed in has no owner yet: the technician
    // signed in on it becomes it, rather than whoever tries next.
    if (user != null && await _local.readPhoneOwner() == null) {
      await _local.savePhoneOwner(PhoneOwner(userId: user.id, name: user.name));
    }
    return user;
  }
}
