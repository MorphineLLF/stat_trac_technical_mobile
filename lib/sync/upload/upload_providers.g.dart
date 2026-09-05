// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'upload_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(uploadQueue)
final uploadQueueProvider = UploadQueueProvider._();

final class UploadQueueProvider
    extends
        $FunctionalProvider<
          AsyncValue<UploadQueue>,
          UploadQueue,
          FutureOr<UploadQueue>
        >
    with $FutureModifier<UploadQueue>, $FutureProvider<UploadQueue> {
  UploadQueueProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'uploadQueueProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$uploadQueueHash();

  @$internal
  @override
  $FutureProviderElement<UploadQueue> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<UploadQueue> create(Ref ref) {
    return uploadQueue(ref);
  }
}

String _$uploadQueueHash() => r'a96b7ae4666c7d6bd80430940cac524de9d758d9';

/// The upload client. No interceptor: this route takes the ninety-day device
/// token as a Bearer, and a cookie is turned away by the CSRF guard.

@ProviderFor(syncUploadClient)
final syncUploadClientProvider = SyncUploadClientProvider._();

/// The upload client. No interceptor: this route takes the ninety-day device
/// token as a Bearer, and a cookie is turned away by the CSRF guard.

final class SyncUploadClientProvider
    extends
        $FunctionalProvider<
          SyncUploadClient,
          SyncUploadClient,
          SyncUploadClient
        >
    with $Provider<SyncUploadClient> {
  /// The upload client. No interceptor: this route takes the ninety-day device
  /// token as a Bearer, and a cookie is turned away by the CSRF guard.
  SyncUploadClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncUploadClientProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncUploadClientHash();

  @$internal
  @override
  $ProviderElement<SyncUploadClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SyncUploadClient create(Ref ref) {
    return syncUploadClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncUploadClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncUploadClient>(value),
    );
  }
}

String _$syncUploadClientHash() => r'5035c178650a1fefdb8f542f4368868a4f9e5301';

@ProviderFor(uploadWorker)
final uploadWorkerProvider = UploadWorkerProvider._();

final class UploadWorkerProvider
    extends
        $FunctionalProvider<
          AsyncValue<UploadWorker>,
          UploadWorker,
          FutureOr<UploadWorker>
        >
    with $FutureModifier<UploadWorker>, $FutureProvider<UploadWorker> {
  UploadWorkerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'uploadWorkerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$uploadWorkerHash();

  @$internal
  @override
  $FutureProviderElement<UploadWorker> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<UploadWorker> create(Ref ref) {
    return uploadWorker(ref);
  }
}

String _$uploadWorkerHash() => r'9c34c65add347117d5d835888181fc72aaa72b33';

/// How many certificates are waiting to reach the server.
///
/// This is the number a technician needs before leaving a site, so it counts
/// everything still on the device — including the ones held for a conflict or
/// a rejection, because those are exactly the ones somebody has to act on.

@ProviderFor(pendingUploadCount)
final pendingUploadCountProvider = PendingUploadCountProvider._();

/// How many certificates are waiting to reach the server.
///
/// This is the number a technician needs before leaving a site, so it counts
/// everything still on the device — including the ones held for a conflict or
/// a rejection, because those are exactly the ones somebody has to act on.

final class PendingUploadCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  /// How many certificates are waiting to reach the server.
  ///
  /// This is the number a technician needs before leaving a site, so it counts
  /// everything still on the device — including the ones held for a conflict or
  /// a rejection, because those are exactly the ones somebody has to act on.
  PendingUploadCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingUploadCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingUploadCountHash();

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    return pendingUploadCount(ref);
  }
}

String _$pendingUploadCountHash() =>
    r'7ab0ce9297002e2e2c262405262397f199a7faae';
