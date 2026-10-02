import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/documents/document_result.dart';

/// The work order sheet: fetching the PDF, and emailing it to the client.
///
/// The same shape as the certificate's client, against the work order routes,
/// with the ninety-day device token as a Bearer:
///
///   GET  /{company}/work-order/{id}/print.pdf
///   GET  /{company}/work-order/{id}/email   what the email box opens with
///   POST /{company}/work-order/{id}/email
///
/// **Every answer comes back as a result, never as an exception** — a refusal
/// is the server answering clearly, and no signal is ordinary here.
class WorkOrderDocumentClient {
  WorkOrderDocumentClient(this._dio);

  final Dio _dio;

  Options _bearer(String token, {ResponseType? type, String? contentType}) =>
      Options(
        headers: {'Authorization': 'Bearer $token'},
        responseType: type,
        contentType: contentType,
        validateStatus: (_) => true,
      );

  /// The rendered work order sheet.
  Future<DocPdfResult> fetchPdf({
    required String company,
    required String deviceToken,
    required int trackId,
  }) async {
    try {
      final response = await _dio.get<List<int>>(
        '/$company/work-order/$trackId/print.pdf',
        options: _bearer(deviceToken, type: ResponseType.bytes),
      );
      final status = response.statusCode ?? 0;
      final body = response.data ?? const <int>[];
      if (status == 200) return DocPdfBytes(Uint8List.fromList(body));
      return docPdfResultFromResponse(status, String.fromCharCodes(body));
    } on DioException catch (e) {
      return DocPdfUnavailable(0, _transportMessage(e));
    }
  }

  /// The technician's own CC, reply address and sign-off. Null when the server
  /// could not say — the box then opens empty and the server signs the mail.
  Future<DocEmailDefaults?> fetchEmailDefaults({
    required String company,
    required String deviceToken,
    required int trackId,
  }) async {
    try {
      final response = await _dio.get<Map<String, Object?>>(
        '/$company/work-order/$trackId/email',
        options: _bearer(deviceToken),
      );
      return docEmailDefaultsFromResponse(
        response.statusCode ?? 0,
        response.data ?? const {},
      );
    } on DioException {
      return null;
    }
  }

  /// Emails the work order sheet. [cc] and [body] left out (null) are filled
  /// by the server from the Admin row; sent as `''` they stay empty. See
  /// [docEmailFields].
  Future<DocEmailResult> email({
    required String company,
    required String deviceToken,
    required int trackId,
    required String to,
    String? cc,
    String? body,
  }) async {
    try {
      final response = await _dio.post<Map<String, Object?>>(
        '/$company/work-order/$trackId/email',
        data: {'to': to.trim(), 'cc': ?cc?.trim(), 'body': ?body},
        options: _bearer(deviceToken, contentType: Headers.jsonContentType),
      );
      return docEmailResultFromResponse(
        response.statusCode ?? 0,
        response.data ?? const {},
      );
    } on DioException catch (e) {
      return DocEmailUnavailable('unavailable', _transportMessage(e));
    }
  }

  static String _transportMessage(DioException e) => switch (e.type) {
    DioExceptionType.connectionError || DioExceptionType.unknown =>
      'Cannot reach the server. Try again when you have signal.',
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => 'The server timed out. Try again.',
    _ => 'Could not reach the work order. Try again.',
  };
}
