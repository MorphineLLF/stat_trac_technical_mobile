import 'dart:convert';

import 'package:dio/dio.dart';

import 'certificate_upload.dart';
import 'sync_upload_result.dart';

/// Posts a certificate batch to `POST /{company}/sync/upload`.
///
/// **Every answer comes back as a [SyncUploadResult], never as an exception.**
/// Dio throws on any non-2xx, but a 409 and a 422 are the server answering
/// clearly — a 422 in particular is a sentence meant for the technician, and a
/// sentence that arrives as a stack trace reaches nobody.
///
/// Nor is a connection failure exceptional here. This app is used in hospital
/// basements; no signal is the normal condition and the queue is designed for
/// it.
class SyncUploadClient {
  SyncUploadClient(this._dio);

  final Dio _dio;

  Future<SyncUploadResult> upload({
    required String company,
    required String deviceToken,
    required CertificateUpload upload,
  }) async {
    final batch = upload.toBatch();

    // Checked before sending: the server caps a batch at 500 ops, and a
    // refusal we can predict should not cost a round trip from a device that
    // may be on one bar of signal.
    if (batch.exceedsServerLimit) {
      return UploadTooLarge(
        'This certificate has ${batch.ops.length} operations and the server '
        'accepts ${SyncUploadBatchLimits.ops}. It has to be split.',
      );
    }

    // The other half of the same cap, and the half that had never been
    // checked. Signatures travel in this batch when they were captured with
    // the readings, and a base64 PNG is the one op that can carry a megabyte
    // on its own.
    //
    // Encoding the body twice — once here, once in Dio — is worth it: the
    // answer would otherwise be a 413, which is permanent, so the round trip
    // buys nothing but a flat battery.
    final body = jsonEncode(batch.toJson());
    final bytes = utf8.encode(body).length;
    if (bytes > SyncUploadBatchLimits.bodyBytes) {
      return UploadTooLarge(
        'This certificate is ${(bytes / 1024).round()} KB and the server '
        'accepts ${SyncUploadBatchLimits.bodyBytes ~/ 1024} KB. It has to be '
        'split — signatures are usually what makes the difference.',
      );
    }

    try {
      final response = await _dio.post<Map<String, Object?>>(
        '/$company/sync/upload',
        data: batch.toJson(),
        // Bearer, not a cookie — a cookie is turned away by the CSRF guard.
        options: Options(
          headers: {'Authorization': 'Bearer $deviceToken'},
          contentType: Headers.jsonContentType,
        ),
      );
      return SyncUploadResult.fromResponse(
        response.statusCode ?? 0,
        response.data ?? const {},
      );
    } on DioException catch (e) {
      final response = e.response;
      if (response != null) {
        return SyncUploadResult.fromResponse(
          response.statusCode ?? 0,
          _bodyOf(response),
        );
      }
      return UploadTransportError(0, _transportMessage(e));
    }
  }

  static Map<String, Object?> _bodyOf(Response<dynamic> r) {
    final data = r.data;
    return data is Map<String, Object?> ? data : const {};
  }

  static String _transportMessage(DioException e) => switch (e.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.unknown =>
      'Cannot reach the server. This will be sent when there is signal.',
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout =>
      'The server timed out. This will be sent again.',
    _ => 'Upload failed. This will be sent again.',
  };
}

/// Server-side limits, named so a message can quote them.
abstract final class SyncUploadBatchLimits {
  static const ops = 500;
  static const bodyBytes = 1024 * 1024;
}
