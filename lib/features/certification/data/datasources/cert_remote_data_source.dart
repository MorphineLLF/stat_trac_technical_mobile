import 'package:dio/dio.dart';

import '../models/test_template_name_model.dart';
import '../models/test_template_item_model.dart';

abstract interface class CertRemoteDataSource {
  /// GET /certificates/templates?type=<1|2|3>
  Future<List<TestTemplateNameModel>> fetchTemplates(int type);

  /// GET /certificates/templates/:id/items
  Future<List<TestTemplateItemModel>> fetchTemplateItems(int templateId);

  /// POST /certificates — returns the server-assigned TestCertificateID.
  Future<int> pushCertificate(Map<String, dynamic> payload);
}

class CertRemoteDataSourceImpl implements CertRemoteDataSource {
  CertRemoteDataSourceImpl(this._dio);
  final Dio _dio;

  @override
  Future<List<TestTemplateNameModel>> fetchTemplates(int type) async {
    final response = await _dio.get(
      '/certificates/templates',
      queryParameters: {'type': type},
    );
    final data = (response.data['data'] as List)
        .cast<Map<String, dynamic>>();
    return data.map(TestTemplateNameModel.fromJson).toList();
  }

  @override
  Future<List<TestTemplateItemModel>> fetchTemplateItems(int templateId) async {
    final response =
        await _dio.get('/certificates/templates/$templateId/items');
    final data = (response.data['data'] as List)
        .cast<Map<String, dynamic>>();
    return data.map(TestTemplateItemModel.fromJson).toList();
  }

  @override
  Future<int> pushCertificate(Map<String, dynamic> payload) async {
    final response = await _dio.post('/certificates', data: payload);
    return response.data['id'] as int;
  }
}
