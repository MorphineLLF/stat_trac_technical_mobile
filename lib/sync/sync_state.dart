import 'package:flutter/foundation.dart';

sealed class SyncState {
  const SyncState();
}

@immutable
class SyncIdle extends SyncState {
  const SyncIdle();
}

@immutable
class SyncInProgress extends SyncState {
  const SyncInProgress();
}

@immutable
class SyncComplete extends SyncState {
  const SyncComplete(this.lastSyncedAt);
  final DateTime lastSyncedAt;
}

@immutable
class SyncError extends SyncState {
  const SyncError({required this.message, this.lastSyncedAt});
  final String message;

  /// Retained from the previous successful sync so the UI can still show it.
  final DateTime? lastSyncedAt;
}
