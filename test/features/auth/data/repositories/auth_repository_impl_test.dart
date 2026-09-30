import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stat_trac_technical/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:stat_trac_technical/features/auth/data/datasources/sync_token_remote_data_source.dart';
import 'package:stat_trac_technical/features/auth/data/models/device_token_model.dart';
import 'package:stat_trac_technical/features/auth/data/models/phone_owner.dart';
import 'package:stat_trac_technical/features/auth/data/models/sync_credentials_model.dart';
import 'package:stat_trac_technical/features/auth/data/models/user_model.dart';
import 'package:stat_trac_technical/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:stat_trac_technical/features/auth/domain/entities/user.dart';
import 'package:stat_trac_technical/features/auth/domain/phone_registered_elsewhere.dart';

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
    registerFallbackValue(const PhoneOwner(userId: 0, name: ''));
    when(() => local.readPhoneOwner()).thenAnswer((_) async => null);
    when(() => local.savePhoneOwner(any())).thenAnswer((_) async {});
  });

  void serverAccepts({required String username, required int userId}) {
    when(
      () => syncTokens.fetchDeviceToken(
        company: 'demo',
        username: username,
        password: 'secret',
      ),
    ).thenAnswer((_) async => _deviceToken);
    when(
      () => syncTokens.fetchSyncCredentials(
        company: 'demo',
        deviceToken: 'device-token-90d',
      ),
    ).thenAnswer(
      (_) async => SyncCredentialsModel(
        token: 'sync-jwt',
        endpoint: 'https://demo.stattrac.net/sync',
        expiresAt: DateTime.utc(2026, 9, 5, 13),
        userId: userId,
      ),
    );
  }

  // A phone belongs to one technician: the first to sign in on it. Only they
  // can sign in afterwards; reinstalling the app releases it. The user's
  // rule, 2026-09-30.
  group('phone registration', () {
    test('the first sign-in registers the phone to that technician', () async {
      serverAccepts(username: 'fritz', userId: 35);

      await repo.login('fritz', 'secret', 'demo');

      final owner =
          verify(() => local.savePhoneOwner(captureAny())).captured.single
              as PhoneOwner;
      expect(owner.userId, 35);
      expect(owner.name, 'Mauritz Britz');
    });

    test('anyone else is refused, and nothing of theirs is kept', () async {
      when(
        () => local.readPhoneOwner(),
      ).thenAnswer((_) async => const PhoneOwner(userId: 31, name: 'Athi'));
      serverAccepts(username: 'fritz', userId: 35);

      await expectLater(
        repo.login('fritz', 'secret', 'demo'),
        throwsA(
          isA<PhoneRegisteredElsewhere>().having(
            (e) => e.ownerName,
            'ownerName',
            'Athi',
          ),
        ),
      );

      verifyNever(() => local.saveDeviceToken(any()));
      verifyNever(() => local.saveUser(any()));
      verifyNever(() => local.savePhoneOwner(any()));
    });

    test('the registered technician still signs in', () async {
      when(() => local.readPhoneOwner()).thenAnswer(
        (_) async => const PhoneOwner(userId: 35, name: 'Mauritz Britz'),
      );
      serverAccepts(username: 'fritz', userId: 35);

      final user = await repo.login('fritz', 'secret', 'demo');

      expect(user.id, 35);
      verify(() => local.saveDeviceToken(_deviceToken)).called(1);
    });

    // A phone updated while signed in has no owner yet: whoever is signed in
    // then becomes it, rather than the next person to try.
    test('a phone already signed in registers its technician', () async {
      when(() => local.readDeviceToken()).thenAnswer((_) async => _deviceToken);
      when(() => local.readUser()).thenAnswer(
        (_) async => const UserModel(
          id: 35,
          name: 'Mauritz Britz',
          email: '',
          role: UserRole.technician,
          technicianCode: '',
        ),
      );

      await repo.getCurrentUser();

      final owner =
          verify(() => local.savePhoneOwner(captureAny())).captured.single
              as PhoneOwner;
      expect(owner.userId, 35);
    });
  });

  group('login', () {
    test('persists the device token, company, and a user carrying the sync '
        'user id', () async {
      when(
        () => syncTokens.fetchDeviceToken(
          company: 'demo',
          username: 'fritz',
          password: 'secret',
        ),
      ).thenAnswer((_) async => _deviceToken);
      when(
        () => syncTokens.fetchSyncCredentials(
          company: 'demo',
          deviceToken: 'device-token-90d',
        ),
      ).thenAnswer((_) async => _syncCreds);

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

    test(
      'does not persist anything when the device token is refused',
      () async {
        when(
          () => syncTokens.fetchDeviceToken(
            company: 'demo',
            username: 'fritz',
            password: 'wrong',
          ),
        ).thenThrow(Exception('401 unauthorized'));

        await expectLater(
          repo.login('fritz', 'wrong', 'demo'),
          throwsA(isA<Exception>()),
        );

        verifyNever(() => local.saveDeviceToken(any()));
        verifyNever(() => local.saveUser(any()));
        verifyNever(() => local.saveDbName(any()));
      },
    );
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
    // The company stays: a technician who has signed in on this phone is
    // not asked for it again after logging out. The user's rule, 2026-09-30.
    test('clears the device token and user, keeps the company', () async {
      await repo.logout();

      verify(() => local.clearDeviceToken()).called(1);
      verify(() => local.clearUser()).called(1);
      verifyNever(() => local.clearDbName());
    });
  });
}
