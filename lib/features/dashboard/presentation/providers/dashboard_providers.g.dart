// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$lastSyncedAtHash() => r'23378c9fd8d1f90604eaaf9cf72b2e950aaa2103';

/// Exposes the last successful sync timestamp for the "Last synced" display.
/// Returns null if no sync has completed yet this session.
///
/// Copied from [lastSyncedAt].
@ProviderFor(lastSyncedAt)
final lastSyncedAtProvider = AutoDisposeProvider<DateTime?>.internal(
  lastSyncedAt,
  name: r'lastSyncedAtProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$lastSyncedAtHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LastSyncedAtRef = AutoDisposeProviderRef<DateTime?>;
String _$dashboardStatsHash() => r'e87fff22e5dc3a5efc815af57e19dc990810f91a';

/// Active WO counts for the dashboard donut chart and KPI row.
/// Active = not completed / reviewed / closed / cancelled.
///
/// Copied from [dashboardStats].
@ProviderFor(dashboardStats)
final dashboardStatsProvider =
    AutoDisposeFutureProvider<DashboardStats>.internal(
      dashboardStats,
      name: r'dashboardStatsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$dashboardStatsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DashboardStatsRef = AutoDisposeFutureProviderRef<DashboardStats>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
