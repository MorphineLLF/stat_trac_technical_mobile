import 'package:dio/dio.dart';

/// Turns a sign-in failure into something a technician can act on.
///
/// The previous version matched substrings against `e.toString()` and
/// collapsed everything it did not recognise into "Login failed. Please try
/// again." That hid the two failures most likely to happen on first setup, and
/// they need opposite responses:
///
///   404 — the company is wrong. It is a path segment in the URL, so an
///         unknown company is "no such route", not "bad credentials".
///   401 — the credentials are wrong.
///
/// Both used to read as "Login failed", which sent people to check the
/// password when the company was the problem. Where the server explains
/// itself, prefer its words over ours.
String loginErrorMessage(Object error) {
  if (error is! DioException) {
    return 'Login failed. Please try again.';
  }

  switch (error.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.unknown:
      return 'Cannot reach the server. Check your connection.';
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'The server timed out. Check your connection and try again.';
    default:
      break;
  }

  final status = error.response?.statusCode;
  switch (status) {
    case 404:
      return 'Company not recognised. Check the Company name and try again.';
    case 401:
    case 403:
      return _serverMessage(error.response?.data) ??
          'Invalid username or password.';
    case 500:
    case 502:
    case 503:
    case 504:
      return 'The server had a problem. Try again shortly.';
  }

  return _serverMessage(error.response?.data) ??
      'Login failed. Please try again.';
}

/// The Go API reports failures as `{"error": "..."}`. Presented as a sentence
/// so it reads as part of the app rather than as a leaked payload.
String? _serverMessage(Object? data) {
  if (data is! Map) return null;
  final raw = data['error'];
  if (raw is! String) return null;

  final text = raw.trim();
  if (text.isEmpty) return null;

  final sentence = text[0].toUpperCase() + text.substring(1);
  return sentence.endsWith('.') ? sentence : '$sentence.';
}
