// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cert_document_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The certificate document client.
///
/// No interceptor, deliberately: these routes take the ninety-day device
/// token as a Bearer, and a cookie is turned away by the CSRF guard — the
/// same reasoning as the upload client.

@ProviderFor(certDocumentClient)
final certDocumentClientProvider = CertDocumentClientProvider._();

/// The certificate document client.
///
/// No interceptor, deliberately: these routes take the ninety-day device
/// token as a Bearer, and a cookie is turned away by the CSRF guard — the
/// same reasoning as the upload client.

final class CertDocumentClientProvider
    extends
        $FunctionalProvider<
          CertDocumentClient,
          CertDocumentClient,
          CertDocumentClient
        >
    with $Provider<CertDocumentClient> {
  /// The certificate document client.
  ///
  /// No interceptor, deliberately: these routes take the ninety-day device
  /// token as a Bearer, and a cookie is turned away by the CSRF guard — the
  /// same reasoning as the upload client.
  CertDocumentClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'certDocumentClientProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$certDocumentClientHash();

  @$internal
  @override
  $ProviderElement<CertDocumentClient> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CertDocumentClient create(Ref ref) {
    return certDocumentClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CertDocumentClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CertDocumentClient>(value),
    );
  }
}

String _$certDocumentClientHash() =>
    r'ef0420bb484eaaaaae00bf61e281643f46e3e3fe';

/// The company and device token these routes need, or null when signed out.

@ProviderFor(certDocumentCredentials)
final certDocumentCredentialsProvider = CertDocumentCredentialsProvider._();

/// The company and device token these routes need, or null when signed out.

final class CertDocumentCredentialsProvider
    extends
        $FunctionalProvider<
          AsyncValue<({String company, String token})?>,
          ({String company, String token})?,
          FutureOr<({String company, String token})?>
        >
    with
        $FutureModifier<({String company, String token})?>,
        $FutureProvider<({String company, String token})?> {
  /// The company and device token these routes need, or null when signed out.
  CertDocumentCredentialsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'certDocumentCredentialsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$certDocumentCredentialsHash();

  @$internal
  @override
  $FutureProviderElement<({String company, String token})?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<({String company, String token})?> create(Ref ref) {
    return certDocumentCredentials(ref);
  }
}

String _$certDocumentCredentialsHash() =>
    r'293147868fd8c6e80ef7a380fa65ae0c1919ed91';
