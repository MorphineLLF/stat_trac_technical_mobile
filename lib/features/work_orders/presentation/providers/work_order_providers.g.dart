// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'work_order_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(databaseHelper)
final databaseHelperProvider = DatabaseHelperProvider._();

final class DatabaseHelperProvider
    extends $FunctionalProvider<DatabaseHelper, DatabaseHelper, DatabaseHelper>
    with $Provider<DatabaseHelper> {
  DatabaseHelperProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'databaseHelperProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$databaseHelperHash();

  @$internal
  @override
  $ProviderElement<DatabaseHelper> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DatabaseHelper create(Ref ref) {
    return databaseHelper(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DatabaseHelper value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DatabaseHelper>(value),
    );
  }
}

String _$databaseHelperHash() => r'1153a154ec3e7612e3c737d1898e7d3e4ddd369f';

@ProviderFor(woLocalDataSource)
final woLocalDataSourceProvider = WoLocalDataSourceProvider._();

final class WoLocalDataSourceProvider
    extends
        $FunctionalProvider<
          WoLocalDataSource,
          WoLocalDataSource,
          WoLocalDataSource
        >
    with $Provider<WoLocalDataSource> {
  WoLocalDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'woLocalDataSourceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$woLocalDataSourceHash();

  @$internal
  @override
  $ProviderElement<WoLocalDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WoLocalDataSource create(Ref ref) {
    return woLocalDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WoLocalDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WoLocalDataSource>(value),
    );
  }
}

String _$woLocalDataSourceHash() => r'7f151e090ee77db0e09d66521ab5b64c8b1f9683';

@ProviderFor(woRemoteDataSource)
final woRemoteDataSourceProvider = WoRemoteDataSourceProvider._();

final class WoRemoteDataSourceProvider
    extends
        $FunctionalProvider<
          WoRemoteDataSource,
          WoRemoteDataSource,
          WoRemoteDataSource
        >
    with $Provider<WoRemoteDataSource> {
  WoRemoteDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'woRemoteDataSourceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$woRemoteDataSourceHash();

  @$internal
  @override
  $ProviderElement<WoRemoteDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WoRemoteDataSource create(Ref ref) {
    return woRemoteDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WoRemoteDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WoRemoteDataSource>(value),
    );
  }
}

String _$woRemoteDataSourceHash() =>
    r'b93e0af4b2e264de61ca19bfbf5d5715c6a89ce0';

@ProviderFor(workOrderRepository)
final workOrderRepositoryProvider = WorkOrderRepositoryProvider._();

final class WorkOrderRepositoryProvider
    extends
        $FunctionalProvider<
          WorkOrderRepository,
          WorkOrderRepository,
          WorkOrderRepository
        >
    with $Provider<WorkOrderRepository> {
  WorkOrderRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workOrderRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workOrderRepositoryHash();

  @$internal
  @override
  $ProviderElement<WorkOrderRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WorkOrderRepository create(Ref ref) {
    return workOrderRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkOrderRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkOrderRepository>(value),
    );
  }
}

String _$workOrderRepositoryHash() =>
    r'48724ce0906a0b835c6a8a4931718b09a6db0bad';

@ProviderFor(assetLocalDataSource)
final assetLocalDataSourceProvider = AssetLocalDataSourceProvider._();

final class AssetLocalDataSourceProvider
    extends
        $FunctionalProvider<
          AssetLocalDataSource,
          AssetLocalDataSource,
          AssetLocalDataSource
        >
    with $Provider<AssetLocalDataSource> {
  AssetLocalDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'assetLocalDataSourceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$assetLocalDataSourceHash();

  @$internal
  @override
  $ProviderElement<AssetLocalDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AssetLocalDataSource create(Ref ref) {
    return assetLocalDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AssetLocalDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AssetLocalDataSource>(value),
    );
  }
}

String _$assetLocalDataSourceHash() =>
    r'c6c1ad63ce9d02c19b2dec1634e430fd2ff9ee5a';

@ProviderFor(TodaysWorkOrders)
final todaysWorkOrdersProvider = TodaysWorkOrdersProvider._();

final class TodaysWorkOrdersProvider
    extends $AsyncNotifierProvider<TodaysWorkOrders, List<WorkOrder>> {
  TodaysWorkOrdersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'todaysWorkOrdersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$todaysWorkOrdersHash();

  @$internal
  @override
  TodaysWorkOrders create() => TodaysWorkOrders();
}

String _$todaysWorkOrdersHash() => r'b9e7de1c405e702b82fac7f34506cad76513f5be';

abstract class _$TodaysWorkOrders extends $AsyncNotifier<List<WorkOrder>> {
  FutureOr<List<WorkOrder>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<WorkOrder>>, List<WorkOrder>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<WorkOrder>>, List<WorkOrder>>,
              AsyncValue<List<WorkOrder>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(workOrderDetail)
final workOrderDetailProvider = WorkOrderDetailFamily._();

final class WorkOrderDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<WorkOrder?>,
          WorkOrder?,
          FutureOr<WorkOrder?>
        >
    with $FutureModifier<WorkOrder?>, $FutureProvider<WorkOrder?> {
  WorkOrderDetailProvider._({
    required WorkOrderDetailFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'workOrderDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workOrderDetailHash();

  @override
  String toString() {
    return r'workOrderDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<WorkOrder?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<WorkOrder?> create(Ref ref) {
    final argument = this.argument as int;
    return workOrderDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkOrderDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workOrderDetailHash() => r'dd8bd15adf8496028a5932ee1e0c73308799605b';

final class WorkOrderDetailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<WorkOrder?>, int> {
  WorkOrderDetailFamily._()
    : super(
        retry: null,
        name: r'workOrderDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  WorkOrderDetailProvider call(int id) =>
      WorkOrderDetailProvider._(argument: id, from: this);

  @override
  String toString() => r'workOrderDetailProvider';
}

@ProviderFor(workOrderStatusHistory)
final workOrderStatusHistoryProvider = WorkOrderStatusHistoryFamily._();

final class WorkOrderStatusHistoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<WorkOrderStatusHistory>>,
          List<WorkOrderStatusHistory>,
          FutureOr<List<WorkOrderStatusHistory>>
        >
    with
        $FutureModifier<List<WorkOrderStatusHistory>>,
        $FutureProvider<List<WorkOrderStatusHistory>> {
  WorkOrderStatusHistoryProvider._({
    required WorkOrderStatusHistoryFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'workOrderStatusHistoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workOrderStatusHistoryHash();

  @override
  String toString() {
    return r'workOrderStatusHistoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<WorkOrderStatusHistory>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<WorkOrderStatusHistory>> create(Ref ref) {
    final argument = this.argument as int;
    return workOrderStatusHistory(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkOrderStatusHistoryProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workOrderStatusHistoryHash() =>
    r'8397eebd5114d11768845d323b2bf7bf76317f20';

final class WorkOrderStatusHistoryFamily extends $Family
    with
        $FunctionalFamilyOverride<FutureOr<List<WorkOrderStatusHistory>>, int> {
  WorkOrderStatusHistoryFamily._()
    : super(
        retry: null,
        name: r'workOrderStatusHistoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  WorkOrderStatusHistoryProvider call(int workOrderId) =>
      WorkOrderStatusHistoryProvider._(argument: workOrderId, from: this);

  @override
  String toString() => r'workOrderStatusHistoryProvider';
}

@ProviderFor(WorkOrderActions)
final workOrderActionsProvider = WorkOrderActionsProvider._();

final class WorkOrderActionsProvider
    extends $NotifierProvider<WorkOrderActions, AsyncValue<void>> {
  WorkOrderActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workOrderActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workOrderActionsHash();

  @$internal
  @override
  WorkOrderActions create() => WorkOrderActions();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<void> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<void>>(value),
    );
  }
}

String _$workOrderActionsHash() => r'e9aec4c7209f633ae7a80e4167d3a060c5b50de2';

abstract class _$WorkOrderActions extends $Notifier<AsyncValue<void>> {
  AsyncValue<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, AsyncValue<void>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, AsyncValue<void>>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
