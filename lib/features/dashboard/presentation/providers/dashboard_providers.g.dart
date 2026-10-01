// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Exposes the last successful sync timestamp for the "Last synced" display.
/// Returns null if no sync has completed yet this session.

@ProviderFor(lastSyncedAt)
final lastSyncedAtProvider = LastSyncedAtProvider._();

/// Exposes the last successful sync timestamp for the "Last synced" display.
/// Returns null if no sync has completed yet this session.

final class LastSyncedAtProvider
    extends $FunctionalProvider<DateTime?, DateTime?, DateTime?>
    with $Provider<DateTime?> {
  /// Exposes the last successful sync timestamp for the "Last synced" display.
  /// Returns null if no sync has completed yet this session.
  LastSyncedAtProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lastSyncedAtProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lastSyncedAtHash();

  @$internal
  @override
  $ProviderElement<DateTime?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DateTime? create(Ref ref) {
    return lastSyncedAt(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime?>(value),
    );
  }
}

String _$lastSyncedAtHash() => r'a55ef5c067d8b7e18a498598d9fd09e2461c460f';

/// Counted from the OUTBOX. A captured work order is completed the moment
/// the server applies it, so nothing synced is pending — what is pending is
/// what has not left the phone.

@ProviderFor(dashboardStats)
final dashboardStatsProvider = DashboardStatsProvider._();

/// Counted from the OUTBOX. A captured work order is completed the moment
/// the server applies it, so nothing synced is pending — what is pending is
/// what has not left the phone.

final class DashboardStatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<DashboardStats>,
          DashboardStats,
          FutureOr<DashboardStats>
        >
    with $FutureModifier<DashboardStats>, $FutureProvider<DashboardStats> {
  /// Counted from the OUTBOX. A captured work order is completed the moment
  /// the server applies it, so nothing synced is pending — what is pending is
  /// what has not left the phone.
  DashboardStatsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dashboardStatsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dashboardStatsHash();

  @$internal
  @override
  $FutureProviderElement<DashboardStats> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DashboardStats> create(Ref ref) {
    return dashboardStats(ref);
  }
}

String _$dashboardStatsHash() => r'72050ec8bd321d401afb7bc7fd9710b295d51ab6';
