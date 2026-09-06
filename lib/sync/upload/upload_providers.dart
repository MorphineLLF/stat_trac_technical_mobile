import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/config/app_config.dart';
import '../../database/database_helper.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/certification/presentation/providers/certificate_providers.dart';
import 'sync_upload_client.dart';
import 'upload_archive.dart';
import 'upload_queue.dart';
import 'upload_worker.dart';

part 'upload_providers.g.dart';

@riverpod
Future<UploadQueue> uploadQueue(Ref ref) async {
  return UploadQueue(await DatabaseHelper.instance.database);
}

/// What was sent and what came back, kept after the queue row is deleted.
@riverpod
Future<UploadArchive> uploadArchive(Ref ref) async {
  return UploadArchive(await DatabaseHelper.instance.database);
}

/// The upload client. No interceptor: this route takes the ninety-day device
/// token as a Bearer, and a cookie is turned away by the CSRF guard.
@riverpod
SyncUploadClient syncUploadClient(Ref ref) {
  return SyncUploadClient(
    Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
      ),
    ),
  );
}

@riverpod
Future<UploadWorker> uploadWorker(Ref ref) async {
  final local = ref.watch(authLocalDataSourceProvider);
  return UploadWorker(
    queue: await ref.watch(uploadQueueProvider.future),
    archive: await ref.watch(uploadArchiveProvider.future),
    client: ref.watch(syncUploadClientProvider),
    confirm: ref.watch(certLocalDataSourceProvider).markSyncedByMobileId,
    company: local.readDbName,
    deviceToken: () async => (await local.readDeviceToken())?.token,
  );
}

/// How many certificates are waiting to reach the server.
///
/// This is the number a technician needs before leaving a site, so it counts
/// everything still on the device — including the ones held for a conflict or
/// a rejection, because those are exactly the ones somebody has to act on.
@riverpod
Future<int> pendingUploadCount(Ref ref) async {
  return (await ref.watch(uploadQueueProvider.future)).count();
}
