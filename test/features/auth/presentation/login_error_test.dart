import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/features/auth/presentation/providers/login_error.dart';

DioException _http(int status, {Object? body}) => DioException(
  requestOptions: RequestOptions(path: '/demo/device/token'),
  response: Response(
    statusCode: status,
    data: body,
    requestOptions: RequestOptions(path: '/demo/device/token'),
  ),
  type: DioExceptionType.badResponse,
);

void main() {
  group('loginErrorMessage', () {
    // A wrong company is a 404 because the company is a path segment. This
    // is the failure that looked identical to a wrong password before, and
    // it is the one a technician is most likely to hit on first setup.
    test('names the company when the tenant path is not found', () {
      final message = loginErrorMessage(_http(404));

      expect(message, contains('Company'));
      expect(message.toLowerCase(), isNot(contains('password')));
    });

    test('uses the server message on a rejected sign-in', () {
      final message = loginErrorMessage(
        _http(401, body: {'error': 'that username and password do not match'}),
      );

      expect(message, 'That username and password do not match.');
    });

    test('falls back to a readable message when 401 carries no body', () {
      expect(
        loginErrorMessage(_http(401)),
        'Invalid username or password.',
      );
    });

    test('distinguishes an unreachable server from a rejected sign-in', () {
      final message = loginErrorMessage(
        DioException(
          requestOptions: RequestOptions(path: '/demo/device/token'),
          type: DioExceptionType.connectionError,
        ),
      );

      expect(message.toLowerCase(), contains('reach'));
    });

    test('reports a timeout as a timeout', () {
      final message = loginErrorMessage(
        DioException(
          requestOptions: RequestOptions(path: '/demo/device/token'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      expect(message.toLowerCase(), contains('timed out'));
    });

    // A server fault is not the technician's fault, and telling them to
    // check their password would send them down the wrong path.
    test('does not blame credentials for a server error', () {
      final message = loginErrorMessage(_http(500));

      expect(message.toLowerCase(), isNot(contains('password')));
      expect(message.toLowerCase(), contains('server'));
    });

    test('handles a non-Dio exception without leaking its type name', () {
      final message = loginErrorMessage(Exception('something odd'));

      expect(message, isNotEmpty);
      expect(message, isNot(contains('Exception')));
    });
  });
}
