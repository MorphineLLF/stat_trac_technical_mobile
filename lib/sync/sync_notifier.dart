import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api/auth_interceptor.dart';
import '../api/dio_client.dart';
import '../database/database_helper.dart';
import '../features/assets/presentation/providers/asset_providers.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import 'sync_error_log_data_source.dart';
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

    state = const SyncInProgress();

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

    try {
      final result = await ref.read(assetRepositoryProvider).syncAssets();

      final message = _buildSyncMessage(
          result.rowCount, result.pageCount, result.removedIds);
      await syncRemote.postSyncLog(
        entity: 'assets',
        rowCount: result.rowCount,
        status: 'success',
        message: message,
      );

      await errorLog.markResolved('sync_assets');
      state = SyncComplete(DateTime.now());
      ref.invalidate(unresolvedSyncErrorCountProvider);
    } on Exception catch (e, st) {
      await errorLog.logError(
        operation: 'sync_assets',
        entityTable: 'assets',
        errorMessage: e.toString(),
        stackTrace: st.toString(),
      );
      state = SyncError(
        message: _friendlySyncError(e),
        lastSyncedAt: previousSuccess,
      );
      ref.invalidate(unresolvedSyncErrorCountProvider);
    }
  }
}

// ── Badge count ───────────────────────────────────────────────────────────────

@riverpod
Future<int> unresolvedSyncErrorCount(Ref ref) =>
    ref.watch(syncErrorLogDataSourceProvider).unresolvedCount();

// ── Helpers ───────────────────────────────────────────────────────────────────

String _buildSyncMessage(int rowCount, int pageCount, List<int> removedIds) {
  final pages = '$pageCount page${pageCount != 1 ? 's' : ''}';
  final base = 'Synced $rowCount asset${rowCount != 1 ? 's' : ''} in $pages';
  if (removedIds.isEmpty) return base;
  return '$base, removed ${removedIds.length} deleted (IDs: ${removedIds.join(', ')})';
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
