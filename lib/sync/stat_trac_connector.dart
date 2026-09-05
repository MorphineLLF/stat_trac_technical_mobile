import 'package:powersync/powersync.dart';

import '../features/auth/data/datasources/auth_local_data_source.dart';
import '../features/auth/data/datasources/sync_token_remote_data_source.dart';

/// Connects PowerSync to the Go application.
///
/// Credentials come from the two-step chain: the stored ninety-day device
/// token is exchanged for a one-hour sync JWT. When PowerSync reports the sync
/// token expired it calls back here, and the exchange runs again — an expiry
/// costs a round trip, never a password prompt.
class StatTracConnector extends PowerSyncBackendConnector {
  StatTracConnector({
    required AuthLocalDataSource local,
    required SyncTokenRemoteDataSource syncTokens,
  }) : _local = local,
       _syncTokens = syncTokens;

  final AuthLocalDataSource _local;
  final SyncTokenRemoteDataSource _syncTokens;

  /// Null means "not signed in" and stops PowerSync retrying. A network or
  /// server failure must throw instead, so it is retried — reporting a
  /// temporary outage as a sign-out would silently stop syncing.
  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    final deviceToken = await _local.readDeviceToken();
    final company = await _local.readDbName();

    if (deviceToken == null || company == null || company.isEmpty) {
      return null;
    }
    if (!DateTime.now().toUtc().isBefore(deviceToken.expiresAt)) {
      return null;
    }

    final credentials = await _syncTokens.fetchSyncCredentials(
      company: company,
      deviceToken: deviceToken.token,
    );

    return PowerSyncCredentials(
      // The endpoint travels with the token deliberately, so the sync service
      // can move without an app release. Never substitute a constant.
      endpoint: credentials.endpoint,
      token: credentials.token,
      // Carried as a string: sync rules compare the subject as text and a
      // cast inside a rule is refused.
      userId: credentials.userId.toString(),
      expiresAt: credentials.expiresAt,
    );
  }

  /// Uploads are not enabled yet.
  ///
  /// The server's write endpoint covers the rep entities only — work orders
  /// and certificates are still to be built — and this app's synced tables are
  /// read-only on the device, because server-assigned integer primary keys
  /// mean a row's final id is not known at creation. Field writes go to the
  /// app's own outbox (`ChangeLogEntry`) instead, and this method will drive
  /// that outbox once the endpoint exists.
  ///
  /// So PowerSync's own queue should always be empty. If it is not, something
  /// wrote directly to a synced table. Throwing keeps the change queued and
  /// makes the mistake visible; completing the transaction would discard a
  /// technician's work silently.
  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final batch = await database.getCrudBatch();
    if (batch == null) return;

    throw StateError(
      'PowerSync upload queue is not empty (${batch.crud.length} pending). '
      'Synced tables are read-only on the device until the server write '
      'endpoint exists; field writes belong in the ChangeLogEntry outbox.',
    );
  }
}
