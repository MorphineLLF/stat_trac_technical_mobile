import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../models/asset_detail_model.dart';
import '../models/asset_model.dart';

abstract interface class AssetRemoteDataSource {
  /// GET /assets?page=N&page_size=500 — slim records for sync.
  Future<List<AssetModel>> getAssets({required int page, int pageSize = 500});

  /// GET /assets/{id} — full record for detail view.
  Future<AssetDetailModel> getAssetDetail(int assetId);
}

class AssetRemoteDataSourceImpl implements AssetRemoteDataSource {
  AssetRemoteDataSourceImpl(this._dio);
  final Dio _dio;

  @override
  Future<List<AssetModel>> getAssets({
    required int page,
    int pageSize = 500,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/assets',
      queryParameters: {'page': page, 'page_size': pageSize},
    );
    debugPrint('[AssetRemote] GET /assets page=$page → keys: ${response.data?.keys.toList()}, status: ${response.statusCode}');
    final items = (response.data?['data'] as List<dynamic>?) ?? [];
    debugPrint('[AssetRemote] parsed ${items.length} items');
    return items
        .cast<Map<String, dynamic>>()
        .map(AssetModel.fromJson)
        .toList();
  }

  @override
  Future<AssetDetailModel> getAssetDetail(int assetId) async {
    final response =
        await _dio.get<Map<String, dynamic>>('/assets/$assetId');
    if (response.data == null) {
      throw Exception('Empty response for asset $assetId');
    }
    return AssetDetailModel.fromJson(response.data!);
  }
}
