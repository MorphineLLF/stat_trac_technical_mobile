import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../api/auth_interceptor.dart';
import '../../../../api/dio_client.dart';
import '../../../../database/database_helper.dart';
import '../../../assets/data/datasources/asset_local_data_source.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/cert_local_data_source.dart';
import '../../data/datasources/cert_remote_data_source.dart';
import '../../data/models/certificate_summary.dart';
import '../../data/repositories/certificate_repository_impl.dart';
import '../../domain/entities/asset_pm_task.dart';
import '../../domain/entities/test_equipment_asset.dart';
import '../../domain/entities/test_output.dart';
import '../../domain/entities/test_template_item.dart';
import '../../domain/entities/test_template_name.dart';
import '../../domain/repositories/certificate_repository.dart';
import '../../data/powersync_cert_data_source.dart';
import '../../../../sync/powersync_providers.dart';

part 'certificate_providers.g.dart';

@riverpod
DatabaseHelper certDatabaseHelper(Ref ref) => DatabaseHelper.instance;

@riverpod
AssetLocalDataSource certAssetLocalDataSource(Ref ref) =>
    AssetLocalDataSourceImpl(ref.watch(certDatabaseHelperProvider));

/// Certificates now come from PowerSync, not the retired Horse tables.
@riverpod
Future<PowerSyncCertDataSource> powerSyncCerts(Ref ref) async {
  return PowerSyncCertDataSource(await ref.watch(syncDatabaseProvider.future));
}

@riverpod
CertLocalDataSource certLocalDataSource(Ref ref) =>
    CertLocalDataSourceImpl(ref.watch(certDatabaseHelperProvider));

@riverpod
CertRemoteDataSource certRemoteDataSource(Ref ref) {
  final authLocal = ref.watch(authLocalDataSourceProvider);
  final authRemote = ref.watch(authRemoteDataSourceProvider);
  final interceptor = AuthInterceptor(local: authLocal, remote: authRemote);
  return CertRemoteDataSourceImpl(buildDioClient(interceptor));
}

@riverpod
CertificateRepository certificateRepository(Ref ref) =>
    CertificateRepositoryImpl(
      local: ref.watch(certLocalDataSourceProvider),
      remote: ref.watch(certRemoteDataSourceProvider),
    );

@riverpod
Future<List<TestTemplateName>> templatesByType(Ref ref, CertType type) =>
    ref.watch(certificateRepositoryProvider).getTemplatesByType(type);

@riverpod
Future<List<TestTemplateItem>> templateItems(Ref ref, int templateNameId) =>
    ref.watch(certificateRepositoryProvider).getTemplateItems(templateNameId);

@riverpod
Future<List<CertificateSummary>> certificateList(Ref ref) =>
    ref.watch(powerSyncCertsProvider.future).then((ds) => ds.getCertificates());

@riverpod
Future<CertificateSummary?> certificateSummary(Ref ref, int id) =>
    ref.watch(powerSyncCertsProvider.future).then((ds) => ds.getCertificateById(id));

@riverpod
Future<List<TestOutput>> certOutputs(Ref ref, int certId) =>
    ref.watch(powerSyncCertsProvider.future).then(
      (ds) => ds.getOutputsByCertId(certId),
    );

@riverpod
Future<List<TestEquipmentAsset>> testEquipmentAssets(Ref ref) =>
    ref.watch(certLocalDataSourceProvider).getTestEquipmentAssets();

@riverpod
Future<List<AssetPmTask>> assetPmTasks(Ref ref, int assetId) =>
    ref.watch(certLocalDataSourceProvider).getAssetPmTasks(assetId);
