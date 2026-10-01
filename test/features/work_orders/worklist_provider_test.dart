import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stat_trac_technical/features/auth/domain/entities/user.dart';
import 'package:stat_trac_technical/features/auth/presentation/providers/auth_providers.dart';
import 'package:stat_trac_technical/features/auth/presentation/providers/auth_state.dart';
import 'package:stat_trac_technical/features/work_orders/data/powersync_work_order_data_source.dart';
import 'package:stat_trac_technical/features/work_orders/domain/work_order_summary.dart';
import 'package:stat_trac_technical/features/work_orders/presentation/providers/work_order_providers.dart';
import 'package:stat_trac_technical/sync/upload/upload_providers.dart';
import 'package:stat_trac_technical/sync/upload/certificate_upload.dart';
import 'package:stat_trac_technical/sync/upload/upload_archive.dart';
import 'package:stat_trac_technical/sync/upload/upload_queue.dart';
import 'package:stat_trac_technical/sync/upload/work_order_upload.dart';

class _Source extends Mock implements PowerSyncWorkOrderDataSource {}

class _SignedIn extends AuthNotifier {
  @override
  AuthState build() => const AuthAuthenticated(
    User(
      id: 31,
      name: 'Athi',
      email: '',
      role: UserRole.technician,
      technicianCode: '',
    ),
  );
}

void main() {
  sqfliteFfiInit();
  setUpAll(() => registerFallbackValue(<int>{}));

  late Database db;
  late UploadQueue queue;
  late UploadArchive archive;
  late _Source source;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await UploadQueue.createTable(db);
    await UploadArchive.createTable(db);
    queue = UploadQueue(db);
    archive = UploadArchive(db);
    source = _Source();
    when(() => source.assetsByIds(any())).thenAnswer((_) async => const {});
  });

  tearDown(() async => db.close());

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_SignedIn.new),
        uploadQueueProvider.overrideWith((ref) async => queue),
        uploadArchiveProvider.overrideWith((ref) async => archive),
        workOrderSourceProvider.overrideWith((ref) async => source),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('queued and synced together, the technician\'s own', () async {
    await queue.enqueue(
      WorkOrderUpload(
        mobileId: 'wo-9',
        capture: const {
          'asset_id': 100,
          'work_type': 1,
          'date_in': '2026-10-01',
          'time_in': '08:00',
        },
        techPng: 'A',
        clientPng: 'B',
        clientName: 'X',
      ),
    );
    when(() => source.capturedBy(31)).thenAnswer(
      (_) async => const SyncedWorklist([
        WorkOrderSummary(trackId: 1, mobileId: 'wo-1', status: 'WO Completed'),
      ], complete: true),
    );

    final list = await container().read(worklistProvider.future);

    expect([for (final w in list.items) w.mobileId], ['wo-9', 'wo-1']);
    expect(list.items.first.queueState, WorkOrderQueueState.waiting);
    expect(list.syncedComplete, isTrue);
  });

  test('a set-aside job carries the server\'s message', () async {
    await queue.enqueue(
      WorkOrderUpload(
        mobileId: 'wo-9',
        capture: const {'asset_id': 100, 'work_type': 1},
        techPng: 'A',
        clientPng: 'B',
        clientName: 'X',
      ),
    );
    await queue.markRejected(
      'wo-9',
      reason: 'open_work_order',
      message: 'Work order 1801 is still open on this machine',
    );
    when(
      () => source.capturedBy(31),
    ).thenAnswer((_) async => const SyncedWorklist([], complete: true));

    final w = (await container().read(worklistProvider.future)).items.single;

    expect(w.queueState, WorkOrderQueueState.setAside);
    expect(w.message, 'Work order 1801 is still open on this machine');
  });

  test('certificates in the queue are not work orders', () async {
    await queue.enqueue(
      CertificateUpload(
        mobileId: 'cert-1',
        certificate: const {'TestAssetID': 9304},
        lines: const [
          CertificateLineUpload(mobileId: 'l', data: {'TestPass': true}),
        ],
      ),
    );
    when(
      () => source.capturedBy(31),
    ).thenAnswer((_) async => const SyncedWorklist([], complete: false));

    final list = await container().read(worklistProvider.future);

    expect(list.items, isEmpty);
    expect(list.syncedComplete, isFalse);
  });

  group('phoneSignatures', () {
    final wo = WorkOrderUpload(
      mobileId: 'wo-9',
      capture: {'asset_id': 100, 'work_type': 1},
      techPng: 'A',
      clientPng: 'B',
      clientName: 'X',
    );

    test('from the queue while the job waits', () async {
      await queue.enqueue(wo);
      final got = await container().read(
        phoneSignaturesProvider('wo-9').future,
      );
      expect(got?.mobileId, 'wo-9');
      expect(got?.techPng, 'A');
    });

    test('from the archive once it has gone', () async {
      await archive.record(upload: wo, applied: 0, assigned: const {});
      final got = await container().read(
        phoneSignaturesProvider('wo-9').future,
      );
      expect(got?.clientPng, 'B');
    });

    test('null when this phone never had them', () async {
      expect(
        await container().read(phoneSignaturesProvider('wo-9').future),
        isNull,
      );
    });
  });
}
