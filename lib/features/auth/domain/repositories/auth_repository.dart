import '../entities/auth_token.dart';
import '../entities/user.dart';

abstract interface class AuthRepository {
  /// Authenticates with the Horse REST API and persists tokens locally.
  Future<AuthToken> login(String username, String password, String dbName);

  /// Clears local tokens and invalidates the session server-side.
  Future<void> logout();

  /// Exchanges the stored refresh token for a new access token.
  Future<AuthToken> refreshToken(String refreshToken);

  /// Returns the currently authenticated user from local storage, or null.
  Future<User?> getCurrentUser();
}
