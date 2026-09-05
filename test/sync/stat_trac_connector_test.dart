import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stat_trac_technical/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:stat_trac_technical/features/auth/data/datasources/sync_token_remote_data_source.dart';
import 'package:stat_trac_technical/features/auth/data/models/device_token_model.dart';
import 'package:stat_trac_technical/features/auth/data/models/sync_credentials_model.dart';
import 'package:stat_trac_technical/sync/stat_trac_connector.dart';

class MockLocal extends Mock implements AuthLocalDataSource {}

class MockSyncTokens extends Mock implements SyncTokenRemoteDataSource {}

DeviceTokenModel _validDeviceToken() => DeviceTokenModel(
  token: 'device-token-90d',
  expiresAt: DateTime.now().toUtc().add(const Duration(days: 60)),
  name: 'Mauritz Britz',
);

void main() {
  late MockLocal local;
  late MockSyncTokens syncTokens;
  late StatTracConnector connector;

  setUp(() {
    local = MockLocal();
    syncTokens = MockSyncTokens();
    connector = StatTracConnector(local: local, syncTokens: syncTokens);
  });

  group('fetchCredentials', () {
    test('returns null and makes no network call when not signed in', () async {
      when(() => local.readDeviceToken()).thenAnswer((_) async => null);
      when(() => local.readDbName()).thenAnswer((_) async => 'demo');

      expect(await connector.fetchCredentials(), isNull);

      verifyNever(
        () => syncTokens.fetchSyncCredentials(
          company: any(named: 'company'),
          deviceToken: any(named: 'deviceToken'),
        ),
      );
    });

    test('returns null when the device token has expired', () async {
      when(() => local.readDeviceToken()).thenAnswer(
        (_) async => DeviceTokenModel(
          token: 'stale',
          expiresAt: DateTime.utc(2020),
          name: 'Old',
        ),
      );
      when(() => local.readDbName()).thenAnswer((_) async => 'demo');

      expect(await connector.fetchCredentials(), isNull);
    });

    test('returns null when no company has been stored', () async {
      when(() => local.readDeviceToken()).thenAnswer(
        (_) async => _validDeviceToken(),
      );
      when(() => local.readDbName()).thenAnswer((_) async => null);

      expect(await connector.fetchCredentials(), isNull);
    });

    test('exchanges the device token and returns the endpoint it was '
        'given', () async {
      when(() => local.readDeviceToken()).thenAnswer(
        (_) async => _validDeviceToken(),
      );
      when(() => local.readDbName()).thenAnswer((_) async => 'demo');
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
          userId: 35,
        ),
      );

      final creds = await connector.fetchCredentials();

      expect(creds, isNotNull);
      expect(creds!.endpoint, 'https://demo.stattrac.net/sync');
      expect(creds.token, 'sync-jwt');
      // PowerSync carries the subject as a string, and the sync rules
      // compare it as one — a cast inside a rule is refused.
      expect(creds.userId, '35');
    });

    test('propagates a network failure instead of reporting signed out',
        () async {
      when(() => local.readDeviceToken()).thenAnswer(
        (_) async => _validDeviceToken(),
      );
      when(() => local.readDbName()).thenAnswer((_) async => 'demo');
      when(
        () => syncTokens.fetchSyncCredentials(
          company: any(named: 'company'),
          deviceToken: any(named: 'deviceToken'),
        ),
      ).thenThrow(Exception('connection closed'));

      // Returning null here would tell PowerSync the user is signed out and
      // stop it retrying. A temporary failure must throw.
      await expectLater(
        connector.fetchCredentials(),
        throwsA(isA<Exception>()),
      );
    });
  });
}
