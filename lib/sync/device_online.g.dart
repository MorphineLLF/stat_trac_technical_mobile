// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_online.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The phone's network, live. Starts with a check so the first answer does not
/// wait for a change.

@ProviderFor(deviceOnline)
final deviceOnlineProvider = DeviceOnlineProvider._();

/// The phone's network, live. Starts with a check so the first answer does not
/// wait for a change.

final class DeviceOnlineProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  /// The phone's network, live. Starts with a check so the first answer does not
  /// wait for a change.
  DeviceOnlineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceOnlineProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceOnlineHash();

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    return deviceOnline(ref);
  }
}

String _$deviceOnlineHash() => r'ea625aa2cd17b767e82a424a0c61ef60b7eb0881';
