import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../database/database_helper.dart';
import '../../../assets/data/datasources/asset_local_data_source.dart';
import '../../data/datasources/cert_local_data_source.dart';
import '../../data/datasources/cert_remote_data_source.dart';
import '../../data/repositories/certificate_repository_impl.dart';
import '../../domain/entities/test_template_item.dart';
import '../../domain/entities/test_template_name.dart';
import '../../domain/repositories/certificate_repository.dart';

part 'certificate_providers.g.dart';

@riverpod
DatabaseHelper certDatabaseHelper(Ref ref) => DatabaseHelper.instance;

@riverpod
AssetLocalDataSource certAssetLocalDataSource(Ref ref) =>
    AssetLocalDataSourceImpl(ref.watch(certDatabaseHelperProvider));

@riverpod
CertLocalDataSource certLocalDataSource(Ref ref) =>
    CertLocalDataSourceImpl(ref.watch(certDatabaseHelperProvider));

@riverpod
CertRemoteDataSource certRemoteDataSource(Ref ref) =>
    CertRemoteDataSourceImpl();

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
