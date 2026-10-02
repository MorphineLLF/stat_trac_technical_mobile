import 'dart:convert';
import 'dart:typed_data';

/// What the Go application answers when asked for a document — a certificate
/// or a work order sheet. The two routes answer in the same shapes.
///
/// Written for that server and nothing else. These routes return the bytes,
/// and their refusals arrive in two shapes rather than one.
sealed class DocPdfResult {
  const DocPdfResult();

  /// Whether asking again could ever give a different answer.
  bool get isRetryable;
}

/// The document, as bytes.
class DocPdfBytes extends DocPdfResult {
  const DocPdfBytes(this.bytes);
  final Uint8List bytes;

  @override
  bool get isRetryable => false;
}

/// The certificate has not reached the server yet.
///
/// A 409, and the most useful answer on this route: it distinguishes "not
/// uploaded yet" from "failed", so the technician can be told they need a
/// moment of signal rather than shown a blank failure.
class DocPdfNotReady extends DocPdfResult {
  const DocPdfNotReady(this.message);
  final String message;

  @override
  bool get isRetryable => false;
}

/// Refused, or no such certificate for this person.
///
/// Out of the technician's places answers as missing rather than forbidden —
/// the convention on that server — so 403 and 404 land together.
class DocPdfRefused extends DocPdfResult {
  const DocPdfRefused(this.status, this.message);
  final int status;
  final String message;

  @override
  bool get isRetryable => false;
}

/// The server could not render it. Worth asking again.
class DocPdfUnavailable extends DocPdfResult {
  const DocPdfUnavailable(this.status, this.message);
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
DocPdfResult docPdfResultFromResponse(int status, String body) {
  final message = _sentenceFrom(body);

  return switch (status) {
    409 => DocPdfNotReady(message),
    403 || 404 => DocPdfRefused(status, message),
    >= 500 => DocPdfUnavailable(status, message),
    _ => DocPdfRefused(status, message),
  };
}

/// What the server says when asked to email a certificate.
sealed class DocEmailResult {
  const DocEmailResult();
  bool get isRetryable;
}

/// It left.
///
/// **A 200 promises the mail was sent and nothing else.** The server answers
/// 200 even when its own audit write fails afterwards, because answering
/// "failed" would have the technician send the same certificate twice.
class DocEmailSent extends DocEmailResult {
  const DocEmailSent({this.id, this.number, this.to = const []});

  /// The certificate's or the work order's id, whichever route answered.
  final int? id;
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
class DocEmailRefused extends DocEmailResult {
  const DocEmailRefused({
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
class DocEmailUnavailable extends DocEmailResult {
  const DocEmailUnavailable(this.reason, this.message);
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
DocEmailResult docEmailResultFromResponse(
  int status,
  Map<String, Object?> body,
) {
  final reason = (body['reason'] as String?) ?? 'unavailable';
  final message =
      (body['error'] as String?) ?? 'The document could not be emailed.';

  if (status == 200) {
    return DocEmailSent(
      id: ((body['certificate'] ?? body['work_order']) as num?)?.toInt(),
      number: body['number'] as String?,
      to: [for (final a in (body['to'] as List?) ?? const []) a as String],
    );
  }

  if (status >= 500) {
    return DocEmailUnavailable(reason, message);
  }

  return DocEmailRefused(
    reason: reason,
    message: message,
    field: body['field'] as String?,
  );
}

/// What the email box opens with: the technician's own CC, reply address and
/// sign-off, off their Admin row.
///
/// That row does not sync, so the server is asked when the box opens —
/// `GET .../email`. The same three fields the server fills a send with when
/// the device leaves them out.
class DocEmailDefaults {
  const DocEmailDefaults({
    this.cc = '',
    this.replyTo = '',
    this.signature = '',
  });
  final String cc;
  final String replyTo;
  final String signature;

  /// The message box's starting text: two blank lines the cursor starts in,
  /// then the sign-off — as the office's box opens. Windows line endings
  /// become a phone text box's.
  String get initialBody {
    final sig = signature.replaceAll('\r\n', '\n').trimRight();
    return sig.isEmpty ? '' : '\n\n$sig';
  }
}

/// The defaults, or null when the server did not give them. Null is not an
/// error: the box opens empty and the send is filled in server-side instead.
DocEmailDefaults? docEmailDefaultsFromResponse(
  int status,
  Map<String, Object?> body,
) {
  if (status != 200) return null;
  return DocEmailDefaults(
    cc: (body['cc'] as String?) ?? '',
    replyTo: (body['reply_to'] as String?) ?? '',
    signature: (body['signature'] as String?) ?? '',
  );
}

/// The CC and message a send carries.
///
/// **What is in the boxes when Send is pressed is what goes.** The server
/// fills a field the request leaves out from the Admin row, and keeps one sent
/// empty empty. So when the defaults were shown, both are sent as they stand —
/// a CC the technician cleared must not come back. When they never arrived,
/// an empty box is left out so the server can still sign the mail.
({String? cc, String? body}) docEmailFields({
  required bool defaultsShown,
  required String cc,
  required String body,
}) {
  final ccText = cc.trim();
  if (defaultsShown) return (cc: ccText, body: body);
  return (
    cc: ccText.isEmpty ? null : ccText,
    body: body.trim().isEmpty ? null : body,
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
