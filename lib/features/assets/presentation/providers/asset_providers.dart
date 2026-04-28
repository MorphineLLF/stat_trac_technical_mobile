import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../api/auth_interceptor.dart';
import '../../../../api/dio_client.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../work_orders/presentation/providers/work_order_providers.dart';
import '../../data/datasources/asset_local_data_source.dart';
import '../../data/datasources/asset_remote_data_source.dart';
import '../../data/repositories/asset_repository_impl.dart';
import '../../domain/entities/asset.dart';
import '../../domain/entities/asset_detail.dart';
import '../../domain/repositories/asset_repository.dart';

part 'asset_providers.g.dart';

// ── Infrastructure ────────────────────────────────────────────────────────────

@riverpod
AssetRemoteDataSource assetRemoteDataSource(Ref ref) {
  final authLocal = ref.watch(authLocalDataSourceProvider);
  final authRemote = ref.watch(authRemoteDataSourceProvider);
  final interceptor = AuthInterceptor(local: authLocal, remote: authRemote);
  return AssetRemoteDataSourceImpl(buildDioClient(interceptor));
}

@riverpod
AssetRepository assetRepository(Ref ref) => AssetRepositoryImpl(
      local: ref.watch(assetLocalDataSourceProvider),
      remote: ref.watch(assetRemoteDataSourceProvider),
    );

// ── Browse ────────────────────────────────────────────────────────────────────

@riverpod
Future<List<Asset>> assets(Ref ref, {String? hospital}) =>
    ref.watch(assetRepositoryProvider).getAssets(hospital: hospital);

@riverpod
Future<List<String>> hospitalList(Ref ref) =>
    ref.watch(assetLocalDataSourceProvider).getHospitals();

// ── Search ────────────────────────────────────────────────────────────────────

@riverpod
Future<List<Asset>> assetSearch(
  Ref ref,
  String query, {
  String? hospital,
}) =>
    ref.watch(assetRepositoryProvider).searchAssets(query, hospital: hospital);

// ── Stats ─────────────────────────────────────────────────────────────────────

@riverpod
Future<AssetStats> assetStats(Ref ref) =>
    ref.watch(assetLocalDataSourceProvider).getStats();

// ── Detail ────────────────────────────────────────────────────────────────────

@riverpod
Future<AssetDetail> assetDetail(Ref ref, int assetId) =>
    ref.watch(assetRepositoryProvider).getAssetDetail(assetId);
