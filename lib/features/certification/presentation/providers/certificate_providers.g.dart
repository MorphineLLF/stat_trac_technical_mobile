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
