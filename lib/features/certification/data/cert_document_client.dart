import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'cert_document_result.dart';

/// The certificate document: fetching the PDF, and emailing it.
///
/// **Written for the Go application and owing nothing to what came before.**
/// The retired endpoint wrapped a base64 PDF in JSON and had no working email
/// at all; these two routes return bytes and a typed JSON answer, and they
/// authenticate with the ninety-day device token as a Bearer.
///
///   GET  /{company}/certification/e-test/{id}/print.pdf
///   POST /{company}/certification/e-test/{id}/email
///
/// **Every answer comes back as a result, never as an exception.** A 409 on a
/// draft and a 422 refusal are the server answering clearly, and an answer
/// that arrives as a stack trace reaches nobody. No signal is not exceptional
/// either — this app is used in hospital basements.
class CertDocumentClient {
  CertDocumentClient(this._dio);

  final Dio _dio;

  /// The rendered certificate.
  ///
  /// `responseType: bytes` because this route returns a PDF, not JSON — and
  /// `validateStatus` accepts everything so a refusal is read rather than
  /// thrown, including the JSON one a Bearer caller gets.
  Future<CertPdfResult> fetchPdf({
    required String company,
    required String deviceToken,
    required int certificateId,
  }) async {
    try {
      final response = await _dio.get<List<int>>(
        '/$company/certification/e-test/$certificateId/print.pdf',
        options: Options(
          headers: {'Authorization': 'Bearer $deviceToken'},
          responseType: ResponseType.bytes,
          validateStatus: (_) => true,
        ),
      );

      final status = response.statusCode ?? 0;
      final body = response.data ?? const <int>[];

      if (status == 200) {
        return CertPdfBytes(Uint8List.fromList(body));
      }
      return certPdfResultFromResponse(status, String.fromCharCodes(body));
    } on DioException catch (e) {
      // No signal, or the request never completed. Worth trying again when
      // there is.
      return CertPdfUnavailable(0, _transportMessage(e));
    }
  }

  /// Emails the certificate.
  ///
  /// Only [to] is required — an empty subject becomes the certificate number
  /// server-side.
  ///
  /// **`from` is the company's and is not ours to set.** [replyTo] is,
  /// though: send the technician's address when it is known, and when it is
  /// not a reply reaches the company mailbox, which is at least somebody.
  ///
  /// **Unknown fields are refused rather than dropped**, so nothing is sent
  /// that the contract does not name — a misspelled `cc` would otherwise be a
  /// copy nobody receives and nobody is told about.
  Future<CertEmailResult> email({
    required String company,
    required String deviceToken,
    required int certificateId,
    required String to,
    String? cc,
    String? replyTo,
    String? subject,
    String? body,
  }) async {
    try {
      final response = await _dio.post<Map<String, Object?>>(
        '/$company/certification/e-test/$certificateId/email',
        data: {
          'to': to.trim(),
          'cc': ?cc?.trim(),
          'reply_to': ?replyTo?.trim(),
          'subject': ?subject?.trim(),
          'body': ?body,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $deviceToken'},
          contentType: Headers.jsonContentType,
          validateStatus: (_) => true,
        ),
      );

      return certEmailResultFromResponse(
        response.statusCode ?? 0,
        response.data ?? const {},
      );
    } on DioException catch (e) {
      return CertEmailUnavailable('unavailable', _transportMessage(e));
    }
  }

  static String _transportMessage(DioException e) => switch (e.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.unknown => 'Cannot reach the server. Try again when you '
        'have signal.',
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => 'The server timed out. Try again.',
    _ => 'Could not reach the certificate. Try again.',
  };
}
