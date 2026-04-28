// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(syncErrorLogDataSource)
final syncErrorLogDataSourceProvider = SyncErrorLogDataSourceProvider._();

final class SyncErrorLogDataSourceProvider
    extends
        $FunctionalProvider<
          SyncErrorLogDataSource,
          SyncErrorLogDataSource,
          SyncErrorLogDataSource
        >
    with $Provider<SyncErrorLogDataSource> {
  SyncErrorLogDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncErrorLogDataSourceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncErrorLogDataSourceHash();

  @$internal
  @override
  $ProviderElement<SyncErrorLogDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SyncErrorLogDataSource create(Ref ref) {
    return syncErrorLogDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncErrorLogDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncErrorLogDataSource>(value),
    );
  }
}

String _$syncErrorLogDataSourceHash() =>
    r'c90ae9276b74192f928f14717e60b1f4ddadf187';

@ProviderFor(syncRemoteDataSource)
final syncRemoteDataSourceProvider = SyncRemoteDataSourceProvider._();

final class SyncRemoteDataSourceProvider
    extends
        $FunctionalProvider<
          SyncRemoteDataSource,
          SyncRemoteDataSource,
          SyncRemoteDataSource
        >
    with $Provider<SyncRemoteDataSource> {
  SyncRemoteDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncRemoteDataSourceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncRemoteDataSourceHash();

  @$internal
  @override
  $ProviderElement<SyncRemoteDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SyncRemoteDataSource create(Ref ref) {
    return syncRemoteDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncRemoteDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncRemoteDataSource>(value),
    );
  }
}

String _$syncRemoteDataSourceHash() =>
    r'd8382f8b869cbf86985558c15cd3196036b47703';

@ProviderFor(SyncNotifier)
final syncProvider = SyncNotifierProvider._();

final class SyncNotifierProvider
    extends $NotifierProvider<SyncNotifier, SyncState> {
  SyncNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncNotifierHash();

  @$internal
  @override
  SyncNotifier create() => SyncNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncState>(value),
    );
  }
}

String _$syncNotifierHash() => r'ca1dc9f8e66dffa9ffa0333be435e691453e2e3e';

abstract class _$SyncNotifier extends $Notifier<SyncState> {
  SyncState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<SyncState, SyncState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SyncState, SyncState>,
              SyncState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(unresolvedSyncErrorCount)
final unresolvedSyncErrorCountProvider = UnresolvedSyncErrorCountProvider._();

final class UnresolvedSyncErrorCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  UnresolvedSyncErrorCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'unresolvedSyncErrorCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$unresolvedSyncErrorCountHash();

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    return unresolvedSyncErrorCount(ref);
  }
}

String _$unresolvedSyncErrorCountHash() =>
    r'977ae39aacd5d9655d84f0bf12acbc699356a5f8';
