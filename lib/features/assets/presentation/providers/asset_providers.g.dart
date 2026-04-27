// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asset_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$assetRemoteDataSourceHash() =>
    r'17c28287296ca428eb4e71377ea3ad7414c34c37';

/// See also [assetRemoteDataSource].
@ProviderFor(assetRemoteDataSource)
final assetRemoteDataSourceProvider =
    AutoDisposeProvider<AssetRemoteDataSource>.internal(
      assetRemoteDataSource,
      name: r'assetRemoteDataSourceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$assetRemoteDataSourceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AssetRemoteDataSourceRef =
    AutoDisposeProviderRef<AssetRemoteDataSource>;
String _$assetRepositoryHash() => r'536144d54b50f51d47dcc572a85580a3870c2c31';

/// See also [assetRepository].
@ProviderFor(assetRepository)
final assetRepositoryProvider = AutoDisposeProvider<AssetRepository>.internal(
  assetRepository,
  name: r'assetRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$assetRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AssetRepositoryRef = AutoDisposeProviderRef<AssetRepository>;
String _$assetsHash() => r'afd048529c2e7f27ab5f7e43ddabecd174de4094';

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

/// See also [assets].
@ProviderFor(assets)
const assetsProvider = AssetsFamily();

/// See also [assets].
class AssetsFamily extends Family<AsyncValue<List<Asset>>> {
  /// See also [assets].
  const AssetsFamily();

  /// See also [assets].
  AssetsProvider call({String? hospital}) {
    return AssetsProvider(hospital: hospital);
  }

  @override
  AssetsProvider getProviderOverride(covariant AssetsProvider provider) {
    return call(hospital: provider.hospital);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'assetsProvider';
}

/// See also [assets].
class AssetsProvider extends AutoDisposeFutureProvider<List<Asset>> {
  /// See also [assets].
  AssetsProvider({String? hospital})
    : this._internal(
        (ref) => assets(ref as AssetsRef, hospital: hospital),
        from: assetsProvider,
        name: r'assetsProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$assetsHash,
        dependencies: AssetsFamily._dependencies,
        allTransitiveDependencies: AssetsFamily._allTransitiveDependencies,
        hospital: hospital,
      );

  AssetsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.hospital,
  }) : super.internal();

  final String? hospital;

  @override
  Override overrideWith(
    FutureOr<List<Asset>> Function(AssetsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: AssetsProvider._internal(
        (ref) => create(ref as AssetsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        hospital: hospital,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<Asset>> createElement() {
    return _AssetsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AssetsProvider && other.hospital == hospital;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, hospital.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin AssetsRef on AutoDisposeFutureProviderRef<List<Asset>> {
  /// The parameter `hospital` of this provider.
  String? get hospital;
}

class _AssetsProviderElement
    extends AutoDisposeFutureProviderElement<List<Asset>>
    with AssetsRef {
  _AssetsProviderElement(super.provider);

  @override
  String? get hospital => (origin as AssetsProvider).hospital;
}

String _$hospitalListHash() => r'677cf2992d954546d6f57ebcd5fbc9399ebad739';

/// See also [hospitalList].
@ProviderFor(hospitalList)
final hospitalListProvider = AutoDisposeFutureProvider<List<String>>.internal(
  hospitalList,
  name: r'hospitalListProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$hospitalListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef HospitalListRef = AutoDisposeFutureProviderRef<List<String>>;
String _$assetSearchHash() => r'efdf5bfafd0ccf45aa662e6d57caf42064fd02eb';

/// See also [assetSearch].
@ProviderFor(assetSearch)
const assetSearchProvider = AssetSearchFamily();

/// See also [assetSearch].
class AssetSearchFamily extends Family<AsyncValue<List<Asset>>> {
  /// See also [assetSearch].
  const AssetSearchFamily();

  /// See also [assetSearch].
  AssetSearchProvider call(String query, {String? hospital}) {
    return AssetSearchProvider(query, hospital: hospital);
  }

  @override
  AssetSearchProvider getProviderOverride(
    covariant AssetSearchProvider provider,
  ) {
    return call(provider.query, hospital: provider.hospital);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'assetSearchProvider';
}

/// See also [assetSearch].
class AssetSearchProvider extends AutoDisposeFutureProvider<List<Asset>> {
  /// See also [assetSearch].
  AssetSearchProvider(String query, {String? hospital})
    : this._internal(
        (ref) => assetSearch(ref as AssetSearchRef, query, hospital: hospital),
        from: assetSearchProvider,
        name: r'assetSearchProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$assetSearchHash,
        dependencies: AssetSearchFamily._dependencies,
        allTransitiveDependencies: AssetSearchFamily._allTransitiveDependencies,
        query: query,
        hospital: hospital,
      );

  AssetSearchProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.query,
    required this.hospital,
  }) : super.internal();

  final String query;
  final String? hospital;

  @override
  Override overrideWith(
    FutureOr<List<Asset>> Function(AssetSearchRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: AssetSearchProvider._internal(
        (ref) => create(ref as AssetSearchRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        query: query,
        hospital: hospital,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<Asset>> createElement() {
    return _AssetSearchProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AssetSearchProvider &&
        other.query == query &&
        other.hospital == hospital;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, query.hashCode);
    hash = _SystemHash.combine(hash, hospital.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin AssetSearchRef on AutoDisposeFutureProviderRef<List<Asset>> {
  /// The parameter `query` of this provider.
  String get query;

  /// The parameter `hospital` of this provider.
  String? get hospital;
}

class _AssetSearchProviderElement
    extends AutoDisposeFutureProviderElement<List<Asset>>
    with AssetSearchRef {
  _AssetSearchProviderElement(super.provider);

  @override
  String get query => (origin as AssetSearchProvider).query;
  @override
  String? get hospital => (origin as AssetSearchProvider).hospital;
}

String _$assetStatsHash() => r'bf665768ce66596b4aa8694e0850de09dae3360e';

/// See also [assetStats].
@ProviderFor(assetStats)
final assetStatsProvider = AutoDisposeFutureProvider<AssetStats>.internal(
  assetStats,
  name: r'assetStatsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$assetStatsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AssetStatsRef = AutoDisposeFutureProviderRef<AssetStats>;
String _$assetDetailHash() => r'7ca85aed7f7e091dea4effbc8ff8f1f4600eda8f';

/// See also [assetDetail].
@ProviderFor(assetDetail)
const assetDetailProvider = AssetDetailFamily();

/// See also [assetDetail].
class AssetDetailFamily extends Family<AsyncValue<AssetDetail>> {
  /// See also [assetDetail].
  const AssetDetailFamily();

  /// See also [assetDetail].
  AssetDetailProvider call(int assetId) {
    return AssetDetailProvider(assetId);
  }

  @override
  AssetDetailProvider getProviderOverride(
    covariant AssetDetailProvider provider,
  ) {
    return call(provider.assetId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'assetDetailProvider';
}

/// See also [assetDetail].
class AssetDetailProvider extends AutoDisposeFutureProvider<AssetDetail> {
  /// See also [assetDetail].
  AssetDetailProvider(int assetId)
    : this._internal(
        (ref) => assetDetail(ref as AssetDetailRef, assetId),
        from: assetDetailProvider,
        name: r'assetDetailProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$assetDetailHash,
        dependencies: AssetDetailFamily._dependencies,
        allTransitiveDependencies: AssetDetailFamily._allTransitiveDependencies,
        assetId: assetId,
      );

  AssetDetailProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.assetId,
  }) : super.internal();

  final int assetId;

  @override
  Override overrideWith(
    FutureOr<AssetDetail> Function(AssetDetailRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: AssetDetailProvider._internal(
        (ref) => create(ref as AssetDetailRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        assetId: assetId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<AssetDetail> createElement() {
    return _AssetDetailProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AssetDetailProvider && other.assetId == assetId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, assetId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin AssetDetailRef on AutoDisposeFutureProviderRef<AssetDetail> {
  /// The parameter `assetId` of this provider.
  int get assetId;
}

class _AssetDetailProviderElement
    extends AutoDisposeFutureProviderElement<AssetDetail>
    with AssetDetailRef {
  _AssetDetailProviderElement(super.provider);

  @override
  int get assetId => (origin as AssetDetailProvider).assetId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
