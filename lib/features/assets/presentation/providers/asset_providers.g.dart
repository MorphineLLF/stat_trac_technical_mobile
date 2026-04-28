// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asset_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(assetRemoteDataSource)
final assetRemoteDataSourceProvider = AssetRemoteDataSourceProvider._();

final class AssetRemoteDataSourceProvider
    extends
        $FunctionalProvider<
          AssetRemoteDataSource,
          AssetRemoteDataSource,
          AssetRemoteDataSource
        >
    with $Provider<AssetRemoteDataSource> {
  AssetRemoteDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'assetRemoteDataSourceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$assetRemoteDataSourceHash();

  @$internal
  @override
  $ProviderElement<AssetRemoteDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AssetRemoteDataSource create(Ref ref) {
    return assetRemoteDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AssetRemoteDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AssetRemoteDataSource>(value),
    );
  }
}

String _$assetRemoteDataSourceHash() =>
    r'17c28287296ca428eb4e71377ea3ad7414c34c37';

@ProviderFor(assetRepository)
final assetRepositoryProvider = AssetRepositoryProvider._();

final class AssetRepositoryProvider
    extends
        $FunctionalProvider<AssetRepository, AssetRepository, AssetRepository>
    with $Provider<AssetRepository> {
  AssetRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'assetRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$assetRepositoryHash();

  @$internal
  @override
  $ProviderElement<AssetRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AssetRepository create(Ref ref) {
    return assetRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AssetRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AssetRepository>(value),
    );
  }
}

String _$assetRepositoryHash() => r'536144d54b50f51d47dcc572a85580a3870c2c31';

@ProviderFor(assets)
final assetsProvider = AssetsFamily._();

final class AssetsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Asset>>,
          List<Asset>,
          FutureOr<List<Asset>>
        >
    with $FutureModifier<List<Asset>>, $FutureProvider<List<Asset>> {
  AssetsProvider._({
    required AssetsFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'assetsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$assetsHash();

  @override
  String toString() {
    return r'assetsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<Asset>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Asset>> create(Ref ref) {
    final argument = this.argument as String?;
    return assets(ref, hospital: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AssetsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$assetsHash() => r'afd048529c2e7f27ab5f7e43ddabecd174de4094';

final class AssetsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<Asset>>, String?> {
  AssetsFamily._()
    : super(
        retry: null,
        name: r'assetsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AssetsProvider call({String? hospital}) =>
      AssetsProvider._(argument: hospital, from: this);

  @override
  String toString() => r'assetsProvider';
}

@ProviderFor(hospitalList)
final hospitalListProvider = HospitalListProvider._();

final class HospitalListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<String>>,
          List<String>,
          FutureOr<List<String>>
        >
    with $FutureModifier<List<String>>, $FutureProvider<List<String>> {
  HospitalListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hospitalListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hospitalListHash();

  @$internal
  @override
  $FutureProviderElement<List<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<String>> create(Ref ref) {
    return hospitalList(ref);
  }
}

String _$hospitalListHash() => r'677cf2992d954546d6f57ebcd5fbc9399ebad739';

@ProviderFor(assetSearch)
final assetSearchProvider = AssetSearchFamily._();

final class AssetSearchProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Asset>>,
          List<Asset>,
          FutureOr<List<Asset>>
        >
    with $FutureModifier<List<Asset>>, $FutureProvider<List<Asset>> {
  AssetSearchProvider._({
    required AssetSearchFamily super.from,
    required (String, {String? hospital}) super.argument,
  }) : super(
         retry: null,
         name: r'assetSearchProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$assetSearchHash();

  @override
  String toString() {
    return r'assetSearchProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<Asset>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Asset>> create(Ref ref) {
    final argument = this.argument as (String, {String? hospital});
    return assetSearch(ref, argument.$1, hospital: argument.hospital);
  }

  @override
  bool operator ==(Object other) {
    return other is AssetSearchProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$assetSearchHash() => r'efdf5bfafd0ccf45aa662e6d57caf42064fd02eb';

final class AssetSearchFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<Asset>>,
          (String, {String? hospital})
        > {
  AssetSearchFamily._()
    : super(
        retry: null,
        name: r'assetSearchProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AssetSearchProvider call(String query, {String? hospital}) =>
      AssetSearchProvider._(argument: (query, hospital: hospital), from: this);

  @override
  String toString() => r'assetSearchProvider';
}

@ProviderFor(assetStats)
final assetStatsProvider = AssetStatsProvider._();

final class AssetStatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<AssetStats>,
          AssetStats,
          FutureOr<AssetStats>
        >
    with $FutureModifier<AssetStats>, $FutureProvider<AssetStats> {
  AssetStatsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'assetStatsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$assetStatsHash();

  @$internal
  @override
  $FutureProviderElement<AssetStats> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<AssetStats> create(Ref ref) {
    return assetStats(ref);
  }
}

String _$assetStatsHash() => r'bf665768ce66596b4aa8694e0850de09dae3360e';

@ProviderFor(assetDetail)
final assetDetailProvider = AssetDetailFamily._();

final class AssetDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<AssetDetail>,
          AssetDetail,
          FutureOr<AssetDetail>
        >
    with $FutureModifier<AssetDetail>, $FutureProvider<AssetDetail> {
  AssetDetailProvider._({
    required AssetDetailFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'assetDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$assetDetailHash();

  @override
  String toString() {
    return r'assetDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<AssetDetail> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AssetDetail> create(Ref ref) {
    final argument = this.argument as int;
    return assetDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AssetDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$assetDetailHash() => r'7ca85aed7f7e091dea4effbc8ff8f1f4600eda8f';

final class AssetDetailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<AssetDetail>, int> {
  AssetDetailFamily._()
    : super(
        retry: null,
        name: r'assetDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AssetDetailProvider call(int assetId) =>
      AssetDetailProvider._(argument: assetId, from: this);

  @override
  String toString() => r'assetDetailProvider';
}
