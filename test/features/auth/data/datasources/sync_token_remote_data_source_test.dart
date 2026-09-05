import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stat_trac_technical/features/auth/data/datasources/sync_token_remote_data_source.dart';

class MockDio extends Mock implements Dio {}

Response<T> _response<T>(T data, String path) => Response<T>(
  data: data,
  statusCode: 200,
  requestOptions: RequestOptions(path: path),
);

void main() {
  late MockDio dio;
  late SyncTokenRemoteDataSourceImpl source;

  setUp(() {
    dio = MockDio();
    source = SyncTokenRemoteDataSourceImpl(dio);
    registerFallbackValue(Options());
  });

  group('fetchSyncCredentials', () {
    test(
      'requests the company-scoped path with the device token as bearer',
      () async {
        when(
          () => dio.get<Map<String, dynamic>>(
            any(),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => _response(const {
            'token': 'sync-jwt',
            'expires': '2026-09-05T13:03:41Z',
            'expires_in': 3599,
            'endpoint': 'https://demo.stattrac.net/sync',
            'user_id': 35,
          }, '/demo/sync/token'),
        );

        final creds = await source.fetchSyncCredentials(
          company: 'demo',
          deviceToken: 'device-token-90d',
        );

        final captured = verify(
          () => dio.get<Map<String, dynamic>>(
            captureAny(),
            options: captureAny(named: 'options'),
          ),
        ).captured;

        expect(captured[0], '/demo/sync/token');
        expect(
          (captured[1] as Options).headers?['Authorization'],
          'Bearer device-token-90d',
        );
        expect(creds.token, 'sync-jwt');
        expect(creds.endpoint, 'https://demo.stattrac.net/sync');
        expect(creds.userId, 35);
      },
    );
  });

  group('fetchDeviceToken', () {
    test(
      'posts form-encoded credentials to the company device token path',
      () async {
        when(
          () => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => _response(const {
            'token': 'device-token-90d',
            'expires': '2026-12-04T10:00:00Z',
            'name': 'Mauritz Britz',
          }, '/demo/device/token'),
        );

        final token = await source.fetchDeviceToken(
          company: 'demo',
          username: 'fritz',
          password: 'secret',
        );

        final captured = verify(
          () => dio.post<Map<String, dynamic>>(
            captureAny(),
            data: captureAny(named: 'data'),
            options: captureAny(named: 'options'),
          ),
        ).captured;

        expect(captured[0], '/demo/device/token');
        expect(captured[1], {'username': 'fritz', 'password': 'secret'});
        expect(
          (captured[2] as Options).contentType,
          Headers.formUrlEncodedContentType,
        );
        expect(token.token, 'device-token-90d');
        expect(token.name, 'Mauritz Britz');
      },
    );
  });
}
