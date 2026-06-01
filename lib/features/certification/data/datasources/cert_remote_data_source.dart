import '../models/test_template_name_model.dart';
import '../models/test_template_item_model.dart';

abstract interface class CertRemoteDataSource {
  /// GET /certificates/templates?type=<1|2|3>
  /// Returns [] until Horse API is implemented.
  Future<List<TestTemplateNameModel>> fetchTemplates(int type);

  /// GET /certificates/templates/:id/items
  /// Returns [] until Horse API is implemented.
  Future<List<TestTemplateItemModel>> fetchTemplateItems(int templateId);

  /// POST /certificates
  /// Returns the server-assigned ID, or throws if unavailable.
  Future<int> pushCertificate(Map<String, dynamic> payload);
}

class CertRemoteDataSourceImpl implements CertRemoteDataSource {
  @override
  Future<List<TestTemplateNameModel>> fetchTemplates(int type) async => [];

  @override
  Future<List<TestTemplateItemModel>> fetchTemplateItems(int templateId) async => [];

  @override
  Future<int> pushCertificate(Map<String, dynamic> payload) async =>
      throw UnimplementedError('Certificate sync endpoint not yet available');
}
