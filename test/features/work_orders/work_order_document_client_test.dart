import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/core/documents/document_result.dart';
import 'package:stat_trac_technical/features/work_orders/data/work_order_document_client.dart';

/// Answers every request with one canned response, and remembers the request.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body, {this.type = 'application/json', this.fail});
  final int status;
  final List<int> body;
  final String type;
  final DioExceptionType? fail;
  RequestOptions? seen;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen = options;
    if (fail != null) throw DioException(requestOptions: options, type: fail!);
    return ResponseBody.fromBytes(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [type],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

(WorkOrderDocumentClient, _Adapter) _client(_Adapter a) {
  final dio = Dio(BaseOptions(baseUrl: 'http://server'))..httpClientAdapter = a;
  return (WorkOrderDocumentClient(dio), a);
}

List<int> _json(Object o) => utf8.encode(jsonEncode(o));

void main() {
  group('the PDF', () {
    test('asks the work order route with the device token', () async {
      final (c, a) = _client(_Adapter(200, [1, 2, 3], type: 'application/pdf'));
      final r = await c.fetchPdf(
        company: 'demo',
        deviceToken: 't',
        trackId: 7144,
      );

      expect((r as DocPdfBytes).bytes, [1, 2, 3]);
      expect(a.seen!.path, '/demo/work-order/7144/print.pdf');
      expect(a.seen!.headers['Authorization'], 'Bearer t');
    });

    // A server without the Go work: the path is not on the handset list.
    test('a server without the work refuses in a sentence', () async {
      final (c, _) = _client(
        _Adapter(403, _json({'error': 'not available to the mobile app'})),
      );
      final r = await c.fetchPdf(company: 'demo', deviceToken: 't', trackId: 1);

      expect((r as DocPdfRefused).message, 'not available to the mobile app');
    });

    test('no signal is unavailable, said plainly', () async {
      final (c, _) = _client(
        _Adapter(0, const [], fail: DioExceptionType.connectionError),
      );
      final r = await c.fetchPdf(company: 'demo', deviceToken: 't', trackId: 1);

      expect(r, isA<DocPdfUnavailable>());
      expect((r as DocPdfUnavailable).message, contains('signal'));
    });
  });

  group('the email', () {
    test('sends only what it was given, to the work order route', () async {
      final (c, a) = _client(
        _Adapter(
          200,
          _json({
            'sent': true,
            'work_order': 7144,
            'to': ['a@b.example'],
          }),
        ),
      );
      final r = await c.email(
        company: 'demo',
        deviceToken: 't',
        trackId: 7144,
        to: ' a@b.example ',
      );

      expect((r as DocEmailSent).id, 7144);
      expect(a.seen!.path, '/demo/work-order/7144/email');
      expect(a.seen!.method, 'POST');
      expect(a.seen!.data, {'to': 'a@b.example'});
    });

    test('a refusal carries its field', () async {
      final (c, _) = _client(
        _Adapter(
          422,
          _json({'reason': 'bad_address', 'error': 'not right', 'field': 'cc'}),
        ),
      );
      final r = await c.email(
        company: 'demo',
        deviceToken: 't',
        trackId: 1,
        to: 'x@y.z',
      );

      expect((r as DocEmailRefused).field, 'cc');
    });

    test('no signal is unavailable', () async {
      final (c, _) = _client(
        _Adapter(0, const [], fail: DioExceptionType.connectionError),
      );
      final r = await c.email(
        company: 'demo',
        deviceToken: 't',
        trackId: 1,
        to: 'x@y.z',
      );

      expect(r, isA<DocEmailUnavailable>());
    });

    test("the box's defaults", () async {
      final (c, a) = _client(
        _Adapter(
          200,
          _json({
            'cc': 'o@co.example',
            'reply_to': 'me@co.example',
            'signature': 'Athi',
          }),
        ),
      );
      final d = await c.fetchEmailDefaults(
        company: 'demo',
        deviceToken: 't',
        trackId: 7144,
      );

      expect(d!.cc, 'o@co.example');
      expect(a.seen!.method, 'GET');
      expect(a.seen!.path, '/demo/work-order/7144/email');
    });
  });
}
