// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'work_order_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(workOrderSource)
final workOrderSourceProvider = WorkOrderSourceProvider._();

final class WorkOrderSourceProvider
    extends
        $FunctionalProvider<
          AsyncValue<PowerSyncWorkOrderDataSource>,
          PowerSyncWorkOrderDataSource,
          FutureOr<PowerSyncWorkOrderDataSource>
        >
    with
        $FutureModifier<PowerSyncWorkOrderDataSource>,
        $FutureProvider<PowerSyncWorkOrderDataSource> {
  WorkOrderSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workOrderSourceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workOrderSourceHash();

  @$internal
  @override
  $FutureProviderElement<PowerSyncWorkOrderDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PowerSyncWorkOrderDataSource> create(Ref ref) {
    return workOrderSource(ref);
  }
}

String _$workOrderSourceHash() => r'a6906b1cc53569ac7db42a0a17f46d2f4f809c28';

/// The signed-in technician's captured work orders: still on the phone first,
/// then synced.

@ProviderFor(worklist)
final worklistProvider = WorklistProvider._();

/// The signed-in technician's captured work orders: still on the phone first,
/// then synced.

final class WorklistProvider
    extends
        $FunctionalProvider<AsyncValue<Worklist>, Worklist, FutureOr<Worklist>>
    with $FutureModifier<Worklist>, $FutureProvider<Worklist> {
  /// The signed-in technician's captured work orders: still on the phone first,
  /// then synced.
  WorklistProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'worklistProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$worklistHash();

  @$internal
  @override
  $FutureProviderElement<Worklist> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Worklist> create(Ref ref) {
    return worklist(ref);
  }
}

String _$worklistHash() => r'db6738840971e2848d4e462006c6ea3ae8712f2c';

@ProviderFor(openRepairOnAsset)
final openRepairOnAssetProvider = OpenRepairOnAssetFamily._();

final class OpenRepairOnAssetProvider
    extends $FunctionalProvider<AsyncValue<int?>, int?, FutureOr<int?>>
    with $FutureModifier<int?>, $FutureProvider<int?> {
  OpenRepairOnAssetProvider._({
    required OpenRepairOnAssetFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'openRepairOnAssetProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$openRepairOnAssetHash();

  @override
  String toString() {
    return r'openRepairOnAssetProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<int?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int?> create(Ref ref) {
    final argument = this.argument as int;
    return openRepairOnAsset(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is OpenRepairOnAssetProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$openRepairOnAssetHash() => r'c91a212794c9f1928e64a17db6a02827b272f9c9';

final class OpenRepairOnAssetFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<int?>, int> {
  OpenRepairOnAssetFamily._()
    : super(
        retry: null,
        name: r'openRepairOnAssetProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  OpenRepairOnAssetProvider call(int assetId) =>
      OpenRepairOnAssetProvider._(argument: assetId, from: this);

  @override
  String toString() => r'openRepairOnAssetProvider';
}

@ProviderFor(workOrderRecord)
final workOrderRecordProvider = WorkOrderRecordFamily._();

final class WorkOrderRecordProvider
    extends
        $FunctionalProvider<
          AsyncValue<WorkOrderRecord?>,
          WorkOrderRecord?,
          FutureOr<WorkOrderRecord?>
        >
    with $FutureModifier<WorkOrderRecord?>, $FutureProvider<WorkOrderRecord?> {
  WorkOrderRecordProvider._({
    required WorkOrderRecordFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'workOrderRecordProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workOrderRecordHash();

  @override
  String toString() {
    return r'workOrderRecordProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<WorkOrderRecord?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<WorkOrderRecord?> create(Ref ref) {
    final argument = this.argument as int;
    return workOrderRecord(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkOrderRecordProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workOrderRecordHash() => r'04b18f871415057dab978b807816e76396490fc8';

final class WorkOrderRecordFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<WorkOrderRecord?>, int> {
  WorkOrderRecordFamily._()
    : super(
        retry: null,
        name: r'workOrderRecordProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  WorkOrderRecordProvider call(int trackId) =>
      WorkOrderRecordProvider._(argument: trackId, from: this);

  @override
  String toString() => r'workOrderRecordProvider';
}

@ProviderFor(repairParts)
final repairPartsProvider = RepairPartsFamily._();

final class RepairPartsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<PartUsed>?>,
          List<PartUsed>?,
          FutureOr<List<PartUsed>?>
        >
    with $FutureModifier<List<PartUsed>?>, $FutureProvider<List<PartUsed>?> {
  RepairPartsProvider._({
    required RepairPartsFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'repairPartsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$repairPartsHash();

  @override
  String toString() {
    return r'repairPartsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<PartUsed>?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<PartUsed>?> create(Ref ref) {
    final argument = this.argument as int;
    return repairParts(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RepairPartsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$repairPartsHash() => r'8fb0bbc3eccf504369b1b51de021b04edc1b1cd6';

final class RepairPartsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<PartUsed>?>, int> {
  RepairPartsFamily._()
    : super(
        retry: null,
        name: r'repairPartsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  RepairPartsProvider call(int trackId) =>
      RepairPartsProvider._(argument: trackId, from: this);

  @override
  String toString() => r'repairPartsProvider';
}

/// The register search the parts picker calls as the technician types.

@ProviderFor(partSearch)
final partSearchProvider = PartSearchProvider._();

/// The register search the parts picker calls as the technician types.

final class PartSearchProvider
    extends
        $FunctionalProvider<
          AsyncValue<Future<List<RegisterPart>> Function(String)>,
          Future<List<RegisterPart>> Function(String),
          FutureOr<Future<List<RegisterPart>> Function(String)>
        >
    with
        $FutureModifier<Future<List<RegisterPart>> Function(String)>,
        $FutureProvider<Future<List<RegisterPart>> Function(String)> {
  /// The register search the parts picker calls as the technician types.
  PartSearchProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'partSearchProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$partSearchHash();

  @$internal
  @override
  $FutureProviderElement<Future<List<RegisterPart>> Function(String)>
  $createElement($ProviderPointer pointer) => $FutureProviderElement(pointer);

  @override
  FutureOr<Future<List<RegisterPart>> Function(String)> create(Ref ref) {
    return partSearch(ref);
  }
}

String _$partSearchHash() => r'bbed92d0757e1687c5df26774231071acd22f609';

@ProviderFor(queuedWorkOrder)
final queuedWorkOrderProvider = QueuedWorkOrderFamily._();

final class QueuedWorkOrderProvider
    extends
        $FunctionalProvider<
          AsyncValue<UploadQueueEntry?>,
          UploadQueueEntry?,
          FutureOr<UploadQueueEntry?>
        >
    with
        $FutureModifier<UploadQueueEntry?>,
        $FutureProvider<UploadQueueEntry?> {
  QueuedWorkOrderProvider._({
    required QueuedWorkOrderFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'queuedWorkOrderProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$queuedWorkOrderHash();

  @override
  String toString() {
    return r'queuedWorkOrderProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<UploadQueueEntry?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<UploadQueueEntry?> create(Ref ref) {
    final argument = this.argument as String;
    return queuedWorkOrder(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is QueuedWorkOrderProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$queuedWorkOrderHash() => r'0fc0fe7f649a51557aa18920a107c01647450ff0';

final class QueuedWorkOrderFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<UploadQueueEntry?>, String> {
  QueuedWorkOrderFamily._()
    : super(
        retry: null,
        name: r'queuedWorkOrderProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  QueuedWorkOrderProvider call(String mobileId) =>
      QueuedWorkOrderProvider._(argument: mobileId, from: this);

  @override
  String toString() => r'queuedWorkOrderProvider';
}

/// The signatures this phone captured for a job — from the queue while it
/// waits, from the archive after it went. Null when this phone never had them
/// (signed elsewhere) or the archive has rolled past it.

@ProviderFor(phoneSignatures)
final phoneSignaturesProvider = PhoneSignaturesFamily._();

/// The signatures this phone captured for a job — from the queue while it
/// waits, from the archive after it went. Null when this phone never had them
/// (signed elsewhere) or the archive has rolled past it.

final class PhoneSignaturesProvider
    extends
        $FunctionalProvider<
          AsyncValue<WorkOrderUpload?>,
          WorkOrderUpload?,
          FutureOr<WorkOrderUpload?>
        >
    with $FutureModifier<WorkOrderUpload?>, $FutureProvider<WorkOrderUpload?> {
  /// The signatures this phone captured for a job — from the queue while it
  /// waits, from the archive after it went. Null when this phone never had them
  /// (signed elsewhere) or the archive has rolled past it.
  PhoneSignaturesProvider._({
    required PhoneSignaturesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'phoneSignaturesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$phoneSignaturesHash();

  @override
  String toString() {
    return r'phoneSignaturesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<WorkOrderUpload?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<WorkOrderUpload?> create(Ref ref) {
    final argument = this.argument as String;
    return phoneSignatures(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PhoneSignaturesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$phoneSignaturesHash() => r'd74ba606a906d205cb8afd019cf6fc7ff38bf80c';

/// The signatures this phone captured for a job — from the queue while it
/// waits, from the archive after it went. Null when this phone never had them
/// (signed elsewhere) or the archive has rolled past it.

final class PhoneSignaturesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<WorkOrderUpload?>, String> {
  PhoneSignaturesFamily._()
    : super(
        retry: null,
        name: r'phoneSignaturesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The signatures this phone captured for a job — from the queue while it
  /// waits, from the archive after it went. Null when this phone never had them
  /// (signed elsewhere) or the archive has rolled past it.

  PhoneSignaturesProvider call(String mobileId) =>
      PhoneSignaturesProvider._(argument: mobileId, from: this);

  @override
  String toString() => r'phoneSignaturesProvider';
}
