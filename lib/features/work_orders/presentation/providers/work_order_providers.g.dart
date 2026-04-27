// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'work_order_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$databaseHelperHash() => r'1153a154ec3e7612e3c737d1898e7d3e4ddd369f';

/// See also [databaseHelper].
@ProviderFor(databaseHelper)
final databaseHelperProvider = AutoDisposeProvider<DatabaseHelper>.internal(
  databaseHelper,
  name: r'databaseHelperProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$databaseHelperHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DatabaseHelperRef = AutoDisposeProviderRef<DatabaseHelper>;
String _$woLocalDataSourceHash() => r'7f151e090ee77db0e09d66521ab5b64c8b1f9683';

/// See also [woLocalDataSource].
@ProviderFor(woLocalDataSource)
final woLocalDataSourceProvider =
    AutoDisposeProvider<WoLocalDataSource>.internal(
      woLocalDataSource,
      name: r'woLocalDataSourceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$woLocalDataSourceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef WoLocalDataSourceRef = AutoDisposeProviderRef<WoLocalDataSource>;
String _$woRemoteDataSourceHash() =>
    r'b93e0af4b2e264de61ca19bfbf5d5715c6a89ce0';

/// See also [woRemoteDataSource].
@ProviderFor(woRemoteDataSource)
final woRemoteDataSourceProvider =
    AutoDisposeProvider<WoRemoteDataSource>.internal(
      woRemoteDataSource,
      name: r'woRemoteDataSourceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$woRemoteDataSourceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef WoRemoteDataSourceRef = AutoDisposeProviderRef<WoRemoteDataSource>;
String _$workOrderRepositoryHash() =>
    r'48724ce0906a0b835c6a8a4931718b09a6db0bad';

/// See also [workOrderRepository].
@ProviderFor(workOrderRepository)
final workOrderRepositoryProvider =
    AutoDisposeProvider<WorkOrderRepository>.internal(
      workOrderRepository,
      name: r'workOrderRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$workOrderRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef WorkOrderRepositoryRef = AutoDisposeProviderRef<WorkOrderRepository>;
String _$assetLocalDataSourceHash() =>
    r'c6c1ad63ce9d02c19b2dec1634e430fd2ff9ee5a';

/// See also [assetLocalDataSource].
@ProviderFor(assetLocalDataSource)
final assetLocalDataSourceProvider =
    AutoDisposeProvider<AssetLocalDataSource>.internal(
      assetLocalDataSource,
      name: r'assetLocalDataSourceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$assetLocalDataSourceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AssetLocalDataSourceRef = AutoDisposeProviderRef<AssetLocalDataSource>;
String _$workOrderDetailHash() => r'dd8bd15adf8496028a5932ee1e0c73308799605b';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [workOrderDetail].
@ProviderFor(workOrderDetail)
const workOrderDetailProvider = WorkOrderDetailFamily();

/// See also [workOrderDetail].
class WorkOrderDetailFamily extends Family<AsyncValue<WorkOrder?>> {
  /// See also [workOrderDetail].
  const WorkOrderDetailFamily();

  /// See also [workOrderDetail].
  WorkOrderDetailProvider call(int id) {
    return WorkOrderDetailProvider(id);
  }

  @override
  WorkOrderDetailProvider getProviderOverride(
    covariant WorkOrderDetailProvider provider,
  ) {
    return call(provider.id);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'workOrderDetailProvider';
}

/// See also [workOrderDetail].
class WorkOrderDetailProvider extends AutoDisposeFutureProvider<WorkOrder?> {
  /// See also [workOrderDetail].
  WorkOrderDetailProvider(int id)
    : this._internal(
        (ref) => workOrderDetail(ref as WorkOrderDetailRef, id),
        from: workOrderDetailProvider,
        name: r'workOrderDetailProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$workOrderDetailHash,
        dependencies: WorkOrderDetailFamily._dependencies,
        allTransitiveDependencies:
            WorkOrderDetailFamily._allTransitiveDependencies,
        id: id,
      );

  WorkOrderDetailProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
  }) : super.internal();

  final int id;

  @override
  Override overrideWith(
    FutureOr<WorkOrder?> Function(WorkOrderDetailRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: WorkOrderDetailProvider._internal(
        (ref) => create(ref as WorkOrderDetailRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<WorkOrder?> createElement() {
    return _WorkOrderDetailProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkOrderDetailProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin WorkOrderDetailRef on AutoDisposeFutureProviderRef<WorkOrder?> {
  /// The parameter `id` of this provider.
  int get id;
}

class _WorkOrderDetailProviderElement
    extends AutoDisposeFutureProviderElement<WorkOrder?>
    with WorkOrderDetailRef {
  _WorkOrderDetailProviderElement(super.provider);

  @override
  int get id => (origin as WorkOrderDetailProvider).id;
}

String _$workOrderStatusHistoryHash() =>
    r'8397eebd5114d11768845d323b2bf7bf76317f20';

/// See also [workOrderStatusHistory].
@ProviderFor(workOrderStatusHistory)
const workOrderStatusHistoryProvider = WorkOrderStatusHistoryFamily();

/// See also [workOrderStatusHistory].
class WorkOrderStatusHistoryFamily
    extends Family<AsyncValue<List<WorkOrderStatusHistory>>> {
  /// See also [workOrderStatusHistory].
  const WorkOrderStatusHistoryFamily();

  /// See also [workOrderStatusHistory].
  WorkOrderStatusHistoryProvider call(int workOrderId) {
    return WorkOrderStatusHistoryProvider(workOrderId);
  }

  @override
  WorkOrderStatusHistoryProvider getProviderOverride(
    covariant WorkOrderStatusHistoryProvider provider,
  ) {
    return call(provider.workOrderId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'workOrderStatusHistoryProvider';
}

/// See also [workOrderStatusHistory].
class WorkOrderStatusHistoryProvider
    extends AutoDisposeFutureProvider<List<WorkOrderStatusHistory>> {
  /// See also [workOrderStatusHistory].
  WorkOrderStatusHistoryProvider(int workOrderId)
    : this._internal(
        (ref) => workOrderStatusHistory(
          ref as WorkOrderStatusHistoryRef,
          workOrderId,
        ),
        from: workOrderStatusHistoryProvider,
        name: r'workOrderStatusHistoryProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$workOrderStatusHistoryHash,
        dependencies: WorkOrderStatusHistoryFamily._dependencies,
        allTransitiveDependencies:
            WorkOrderStatusHistoryFamily._allTransitiveDependencies,
        workOrderId: workOrderId,
      );

  WorkOrderStatusHistoryProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.workOrderId,
  }) : super.internal();

  final int workOrderId;

  @override
  Override overrideWith(
    FutureOr<List<WorkOrderStatusHistory>> Function(
      WorkOrderStatusHistoryRef provider,
    )
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: WorkOrderStatusHistoryProvider._internal(
        (ref) => create(ref as WorkOrderStatusHistoryRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        workOrderId: workOrderId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<WorkOrderStatusHistory>>
  createElement() {
    return _WorkOrderStatusHistoryProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkOrderStatusHistoryProvider &&
        other.workOrderId == workOrderId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, workOrderId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin WorkOrderStatusHistoryRef
    on AutoDisposeFutureProviderRef<List<WorkOrderStatusHistory>> {
  /// The parameter `workOrderId` of this provider.
  int get workOrderId;
}

class _WorkOrderStatusHistoryProviderElement
    extends AutoDisposeFutureProviderElement<List<WorkOrderStatusHistory>>
    with WorkOrderStatusHistoryRef {
  _WorkOrderStatusHistoryProviderElement(super.provider);

  @override
  int get workOrderId => (origin as WorkOrderStatusHistoryProvider).workOrderId;
}

String _$todaysWorkOrdersHash() => r'1854b5b02812f81c48e0e7ee158d74bbe7891fbd';

/// See also [TodaysWorkOrders].
@ProviderFor(TodaysWorkOrders)
final todaysWorkOrdersProvider =
    AutoDisposeAsyncNotifierProvider<
      TodaysWorkOrders,
      List<WorkOrder>
    >.internal(
      TodaysWorkOrders.new,
      name: r'todaysWorkOrdersProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$todaysWorkOrdersHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$TodaysWorkOrders = AutoDisposeAsyncNotifier<List<WorkOrder>>;
String _$workOrderActionsHash() => r'e9aec4c7209f633ae7a80e4167d3a060c5b50de2';

/// See also [WorkOrderActions].
@ProviderFor(WorkOrderActions)
final workOrderActionsProvider =
    AutoDisposeNotifierProvider<WorkOrderActions, AsyncValue<void>>.internal(
      WorkOrderActions.new,
      name: r'workOrderActionsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$workOrderActionsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$WorkOrderActions = AutoDisposeNotifier<AsyncValue<void>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
