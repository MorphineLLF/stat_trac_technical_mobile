// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'work_order_document_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// No interceptor: these routes take the device token as a Bearer, and a
/// cookie is turned away by the CSRF guard — as for the certificate client.

@ProviderFor(workOrderDocumentClient)
final workOrderDocumentClientProvider = WorkOrderDocumentClientProvider._();

/// No interceptor: these routes take the device token as a Bearer, and a
/// cookie is turned away by the CSRF guard — as for the certificate client.

final class WorkOrderDocumentClientProvider
    extends
        $FunctionalProvider<
          WorkOrderDocumentClient,
          WorkOrderDocumentClient,
          WorkOrderDocumentClient
        >
    with $Provider<WorkOrderDocumentClient> {
  /// No interceptor: these routes take the device token as a Bearer, and a
  /// cookie is turned away by the CSRF guard — as for the certificate client.
  WorkOrderDocumentClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workOrderDocumentClientProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workOrderDocumentClientHash();

  @$internal
  @override
  $ProviderElement<WorkOrderDocumentClient> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WorkOrderDocumentClient create(Ref ref) {
    return workOrderDocumentClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkOrderDocumentClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkOrderDocumentClient>(value),
    );
  }
}

String _$workOrderDocumentClientHash() =>
    r'1b6ed014001fb043f13f86ddbd122e24522b7404';

/// The company and device token these routes need, or null when signed out.

@ProviderFor(workOrderDocumentCredentials)
final workOrderDocumentCredentialsProvider =
    WorkOrderDocumentCredentialsProvider._();

/// The company and device token these routes need, or null when signed out.

final class WorkOrderDocumentCredentialsProvider
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
  WorkOrderDocumentCredentialsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workOrderDocumentCredentialsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workOrderDocumentCredentialsHash();

  @$internal
  @override
  $FutureProviderElement<({String company, String token})?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<({String company, String token})?> create(Ref ref) {
    return workOrderDocumentCredentials(ref);
  }
}

String _$workOrderDocumentCredentialsHash() =>
    r'1e1e797efdc62ccc43f3f10eaf9b8fd42399adca';
