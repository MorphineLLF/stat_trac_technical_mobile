import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/config/app_config.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/work_order_document_client.dart';

part 'work_order_document_providers.g.dart';

/// No interceptor: these routes take the device token as a Bearer, and a
/// cookie is turned away by the CSRF guard — as for the certificate client.
@riverpod
WorkOrderDocumentClient workOrderDocumentClient(Ref ref) {
  return WorkOrderDocumentClient(
    Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        // A rendered sheet is headless Chrome plus the download.
        receiveTimeout: const Duration(seconds: 60),
      ),
    ),
  );
}

/// The company and device token these routes need, or null when signed out.
@riverpod
Future<({String company, String token})?> workOrderDocumentCredentials(
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
