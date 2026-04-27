import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/assets/presentation/providers/asset_providers.dart';
import 'sync_state.dart';

part 'sync_notifier.g.dart';

@riverpod
class SyncNotifier extends _$SyncNotifier {
  @override
  SyncState build() => const SyncIdle();

  /// Called by connectivity listeners, foreground-resume hooks, and the
  /// 5-minute background scheduler (all wired in Phase 1).
  Future<void> triggerSync() async {
    if (state is SyncInProgress) return;

    final previousSuccess = switch (state) {
      SyncComplete(:final lastSyncedAt) => lastSyncedAt,
      SyncError(:final lastSyncedAt) => lastSyncedAt,
      _ => null,
    };

    state = const SyncInProgress();

    try {
      await ref.read(assetRepositoryProvider).syncAssets();
      state = SyncComplete(DateTime.now());
    } on Exception catch (e) {
      state = SyncError(
        message: e.toString(),
        lastSyncedAt: previousSuccess,
      );
    }
  }
}
