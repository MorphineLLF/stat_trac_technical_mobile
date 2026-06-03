import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api/auth_interceptor.dart';
import '../api/dio_client.dart';
import '../database/database_helper.dart';
import '../features/assets/presentation/providers/asset_providers.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/auth/presentation/providers/auth_state.dart';
import '../features/certification/presentation/providers/certificate_providers.dart';
import 'sync_error_log_data_source.dart';
export 'sync_error_log_data_source.dart' show SyncErrorEntry;
import 'sync_remote_data_source.dart';
import 'sync_state.dart';

part 'sync_notifier.g.dart';

// ── Infrastructure ────────────────────────────────────────────────────────────

@riverpod
SyncErrorLogDataSource syncErrorLogDataSource(Ref ref) =>
    SyncErrorLogDataSourceImpl(DatabaseHelper.instance);

@riverpod
SyncRemoteDataSource syncRemoteDataSource(Ref ref) {
  final authLocal = ref.watch(authLocalDataSourceProvider);
  final authRemote = ref.watch(authRemoteDataSourceProvider);
  final interceptor = AuthInterceptor(local: authLocal, remote: authRemote);
  return SyncRemoteDataSourceImpl(buildDioClient(interceptor));
}

// ── Notifier ──────────────────────────────────────────────────────────────────

@riverpod
class SyncNotifier extends _$SyncNotifier {
  @override
  SyncState build() => const SyncIdle();

  Future<void> triggerSync() async {
    if (state is SyncInProgress) return;

    final previousSuccess = switch (state) {
      SyncComplete(:final lastSyncedAt) => lastSyncedAt,
      SyncError(:final lastSyncedAt) => lastSyncedAt,
      _ => null,
    };

    state = const SyncInProgress(progress: 0.0, message: 'Starting sync...');

    // Connectivity check — return silently if offline.
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.isEmpty ||
        connectivity.every((r) => r == ConnectivityResult.none)) {
      state = previousSuccess != null
          ? SyncComplete(previousSuccess)
          : const SyncIdle();
      return;
    }

    final errorLog = ref.read(syncErrorLogDataSourceProvider);
    final syncRemote = ref.read(syncRemoteDataSourceProvider);

    // Purge stale resolved error rows on each sync cycle.
    await errorLog.purgeOldResolved();
    ref.invalidate(unresolvedSyncErrorCountProvider);

    state = const SyncInProgress(progress: 0.05, message: 'Syncing assets...');

    try {
      final result = await ref.read(assetRepositoryProvider).syncAssets(
        onPage: (page) {
          final p = (0.05 + page * 0.05).clamp(0.05, 0.60);
          state = SyncInProgress(
            progress: p,
            message: 'Syncing assets (page $page)...',
          );
        },
      );

      final message = _buildSyncMessage(
          result.rowCount, result.pageCount, result.removedIds, result.changes);
      await syncRemote.postSyncLog(
        operation: 'sync_assets',
        entity: 'assets',
        rowCount: result.rowCount,
        status: 'success',
        message: message,
      );

      await errorLog.markResolved('sync_assets');
      state = const SyncInProgress(progress: 0.65, message: 'Syncing templates...');
    } on Exception catch (e, st) {
      await errorLog.logError(
        operation: 'sync_assets',
        entityTable: 'assets',
        errorMessage: e.toString(),
        stackTrace: st.toString(),
      );
      await syncRemote.postSyncLog(
        operation: 'sync_assets',
        entity: 'assets',
        rowCount: 0,
        status: 'error',
        message: e.toString(),
      );
      state = SyncError(
        message: _friendlySyncError(e),
        lastSyncedAt: previousSuccess,
      );
      ref.invalidate(unresolvedSyncErrorCountProvider);
      return;
    }

    // Template sync — errors are logged but do not block the overall sync.
    try {
      await ref.read(certificateRepositoryProvider).syncTemplatesFromRemote();
      await errorLog.markResolved('sync_templates');
    } on Exception catch (e, st) {
      await errorLog.logError(
        operation: 'sync_templates',
        entityTable: 'test_template_names',
        errorMessage: e.toString(),
        stackTrace: st.toString(),
      );
      await syncRemote.postSyncLog(
        operation: 'sync_templates',
        entity: 'test_template_names',
        rowCount: 0,
        status: 'error',
        message: e.toString(),
      );
    }

    // Step 5.5 — test equipment assets (~68%)
    state = const SyncInProgress(progress: 0.68, message: 'Syncing test equipment…');
    try {
      final equipCount =
          await ref.read(certificateRepositoryProvider).syncTestEquipmentAssets();
      await syncRemote.postSyncLog(
        operation: 'sync_test_equipment',
        entity: 'test_equipment_assets',
        rowCount: equipCount,
        status: 'success',
        message: 'Synced $equipCount test equipment assets',
      );
      await errorLog.markResolved('sync_test_equipment');
      ref.invalidate(testEquipmentAssetsProvider);
    } on Exception catch (e, st) {
      await errorLog.logError(
        operation: 'sync_test_equipment',
        entityTable: 'test_equipment_assets',
        errorMessage: e.toString(),
        stackTrace: st.toString(),
      );
      await syncRemote.postSyncLog(
        operation: 'sync_test_equipment',
        entity: 'test_equipment_assets',
        rowCount: 0,
        status: 'error',
        message: e.toString(),
      );
    }

    state = const SyncInProgress(progress: 0.80, message: 'Uploading certificates...');

    // Push pending certificates to the server.
    try {
      await ref.read(certificateRepositoryProvider).pushPendingCertificates();
      await errorLog.markResolved('push_certificates');
    } on Exception catch (e, st) {
      await errorLog.logError(
        operation: 'push_certificates',
        entityTable: 'test_certificates',
        errorMessage: e.toString(),
        stackTrace: st.toString(),
      );
      await syncRemote.postSyncLog(
        operation: 'push_certificates',
        entity: 'test_certificates',
        rowCount: 0,
        status: 'error',
        message: e.toString(),
      );
    }

    state = const SyncInProgress(progress: 0.90, message: 'Downloading certificates...');

    // Pull certificates from the server for this technician.
    final authState = ref.read(authProvider);
    final technicianId = switch (authState) {
      AuthAuthenticated(:final user) => user.id,
      _ => 0,
    };
    if (technicianId > 0) {
      try {
        final pullResult = await ref
            .read(certificateRepositoryProvider)
            .pullCertificatesFromRemote(technicianId);
        await errorLog.markResolved('pull_certificates');
        final parts = <String>[];
        if (pullResult.added > 0) parts.add('${pullResult.added} added');
        if (pullResult.deletedIds.isNotEmpty) {
          parts.add(
            '${pullResult.deletedIds.length} deleted '
            '(IDs: ${pullResult.deletedIds.join(', ')})',
          );
        }
        await syncRemote.postSyncLog(
          operation: 'pull_certificates',
          entity: 'test_certificates',
          rowCount: pullResult.added + pullResult.deletedIds.length,
          status: 'success',
          message: parts.isEmpty ? 'No changes' : parts.join(', '),
        );
      } on Exception catch (e, st) {
        await errorLog.logError(
          operation: 'pull_certificates',
          entityTable: 'test_certificates',
          errorMessage: e.toString(),
          stackTrace: st.toString(),
        );
        await syncRemote.postSyncLog(
          operation: 'pull_certificates',
          entity: 'test_certificates',
          rowCount: 0,
          status: 'error',
          message: e.toString(),
        );
      }
    }

    state = SyncComplete(DateTime.now());
    ref.invalidate(unresolvedSyncErrorCountProvider);
  }
}

// ── Badge count ───────────────────────────────────────────────────────────────

@riverpod
Future<int> unresolvedSyncErrorCount(Ref ref) =>
    ref.watch(syncErrorLogDataSourceProvider).unresolvedCount();

@riverpod
Future<List<SyncErrorEntry>> unresolvedSyncErrors(Ref ref) =>
    ref.watch(syncErrorLogDataSourceProvider).getUnresolvedErrors();

// ── Helpers ───────────────────────────────────────────────────────────────────

String _buildSyncMessage(
  int rowCount,
  int pageCount,
  List<int> removedIds,
  List<({int assetId, List<String> fields})> changes,
) {
  final pages = '$pageCount page${pageCount != 1 ? 's' : ''}';
  final buf = StringBuffer(
      'Synced $rowCount asset${rowCount != 1 ? 's' : ''} in $pages');
  if (removedIds.isNotEmpty) {
    buf.write(
        ', removed ${removedIds.length} deleted (IDs: ${removedIds.join(', ')})');
  }
  if (changes.isNotEmpty) {
    final fieldCounts = <String, int>{};
    for (final c in changes) {
      for (final f in c.fields) {
        fieldCounts[f] = (fieldCounts[f] ?? 0) + 1;
      }
    }
    final summary =
        fieldCounts.entries.map((e) => '${e.key} ×${e.value}').join(', ');
    buf.write(
        ', ${changes.length} record${changes.length != 1 ? 's' : ''} changed ($summary)');
  }
  return buf.toString();
}

String _friendlySyncError(Exception e) {
  final msg = e.toString().toLowerCase();
  if (msg.contains('401') || msg.contains('unauthorized')) {
    return 'Session expired. Please log in again.';
  }
  if (msg.contains('403') || msg.contains('forbidden')) {
    return 'Access denied. Contact your administrator.';
  }
  if (msg.contains('500') || msg.contains('server error')) {
    return 'Server error. Contact your system administrator.';
  }
  if (msg.contains('timeout')) {
    return 'Server not responding. Try again later.';
  }
  if (msg.contains('socket') ||
      msg.contains('connection refused') ||
      msg.contains('host lookup')) {
    return 'Cannot reach server. Check your Wi-Fi or mobile data.';
  }
  return 'Sync failed. Please try again.';
}
