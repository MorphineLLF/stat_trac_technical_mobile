// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'certificate_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(certDatabaseHelper)
final certDatabaseHelperProvider = CertDatabaseHelperProvider._();

final class CertDatabaseHelperProvider
    extends $FunctionalProvider<DatabaseHelper, DatabaseHelper, DatabaseHelper>
    with $Provider<DatabaseHelper> {
  CertDatabaseHelperProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'certDatabaseHelperProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$certDatabaseHelperHash();

  @$internal
  @override
  $ProviderElement<DatabaseHelper> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DatabaseHelper create(Ref ref) {
    return certDatabaseHelper(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DatabaseHelper value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DatabaseHelper>(value),
    );
  }
}

String _$certDatabaseHelperHash() =>
    r'1c4f04cc7ead4081ae71e9e3629a53b59a299ffc';

@ProviderFor(certAssetLocalDataSource)
final certAssetLocalDataSourceProvider = CertAssetLocalDataSourceProvider._();

final class CertAssetLocalDataSourceProvider
    extends
        $FunctionalProvider<
          AssetLocalDataSource,
          AssetLocalDataSource,
          AssetLocalDataSource
        >
    with $Provider<AssetLocalDataSource> {
  CertAssetLocalDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'certAssetLocalDataSourceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$certAssetLocalDataSourceHash();

  @$internal
  @override
  $ProviderElement<AssetLocalDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AssetLocalDataSource create(Ref ref) {
    return certAssetLocalDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AssetLocalDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AssetLocalDataSource>(value),
    );
  }
}

String _$certAssetLocalDataSourceHash() =>
    r'2bd25646923ad63f4f81ebc7692e36f9a47d4fab';

@ProviderFor(certLocalDataSource)
final certLocalDataSourceProvider = CertLocalDataSourceProvider._();

final class CertLocalDataSourceProvider
    extends
        $FunctionalProvider<
          CertLocalDataSource,
          CertLocalDataSource,
          CertLocalDataSource
        >
    with $Provider<CertLocalDataSource> {
  CertLocalDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'certLocalDataSourceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$certLocalDataSourceHash();

  @$internal
  @override
  $ProviderElement<CertLocalDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CertLocalDataSource create(Ref ref) {
    return certLocalDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CertLocalDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CertLocalDataSource>(value),
    );
  }
}

String _$certLocalDataSourceHash() =>
    r'7246134366e29a0a5755a7ae70d8431f2cdb7629';

@ProviderFor(certRemoteDataSource)
final certRemoteDataSourceProvider = CertRemoteDataSourceProvider._();

final class CertRemoteDataSourceProvider
    extends
        $FunctionalProvider<
          CertRemoteDataSource,
          CertRemoteDataSource,
          CertRemoteDataSource
        >
    with $Provider<CertRemoteDataSource> {
  CertRemoteDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'certRemoteDataSourceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$certRemoteDataSourceHash();

  @$internal
  @override
  $ProviderElement<CertRemoteDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CertRemoteDataSource create(Ref ref) {
    return certRemoteDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CertRemoteDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CertRemoteDataSource>(value),
    );
  }
}

String _$certRemoteDataSourceHash() =>
    r'c94f52784869aaae558e75e63a14379801c0a321';

@ProviderFor(certificateRepository)
final certificateRepositoryProvider = CertificateRepositoryProvider._();

final class CertificateRepositoryProvider
    extends
        $FunctionalProvider<
          CertificateRepository,
          CertificateRepository,
          CertificateRepository
        >
    with $Provider<CertificateRepository> {
  CertificateRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'certificateRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$certificateRepositoryHash();

  @$internal
  @override
  $ProviderElement<CertificateRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CertificateRepository create(Ref ref) {
    return certificateRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CertificateRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CertificateRepository>(value),
    );
  }
}

String _$certificateRepositoryHash() =>
    r'd3b5f79ed426f1c6593319dce419c4593b45dba8';

@ProviderFor(templatesByType)
final templatesByTypeProvider = TemplatesByTypeFamily._();

final class TemplatesByTypeProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TestTemplateName>>,
          List<TestTemplateName>,
          FutureOr<List<TestTemplateName>>
        >
    with
        $FutureModifier<List<TestTemplateName>>,
        $FutureProvider<List<TestTemplateName>> {
  TemplatesByTypeProvider._({
    required TemplatesByTypeFamily super.from,
    required CertType super.argument,
  }) : super(
         retry: null,
         name: r'templatesByTypeProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$templatesByTypeHash();

  @override
  String toString() {
    return r'templatesByTypeProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<TestTemplateName>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<TestTemplateName>> create(Ref ref) {
    final argument = this.argument as CertType;
    return templatesByType(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TemplatesByTypeProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$templatesByTypeHash() => r'319bb372172b5e775d1ddb9bd96c2d65d40cded7';

final class TemplatesByTypeFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<TestTemplateName>>, CertType> {
  TemplatesByTypeFamily._()
    : super(
        retry: null,
        name: r'templatesByTypeProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TemplatesByTypeProvider call(CertType type) =>
      TemplatesByTypeProvider._(argument: type, from: this);

  @override
  String toString() => r'templatesByTypeProvider';
}

@ProviderFor(templateItems)
final templateItemsProvider = TemplateItemsFamily._();

final class TemplateItemsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TestTemplateItem>>,
          List<TestTemplateItem>,
          FutureOr<List<TestTemplateItem>>
        >
    with
        $FutureModifier<List<TestTemplateItem>>,
        $FutureProvider<List<TestTemplateItem>> {
  TemplateItemsProvider._({
    required TemplateItemsFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'templateItemsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$templateItemsHash();

  @override
  String toString() {
    return r'templateItemsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<TestTemplateItem>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<TestTemplateItem>> create(Ref ref) {
    final argument = this.argument as int;
    return templateItems(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TemplateItemsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$templateItemsHash() => r'a0c787e91cb65f819e1cdc10b72fd33d07159aa4';

final class TemplateItemsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<TestTemplateItem>>, int> {
  TemplateItemsFamily._()
    : super(
        retry: null,
        name: r'templateItemsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TemplateItemsProvider call(int templateNameId) =>
      TemplateItemsProvider._(argument: templateNameId, from: this);

  @override
  String toString() => r'templateItemsProvider';
}

@ProviderFor(certificateList)
final certificateListProvider = CertificateListProvider._();

final class CertificateListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CertificateSummary>>,
          List<CertificateSummary>,
          FutureOr<List<CertificateSummary>>
        >
    with
        $FutureModifier<List<CertificateSummary>>,
        $FutureProvider<List<CertificateSummary>> {
  CertificateListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'certificateListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$certificateListHash();

  @$internal
  @override
  $FutureProviderElement<List<CertificateSummary>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<CertificateSummary>> create(Ref ref) {
    return certificateList(ref);
  }
}

String _$certificateListHash() => r'673ef84d5894871eeb59d42e82531b400eef9f4f';

@ProviderFor(certificateSummary)
final certificateSummaryProvider = CertificateSummaryFamily._();

final class CertificateSummaryProvider
    extends
        $FunctionalProvider<
          AsyncValue<CertificateSummary?>,
          CertificateSummary?,
          FutureOr<CertificateSummary?>
        >
    with
        $FutureModifier<CertificateSummary?>,
        $FutureProvider<CertificateSummary?> {
  CertificateSummaryProvider._({
    required CertificateSummaryFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'certificateSummaryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$certificateSummaryHash();

  @override
  String toString() {
    return r'certificateSummaryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<CertificateSummary?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CertificateSummary?> create(Ref ref) {
    final argument = this.argument as int;
    return certificateSummary(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CertificateSummaryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$certificateSummaryHash() =>
    r'c02b0da13d0ec6479b991c18ded7493f8a8d4531';

final class CertificateSummaryFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<CertificateSummary?>, int> {
  CertificateSummaryFamily._()
    : super(
        retry: null,
        name: r'certificateSummaryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CertificateSummaryProvider call(int id) =>
      CertificateSummaryProvider._(argument: id, from: this);

  @override
  String toString() => r'certificateSummaryProvider';
}

@ProviderFor(certOutputs)
final certOutputsProvider = CertOutputsFamily._();

final class CertOutputsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TestOutput>>,
          List<TestOutput>,
          FutureOr<List<TestOutput>>
        >
    with $FutureModifier<List<TestOutput>>, $FutureProvider<List<TestOutput>> {
  CertOutputsProvider._({
    required CertOutputsFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'certOutputsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$certOutputsHash();

  @override
  String toString() {
    return r'certOutputsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<TestOutput>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<TestOutput>> create(Ref ref) {
    final argument = this.argument as int;
    return certOutputs(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CertOutputsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$certOutputsHash() => r'db1ad17811c4ca06afa31e92120191f45f30670a';

final class CertOutputsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<TestOutput>>, int> {
  CertOutputsFamily._()
    : super(
        retry: null,
        name: r'certOutputsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CertOutputsProvider call(int certId) =>
      CertOutputsProvider._(argument: certId, from: this);

  @override
  String toString() => r'certOutputsProvider';
}

@ProviderFor(testEquipmentAssets)
final testEquipmentAssetsProvider = TestEquipmentAssetsProvider._();

final class TestEquipmentAssetsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TestEquipmentAsset>>,
          List<TestEquipmentAsset>,
          FutureOr<List<TestEquipmentAsset>>
        >
    with
        $FutureModifier<List<TestEquipmentAsset>>,
        $FutureProvider<List<TestEquipmentAsset>> {
  TestEquipmentAssetsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'testEquipmentAssetsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$testEquipmentAssetsHash();

  @$internal
  @override
  $FutureProviderElement<List<TestEquipmentAsset>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<TestEquipmentAsset>> create(Ref ref) {
    return testEquipmentAssets(ref);
  }
}

String _$testEquipmentAssetsHash() =>
    r'f34aaf8e8ceae4b32cfe6b2a69671682d31f8b9f';

@ProviderFor(assetPmTasks)
final assetPmTasksProvider = AssetPmTasksFamily._();

final class AssetPmTasksProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AssetPmTask>>,
          List<AssetPmTask>,
          FutureOr<List<AssetPmTask>>
        >
    with
        $FutureModifier<List<AssetPmTask>>,
        $FutureProvider<List<AssetPmTask>> {
  AssetPmTasksProvider._({
    required AssetPmTasksFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'assetPmTasksProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$assetPmTasksHash();

  @override
  String toString() {
    return r'assetPmTasksProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<AssetPmTask>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AssetPmTask>> create(Ref ref) {
    final argument = this.argument as int;
    return assetPmTasks(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AssetPmTasksProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$assetPmTasksHash() => r'e8fc7671dda751bab48f1be915d7a6b630bee9c8';

final class AssetPmTasksFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<AssetPmTask>>, int> {
  AssetPmTasksFamily._()
    : super(
        retry: null,
        name: r'assetPmTasksProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AssetPmTasksProvider call(int assetId) =>
      AssetPmTasksProvider._(argument: assetId, from: this);

  @override
  String toString() => r'assetPmTasksProvider';
}
