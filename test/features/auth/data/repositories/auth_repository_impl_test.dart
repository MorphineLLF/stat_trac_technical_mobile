import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stat_trac_technical/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:stat_trac_technical/features/auth/data/datasources/sync_token_remote_data_source.dart';
import 'package:stat_trac_technical/features/auth/data/models/device_token_model.dart';
import 'package:stat_trac_technical/features/auth/data/models/sync_credentials_model.dart';
import 'package:stat_trac_technical/features/auth/data/models/user_model.dart';
import 'package:stat_trac_technical/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:stat_trac_technical/features/auth/domain/entities/user.dart';

class MockLocal extends Mock implements AuthLocalDataSource {}

class MockSyncTokens extends Mock implements SyncTokenRemoteDataSource {}

final _deviceToken = DeviceTokenModel(
  token: 'device-token-90d',
  expiresAt: DateTime.utc(2026, 12, 4),
  name: 'Mauritz Britz',
);

final _syncCreds = SyncCredentialsModel(
  token: 'sync-jwt',
  endpoint: 'https://demo.stattrac.net/sync',
  expiresAt: DateTime.utc(2026, 9, 5, 13),
  userId: 35,
);

void main() {
  late MockLocal local;
  late MockSyncTokens syncTokens;
  late AuthRepositoryImpl repo;

  setUp(() {
    local = MockLocal();
    syncTokens = MockSyncTokens();
    repo = AuthRepositoryImpl(syncTokens: syncTokens, local: local);

    registerFallbackValue(_deviceToken);
    registerFallbackValue(
      const UserModel(
        id: 0,
        name: '',
        email: '',
        role: UserRole.technician,
        technicianCode: '',
      ),
    );

    when(() => local.saveDeviceToken(any())).thenAnswer((_) async {});
    when(() => local.saveUser(any())).thenAnswer((_) async {});
    when(() => local.saveDbName(any())).thenAnswer((_) async {});
    when(() => local.clearDeviceToken()).thenAnswer((_) async {});
    when(() => local.clearUser()).thenAnswer((_) async {});
    when(() => local.clearDbName()).thenAnswer((_) async {});
  });

  group('login', () {
    test('persists the device token, company, and a user carrying the sync '
        'user id', () async {
      when(() => syncTokens.fetchDeviceToken(
            company: 'demo',
            username: 'fritz',
            password: 'secret',
          )).thenAnswer((_) async => _deviceToken);
      when(() => syncTokens.fetchSyncCredentials(
            company: 'demo',
            deviceToken: 'device-token-90d',
          )).thenAnswer((_) async => _syncCreds);

      final user = await repo.login('fritz', 'secret', 'demo');

      // The device token endpoint returns no user id; the sync token
      // exchange is what supplies it.
      expect(user.id, 35);
      expect(user.name, 'Mauritz Britz');

      verify(() => local.saveDeviceToken(_deviceToken)).called(1);
      verify(() => local.saveDbName('demo')).called(1);

      final saved = verify(() => local.saveUser(captureAny())).captured.single;
      expect((saved as UserModel).id, 35);
    });

    test('does not persist anything when the device token is refused',
        () async {
      when(() => syncTokens.fetchDeviceToken(
            company: 'demo',
            username: 'fritz',
            password: 'wrong',
          )).thenThrow(Exception('401 unauthorized'));

      await expectLater(
        repo.login('fritz', 'wrong', 'demo'),
        throwsA(isA<Exception>()),
      );

      verifyNever(() => local.saveDeviceToken(any()));
      verifyNever(() => local.saveUser(any()));
      verifyNever(() => local.saveDbName(any()));
    });
  });

  group('getCurrentUser', () {
    test('returns null once the device token has expired', () async {
      when(() => local.readDeviceToken()).thenAnswer(
        (_) async => DeviceTokenModel(
          token: 'old',
          expiresAt: DateTime.utc(2020),
          name: 'Stale',
        ),
      );

      expect(await repo.getCurrentUser(), isNull);
      verifyNever(() => local.readUser());
    });
  });

  group('logout', () {
    test('clears the device token, user and company', () async {
      await repo.logout();

      verify(() => local.clearDeviceToken()).called(1);
      verify(() => local.clearUser()).called(1);
      verify(() => local.clearDbName()).called(1);
    });
  });
}
