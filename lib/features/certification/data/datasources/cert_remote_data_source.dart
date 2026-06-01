import 'package:dio/dio.dart';

import '../models/test_certificate_model.dart';
import '../models/test_output_model.dart';
import '../models/test_template_name_model.dart';
import '../models/test_template_item_model.dart';

abstract interface class CertRemoteDataSource {
  /// GET /certificates/templates?type=<1|2|3>
  Future<List<TestTemplateNameModel>> fetchTemplates(int type);

  /// GET /certificates/templates/:id/items
  Future<List<TestTemplateItemModel>> fetchTemplateItems(int templateId);

  /// POST /certificates — returns the server-assigned TestCertificateID.
  Future<int> pushCertificate(Map<String, dynamic> payload);

  /// GET /certificates/history?technician_id=<id>&after_id=<cursor>
  /// Returns cert + embedded outputs for certs the technician created on the
  /// server that are not yet in local SQLite.
  Future<List<(TestCertificateModel, List<TestOutputModel>)>>
      fetchCertificateHistory(int technicianId, int afterId);
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

  @override
  Future<List<(TestCertificateModel, List<TestOutputModel>)>>
      fetchCertificateHistory(int technicianId, int afterId) async {
    final response = await _dio.get(
      '/certificates/history',
      queryParameters: {
        'technician_id': technicianId,
        'after_id': afterId,
      },
    );
    final data =
        ((response.data['data'] as List?) ?? []).cast<Map<String, dynamic>>();
    return data.map((j) {
      final cert = TestCertificateModel.fromJson(j);
      final rawOutputs =
          (j['outputs'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final outputs = rawOutputs
          .map((o) => TestOutputModel.fromJson(o, certificateId: 0))
          .toList();
      return (cert, outputs);
    }).toList();
  }
}
