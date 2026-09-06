import 'dart:convert';
import 'dart:typed_data';

/// What the Go application answers when asked for a certificate document.
///
/// Written for that server and nothing else. The retired Horse endpoint
/// returned a base64 PDF inside JSON; this route returns the bytes, and its
/// refusals arrive in two shapes rather than one.
sealed class CertPdfResult {
  const CertPdfResult();

  /// Whether asking again could ever give a different answer.
  bool get isRetryable;
}

/// The document, as bytes.
class CertPdfBytes extends CertPdfResult {
  const CertPdfBytes(this.bytes);
  final Uint8List bytes;

  @override
  bool get isRetryable => false;
}

/// The certificate has not reached the server yet.
///
/// A 409, and the most useful answer on this route: it distinguishes "not
/// uploaded yet" from "failed", so the technician can be told they need a
/// moment of signal rather than shown a blank failure.
class CertPdfNotReady extends CertPdfResult {
  const CertPdfNotReady(this.message);
  final String message;

  @override
  bool get isRetryable => false;
}

/// Refused, or no such certificate for this person.
///
/// Out of the technician's places answers as missing rather than forbidden —
/// the convention on that server — so 403 and 404 land together.
class CertPdfRefused extends CertPdfResult {
  const CertPdfRefused(this.status, this.message);
  final int status;
  final String message;

  @override
  bool get isRetryable => false;
}

/// The server could not render it. Worth asking again.
class CertPdfUnavailable extends CertPdfResult {
  const CertPdfUnavailable(this.status, this.message);
  final int status;
  final String message;

  @override
  bool get isRetryable => true;
}

/// Turns a status and a body into an answer.
///
/// **The body may be JSON or it may be prose.** Errors on that route are
/// text/plain or HTML because it is an office route, except a refusal to a
/// Bearer caller, which is JSON. Both must reach the technician as a
/// sentence, so a JSON body is unwrapped and anything else is passed through.
CertPdfResult certPdfResultFromResponse(int status, String body) {
  final message = _sentenceFrom(body);

  return switch (status) {
    409 => CertPdfNotReady(message),
    403 || 404 => CertPdfRefused(status, message),
    >= 500 => CertPdfUnavailable(status, message),
    _ => CertPdfRefused(status, message),
  };
}

/// What the server says when asked to email a certificate.
sealed class CertEmailResult {
  const CertEmailResult();
  bool get isRetryable;
}

/// It left.
///
/// **A 200 promises the mail was sent and nothing else.** The server answers
/// 200 even when its own audit write fails afterwards, because answering
/// "failed" would have the technician send the same certificate twice.
class CertEmailSent extends CertEmailResult {
  const CertEmailSent({this.certificate, this.number, this.to = const []});
  final int? certificate;
  final String? number;
  final List<String> to;

  @override
  bool get isRetryable => false;
}

/// The answer is no, and it will stay no.
///
/// Park it and show the sentence. The codes are `bad_request`,
/// `no_recipient`, `bad_address`, `not_found`, `void`, `draft` and
/// `not_configured`.
class CertEmailRefused extends CertEmailResult {
  const CertEmailRefused({
    required this.reason,
    required this.message,
    this.field,
  });
  final String reason;
  final String message;

  /// Which input the refusal is about, when the server names one.
  final String? field;

  @override
  bool get isRetryable => false;
}

/// The renderer or the mail host is down — `no_renderer`, `render_failed`,
/// `send_failed`, `unavailable`. Try again.
class CertEmailUnavailable extends CertEmailResult {
  const CertEmailUnavailable(this.reason, this.message);
  final String reason;
  final String message;

  @override
  bool get isRetryable => true;
}

/// Turns the email route's answer into a result.
///
/// Retryability is taken from the status rather than from the reason code:
/// the codes are a stable vocabulary for telling a person what happened, and
/// a code this build has never heard of must not silently become retryable.
CertEmailResult certEmailResultFromResponse(
  int status,
  Map<String, Object?> body,
) {
  final reason = (body['reason'] as String?) ?? 'unavailable';
  final message =
      (body['error'] as String?) ?? 'The certificate could not be emailed.';

  if (status == 200) {
    return CertEmailSent(
      certificate: (body['certificate'] as num?)?.toInt(),
      number: body['number'] as String?,
      to: [for (final a in (body['to'] as List?) ?? const []) a as String],
    );
  }

  if (status >= 500) {
    return CertEmailUnavailable(reason, message);
  }

  return CertEmailRefused(
    reason: reason,
    message: message,
    field: body['field'] as String?,
  );
}

/// A body a technician can read.
String _sentenceFrom(String body) {
  final trimmed = body.trim();
  if (!trimmed.startsWith('{')) {
    return trimmed;
  }
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map && decoded['error'] is String) {
      return decoded['error'] as String;
    }
  } on FormatException {
    // Not JSON after all. Whatever it is, it is what the server said.
  }
  return trimmed;
}
