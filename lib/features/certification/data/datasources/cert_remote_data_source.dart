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

  /// `GET /certificates/history?technician_id=:id&after_id=:cursor&page_size=:n`
  /// Returns up to [pageSize] certs with embedded outputs whose ID > afterId.
  /// When result count == pageSize, more pages exist.
  Future<List<(TestCertificateModel, List<TestOutputModel>)>>
      fetchCertificateHistory(int technicianId, int afterId,
          {int pageSize = 100});

  /// `GET /certificates/ids?technician_id=:id`
  /// Returns all TestCertificateID values for the technician on the server.
  Future<List<int>> fetchCertificateIds(int technicianId);
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
      fetchCertificateHistory(int technicianId, int afterId,
          {int pageSize = 100}) async {
    final response = await _dio.get(
      '/certificates/history',
      queryParameters: {
        'technician_id': technicianId,
        'after_id': afterId,
        'page_size': pageSize,
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

  @override
  Future<List<int>> fetchCertificateIds(int technicianId) async {
    final response = await _dio.get(
      '/certificates/ids',
      queryParameters: {'technician_id': technicianId},
    );
    return ((response.data['ids'] as List?) ?? []).cast<int>();
  }
}
