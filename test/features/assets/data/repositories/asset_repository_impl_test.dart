import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stat_trac_technical/features/assets/data/datasources/asset_local_data_source.dart';
import 'package:stat_trac_technical/features/assets/data/datasources/asset_remote_data_source.dart';
import 'package:stat_trac_technical/features/assets/data/models/asset_model.dart';
import 'package:stat_trac_technical/features/assets/data/repositories/asset_repository_impl.dart';

class MockAssetLocal extends Mock implements AssetLocalDataSource {}

class MockAssetRemote extends Mock implements AssetRemoteDataSource {}

AssetModel _makeModel(int assetId) => AssetModel(
      id: 0,
      assetId: assetId,
      equipmentType: 'Type $assetId',
      isActive: true,
      isCondemned: false,
      isProvisional: false,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAssetLocal mockLocal;
  late MockAssetRemote mockRemote;
  late AssetRepositoryImpl repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockLocal = MockAssetLocal();
    mockRemote = MockAssetRemote();
    repo = AssetRepositoryImpl(local: mockLocal, remote: mockRemote);
  });

  group('syncAssets', () {
    test('fetches one page when batch size < 500', () async {
      final batch = List.generate(3, _makeModel);
      when(() => mockRemote.getAssets(page: 1, pageSize: 500))
          .thenAnswer((_) async => batch);
      when(() => mockLocal.upsertAll(any())).thenAnswer((_) async {});

      await repo.syncAssets();

      verify(() => mockRemote.getAssets(page: 1, pageSize: 500)).called(1);
      verify(() => mockLocal.upsertAll(batch)).called(1);
      // Only 1 page because batch.length (3) < 500.
      verifyNever(() => mockRemote.getAssets(page: 2, pageSize: 500));
    });

    test('fetches multiple pages when first batch is full', () async {
      final fullBatch = List.generate(500, _makeModel);
      final lastBatch = List.generate(10, (i) => _makeModel(i + 500));

      when(() => mockRemote.getAssets(page: 1, pageSize: 500))
          .thenAnswer((_) async => fullBatch);
      when(() => mockRemote.getAssets(page: 2, pageSize: 500))
          .thenAnswer((_) async => lastBatch);
      when(() => mockLocal.upsertAll(any())).thenAnswer((_) async {});

      await repo.syncAssets();

      verify(() => mockRemote.getAssets(page: 1, pageSize: 500)).called(1);
      verify(() => mockRemote.getAssets(page: 2, pageSize: 500)).called(1);
      verifyNever(() => mockRemote.getAssets(page: 3, pageSize: 500));
    });

    test('rethrows remote exceptions', () async {
      when(() => mockRemote.getAssets(page: 1, pageSize: 500))
          .thenThrow(Exception('network error'));

      await expectLater(repo.syncAssets(), throwsA(isA<Exception>()));
    });

    test('writes assets_last_synced timestamp on success', () async {
      final batch = List.generate(2, _makeModel);
      when(() => mockRemote.getAssets(page: 1, pageSize: 500))
          .thenAnswer((_) async => batch);
      when(() => mockLocal.upsertAll(any())).thenAnswer((_) async {});

      await repo.syncAssets();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('assets_last_synced'), isNotNull);
    });
  });

  group('getAssets', () {
    test('delegates to local datasource', () async {
      final assets = [_makeModel(1), _makeModel(2)];
      when(() => mockLocal.getAssets(hospital: any(named: 'hospital')))
          .thenAnswer((_) async => assets);

      final result = await repo.getAssets(hospital: 'St. Mary');

      expect(result, assets);
      verify(() => mockLocal.getAssets(hospital: 'St. Mary')).called(1);
    });
  });
}
