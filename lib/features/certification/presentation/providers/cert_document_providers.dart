import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/config/app_config.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/cert_document_client.dart';

part 'cert_document_providers.g.dart';

/// The certificate document client.
///
/// No interceptor, deliberately: these routes take the ninety-day device
/// token as a Bearer, and a cookie is turned away by the CSRF guard — the
/// same reasoning as the upload client.
@riverpod
CertDocumentClient certDocumentClient(Ref ref) {
  return CertDocumentClient(
    Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        // A rendered certificate is roughly a second of headless Chrome plus
        // the download, so it is given longer than a JSON call.
        receiveTimeout: const Duration(seconds: 60),
      ),
    ),
  );
}

/// The company and device token these routes need, or null when signed out.
@riverpod
Future<({String company, String token})?> certDocumentCredentials(
  Ref ref,
) async {
  final local = ref.watch(authLocalDataSourceProvider);
  final company = await local.readDbName();
  final token = (await local.readDeviceToken())?.token;

  if (company == null || token == null || company.isEmpty || token.isEmpty) {
    return null;
  }
  return (company: company, token: token);
}
