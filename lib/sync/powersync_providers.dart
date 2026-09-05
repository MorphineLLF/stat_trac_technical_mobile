import 'package:powersync/powersync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/auth/presentation/providers/auth_providers.dart';
import 'powersync_database.dart';
import 'stat_trac_connector.dart';

part 'powersync_providers.g.dart';

/// The connector PowerSync calls for credentials.
@riverpod
StatTracConnector statTracConnector(Ref ref) {
  return StatTracConnector(
    local: ref.watch(authLocalDataSourceProvider),
    syncTokens: ref.watch(syncTokenRemoteDataSourceProvider),
  );
}

/// The device's sync database, opened and connected.
///
/// Kept alive for the process: opening is expensive, and closing it would
/// drop the stream a technician depends on. It stays connected while the app
/// is backgrounded, which is how work queued offline drains as soon as signal
/// returns.
///
/// [StatTracConnector.fetchCredentials] returns null until sign-in, so calling
/// this before the technician has logged in is safe — PowerSync simply waits
/// rather than erroring.
@Riverpod(keepAlive: true)
Future<PowerSyncDatabase> syncDatabase(Ref ref) async {
  final db = await openSyncDatabase();
  await db.connect(connector: ref.watch(statTracConnectorProvider));
  ref.onDispose(db.close);
  return db;
}

/// Live sync status — connection state, last synced time, upload queue depth.
///
/// This is what the dashboard's status label binds to, replacing the
/// hand-rolled SyncNotifier state.
@riverpod
Stream<SyncStatus> syncStatus(Ref ref) async* {
  final db = await ref.watch(syncDatabaseProvider.future);
  yield db.currentStatus;
  yield* db.statusStream;
}
