import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stat_trac_technical/sync/upload/certificate_upload.dart';
import 'package:stat_trac_technical/sync/upload/sync_upload_client.dart';
import 'package:stat_trac_technical/sync/upload/sync_upload_result.dart';

class MockDio extends Mock implements Dio {}

CertificateUpload _upload() => CertificateUpload(
  mobileId: 'cert-uuid',
  certificate: const {'TestAssetID': 9304},
  lines: const [
    CertificateLineUpload(mobileId: 'line-0', data: {'TestPass': true}),
  ],
);

Response<Map<String, Object?>> _resp(int status, Map<String, Object?> body) =>
    Response(
      statusCode: status,
      data: body,
      requestOptions: RequestOptions(path: '/demo/sync/upload'),
    );

void main() {
  late MockDio dio;
  late SyncUploadClient client;

  setUp(() {
    dio = MockDio();
    client = SyncUploadClient(dio);
    registerFallbackValue(Options());
  });

  void stub(Response<Map<String, Object?>> r) {
    when(
      () => dio.post<Map<String, Object?>>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => r);
  }

  test('posts to the company-scoped path with the device token as bearer',
      () async {
    stub(_resp(200, const {'applied': 2, 'assigned': {'cert-uuid': 5031}}));

    await client.upload(
      company: 'demo',
      deviceToken: 'device-token-90d',
      upload: _upload(),
    );

    final captured = verify(
      () => dio.post<Map<String, Object?>>(
        captureAny(),
        data: captureAny(named: 'data'),
        options: captureAny(named: 'options'),
      ),
    ).captured;

    expect(captured[0], '/demo/sync/upload');
    // A cookie gets a 403 from the CSRF guard; this route wants a Bearer.
    expect(
      (captured[2] as Options).headers?['Authorization'],
      'Bearer device-token-90d',
    );

    final ops = (captured[1] as Map)['ops']! as List;
    expect(ops, hasLength(2));
  });

  test('returns the applied result with its assigned keys', () async {
    stub(_resp(200, const {
      'applied': 2,
      'assigned': {'cert-uuid': 5031, 'line-0': 90210},
      'issued': ['cert-uuid'],
    }));

    final r = await client.upload(
      company: 'demo',
      deviceToken: 't',
      upload: _upload(),
    );

    expect((r as UploadApplied).assigned['cert-uuid'], 5031);
    expect(r.issued, ['cert-uuid']);
  });

  // The op count was checked before sending and the body size was not, though
  // the cap has been sitting in SyncUploadBatchLimits.bodyBytes the whole time.
  // A certificate with many readings and two signature PNGs in one batch is
  // exactly the shape that finds a megabyte, and the answer would be a 413 —
  // which is permanent. Better to refuse it here than to spend a round trip
  // from a device on one bar of signal to be told the same thing.
  test('refuses a body over the 1 MB cap without spending a round trip',
      () async {
    final fat = CertificateUpload(
      mobileId: 'cert-uuid',
      certificate: const {'TestAssetID': 9304},
      lines: [
        for (var i = 0; i < 20; i++)
          CertificateLineUpload(
            mobileId: 'line-$i',
            data: {'TestNote': 'x' * 60000},
          ),
      ],
    );

    final r = await client.upload(
      company: 'demo',
      deviceToken: 't',
      upload: fat,
    );

    expect(r, isA<UploadTooLarge>());
    expect(r.isRetryable, isFalse);
    verifyNever(
      () => dio.post<Map<String, Object?>>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    );
  });

  // Dio throws on a non-2xx by default. Each of these is a real answer from
  // the server, not a transport failure, so they must come back as results
  // rather than exceptions — a 422 in particular is a sentence for the
  // technician and must reach them.
  test('turns a 422 into a rejection rather than throwing', () async {
    when(
      () => dio.post<Map<String, Object?>>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/demo/sync/upload'),
        response: _resp(422, const {
          'rejections': [
            {
              'table': 'TestCertificate',
              'mobile_id': 'cert-uuid',
              'reason': 'incomplete_values',
              'message': 'not every test has a reading against it',
            },
          ],
        }),
        type: DioExceptionType.badResponse,
      ),
    );

    final r = await client.upload(
      company: 'demo',
      deviceToken: 't',
      upload: _upload(),
    );

    expect(r, isA<UploadRejected>());
    expect((r as UploadRejected).rejections.single.reason, 'incomplete_values');
  });

  test('turns a 409 into a conflict rather than throwing', () async {
    when(
      () => dio.post<Map<String, Object?>>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/x'),
        response: _resp(409, const {
          'conflicts': [
            {'table': 'TestCertificate', 'mobile_id': 'c', 'fields': []},
          ],
        }),
        type: DioExceptionType.badResponse,
      ),
    );

    expect(
      await client.upload(company: 'demo', deviceToken: 't', upload: _upload()),
      isA<UploadConflict>(),
    );
  });

  // No signal is the normal condition for this app, not an exception.
  test('reports a connection failure as retryable rather than throwing',
      () async {
    when(
      () => dio.post<Map<String, Object?>>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError,
      ),
    );

    final r = await client.upload(
      company: 'demo',
      deviceToken: 't',
      upload: _upload(),
    );

    expect(r, isA<UploadTransportError>());
    expect(r.isRetryable, isTrue);
  });

  test('refuses a batch larger than the server accepts before sending it',
      () async {
    final tooBig = CertificateUpload(
      mobileId: 'c',
      certificate: const {},
      lines: [
        for (var i = 0; i < 501; i++)
          CertificateLineUpload(mobileId: '$i', data: const {}),
      ],
    );

    final r = await client.upload(
      company: 'demo',
      deviceToken: 't',
      upload: tooBig,
    );

    // Too many ops and too many bytes are the same situation with the same
    // remedy — fewer ops — so they answer with the same type.
    expect(r, isA<UploadTooLarge>());
    verifyNever(
      () => dio.post<Map<String, Object?>>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    );
  });
}
