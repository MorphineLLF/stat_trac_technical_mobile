// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'powersync_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The connector PowerSync calls for credentials.

@ProviderFor(statTracConnector)
final statTracConnectorProvider = StatTracConnectorProvider._();

/// The connector PowerSync calls for credentials.

final class StatTracConnectorProvider
    extends
        $FunctionalProvider<
          StatTracConnector,
          StatTracConnector,
          StatTracConnector
        >
    with $Provider<StatTracConnector> {
  /// The connector PowerSync calls for credentials.
  StatTracConnectorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'statTracConnectorProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$statTracConnectorHash();

  @$internal
  @override
  $ProviderElement<StatTracConnector> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  StatTracConnector create(Ref ref) {
    return statTracConnector(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StatTracConnector value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StatTracConnector>(value),
    );
  }
}

String _$statTracConnectorHash() => r'c8f36518a74b2b5025a635897c3ed08c55d9bbe0';

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

@ProviderFor(syncDatabase)
final syncDatabaseProvider = SyncDatabaseProvider._();

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

final class SyncDatabaseProvider
    extends
        $FunctionalProvider<
          AsyncValue<PowerSyncDatabase>,
          PowerSyncDatabase,
          FutureOr<PowerSyncDatabase>
        >
    with
        $FutureModifier<PowerSyncDatabase>,
        $FutureProvider<PowerSyncDatabase> {
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
  SyncDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncDatabaseHash();

  @$internal
  @override
  $FutureProviderElement<PowerSyncDatabase> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PowerSyncDatabase> create(Ref ref) {
    return syncDatabase(ref);
  }
}

String _$syncDatabaseHash() => r'9c7a2bb1c982a35db67b537801d44f08375f8ccb';

/// Live sync status — connection state, last synced time, upload queue depth.
///
/// This is what the dashboard's status label binds to, replacing the
/// hand-rolled SyncNotifier state.

@ProviderFor(syncStatus)
final syncStatusProvider = SyncStatusProvider._();

/// Live sync status — connection state, last synced time, upload queue depth.
///
/// This is what the dashboard's status label binds to, replacing the
/// hand-rolled SyncNotifier state.

final class SyncStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<SyncStatus>,
          SyncStatus,
          Stream<SyncStatus>
        >
    with $FutureModifier<SyncStatus>, $StreamProvider<SyncStatus> {
  /// Live sync status — connection state, last synced time, upload queue depth.
  ///
  /// This is what the dashboard's status label binds to, replacing the
  /// hand-rolled SyncNotifier state.
  SyncStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncStatusProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncStatusHash();

  @$internal
  @override
  $StreamProviderElement<SyncStatus> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<SyncStatus> create(Ref ref) {
    return syncStatus(ref);
  }
}

String _$syncStatusHash() => r'bbc021068e2571cec657047e48947ed61d895923';
