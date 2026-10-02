import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
  // EVERY ref.watch before the first await. Callers take this worker with
  // ref.read(...future), which does not keep it alive, so it can be disposed
  // while it waits on the database — and a ref.watch after that await throws
  // "Cannot use the Ref ... after it has been disposed". That threw on every
  // drain on a real phone: nothing was sent, and the button said only
  // "Could not send".
  final local = ref.watch(authLocalDataSourceProvider);
  final client = ref.watch(syncUploadClientProvider);
  final certLocal = ref.watch(certLocalDataSourceProvider);
  final queueFuture = ref.watch(uploadQueueProvider.future);
  final archiveFuture = ref.watch(uploadArchiveProvider.future);

  final queue = await queueFuture;

  // Certificates parked because their row op carried the verdict are freed
  // here rather than retyped: the work is on the device and the payload was
  // one key away from being sendable. Idempotent, so it costs nothing once
  // there is nothing left to free.
  final freed = await queue.repairVerdictInRowOp();
  if (freed > 0) {
    debugPrint(
      '[upload] freed $freed certificate${freed == 1 ? '' : 's'} parked '
      'for carrying the verdict in the row op — they will go on the next '
      'drain',
    );
  }

  return UploadWorker(
    queue: queue,
    archive: await archiveFuture,
    client: client,
    confirm: certLocal.markSyncedByMobileId,
    company: local.readDbName,
    deviceToken: () async => (await local.readDeviceToken())?.token,
  );
}

/// How many jobs — certificates and work orders — are waiting to reach the
/// server.
///
/// This is the number a technician needs before leaving a site, so it counts
/// everything still on the device — including the ones held for a conflict or
/// a rejection, because those are exactly the ones somebody has to act on.
/// Certificates alone showed "1" over two jobs not sent.
@riverpod
Future<int> pendingUploadCount(Ref ref) async {
  final queue = await ref.watch(uploadQueueProvider.future);
  return await queue.certificateCount() + await queue.workOrderCount();
}
