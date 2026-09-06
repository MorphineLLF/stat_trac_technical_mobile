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
    ref.watch(powerSyncCertsProvider.future).then(
      (ds) => ds.getTemplatesByType(type),
    );

@riverpod
Future<List<TestTemplateItem>> templateItems(Ref ref, int templateNameId) =>
    ref.watch(powerSyncCertsProvider.future).then(
      (ds) => ds.getTemplateItems(templateNameId),
    );

/// Every certificate the technician can see: the server's, plus this device's
/// own work that the server has not confirmed yet.
///
/// The list used to read PowerSync alone, which meant a technician's finished
/// certificate did not appear on their own screen — the app only ever showed
/// what the server sent back, so work that failed to round-trip looked
/// identical to work that was never done. Local rows drop out of this list the
/// moment the server confirms them, so nothing is ever listed twice.
@riverpod
Future<List<CertificateSummary>> certificateList(Ref ref) async {
  final ds = await ref.watch(powerSyncCertsProvider.future);
  final local = await ref
      .watch(certLocalDataSourceProvider)
      .getUnconfirmedCertificates();
  return [...local, ...await ds.getCertificates()];
}

/// One certificate, from whichever side holds it.
///
/// A local id and a server key are different number spaces, so the device's
/// own unconfirmed work is looked up first — it is the only place that copy
/// exists.
@riverpod
Future<CertificateSummary?> certificateSummary(Ref ref, int id) async {
  final local = await ref
      .watch(certLocalDataSourceProvider)
      .getUnconfirmedCertificates();
  for (final c in local) {
    if (c.id == id) return c;
  }
  final ds = await ref.watch(powerSyncCertsProvider.future);
  return ds.getCertificateById(id);
}

/// A certificate's readings, read from wherever that certificate lives.
///
/// For the device's own unconfirmed work this is local storage — the server
/// has nothing to give back yet, and reading it there is what showed a
/// technician an empty certificate they had just filled in themselves.
@riverpod
Future<List<TestOutput>> certOutputs(Ref ref, int certId) async {
  final summary = await ref.watch(certificateSummaryProvider(certId).future);
  if (summary?.isLocal ?? false) {
    return ref.watch(certLocalDataSourceProvider).getOutputsByCertId(certId);
  }
  final ds = await ref.watch(powerSyncCertsProvider.future);
  return ds.getOutputsByCertId(certId);
}

@riverpod
Future<List<TestEquipmentAsset>> testEquipmentAssets(Ref ref) =>
    ref.watch(powerSyncCertsProvider.future).then(
      (ds) => ds.getTestEquipmentAssets(),
    );

@riverpod
Future<List<AssetPmTask>> assetPmTasks(Ref ref, int assetId) =>
    ref.watch(powerSyncCertsProvider.future).then(
      (ds) => ds.getAssetPmTasks(assetId),
    );
