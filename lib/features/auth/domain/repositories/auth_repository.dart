import '../entities/auth_token.dart';
import '../entities/user.dart';

abstract interface class AuthRepository {
  /// Signs in against the Go application and persists the device token.
  ///
  /// [company] is the tenant key. Returns the authenticated user, whose id
  /// comes from the sync-token exchange — the device token endpoint does not
  /// return one.
  Future<User> login(String username, String password, String company);

  /// Clears local tokens and invalidates the session server-side.
  Future<void> logout();

  /// Retained for the Horse-era Dio interceptor, which is retired with the
  /// remote data sources. Device tokens are not refreshed.
  Future<AuthToken> refreshToken(String refreshToken);

  /// Returns the currently authenticated user from local storage, or null.
  Future<User?> getCurrentUser();
}
