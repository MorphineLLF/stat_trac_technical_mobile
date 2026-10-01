import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stat_trac_technical/sync/upload/sync_upload_client.dart';
import 'package:stat_trac_technical/sync/upload/sync_upload_result.dart';
import 'package:stat_trac_technical/sync/upload/upload_archive.dart';
import 'package:stat_trac_technical/sync/upload/upload_queue.dart';
import 'package:stat_trac_technical/sync/upload/upload_worker.dart';
import 'package:stat_trac_technical/sync/upload/work_order_upload.dart';

class MockClient extends Mock implements SyncUploadClient {}

WorkOrderUpload _wo(String id) => WorkOrderUpload(
  mobileId: id,
  capture: const {'asset_id': 1234, 'work_type': 1},
  techPng: 'AAAA',
  clientPng: 'BBBB',
  clientName: 'Sister Dlamini',
);

const _ready = ['batch_atomic', 'capture_action', 'job_sign_action'];

void main() {
  sqfliteFfiInit();
  setUpAll(() => registerFallbackValue(_wo('fallback')));

  late Database db;
  late UploadQueue queue;
  late UploadArchive archive;
  late MockClient client;
  late UploadWorker worker;
  late List<(String, int)> confirmed;

  setUp(() async {
    UploadWorker.forgetServer();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await UploadQueue.createTable(db);
    await UploadArchive.createTable(db);
    queue = UploadQueue(db);
    archive = UploadArchive(db);
    client = MockClient();
    confirmed = [];
    worker = UploadWorker(
      queue: queue,
      archive: archive,
      client: client,
      confirm: (m, s) async {
        confirmed.add((m, s));
        return true;
      },
      company: () async => 'demo',
      deviceToken: () async => 'token',
    );
  });

  tearDown(() async => db.close());

  void answers(SyncUploadResult r) => when(
    () => client.upload(
      company: any(named: 'company'),
      deviceToken: any(named: 'deviceToken'),
      upload: any(named: 'upload'),
    ),
  ).thenAnswer((_) async => r);

  int sends() => verify(
    () => client.upload(
      company: any(named: 'company'),
      deviceToken: any(named: 'deviceToken'),
      upload: any(named: 'upload'),
    ),
  ).callCount;

  test('applied: archived, then gone from the queue, never confirmed as a '
      'certificate', () async {
    await queue.enqueue(_wo('wo-1'));
    answers(const UploadApplied(applied: 0, assigned: {'wo-1': 1801},
        issued: [], enforces: _ready));

    final r = await worker.drain();

    expect(r.applied, 1);
    expect(r.appliedWorkOrders, 1);
    expect(await queue.count(), 0);
    expect((await archive.all()).single.mobileId, 'wo-1');
    expect(confirmed, isEmpty);
  });

  // An older server refuses `capture` as a 400 and applies nothing. That is
  // "not ready yet", not a broken app — the job must wait, not be parked.
  test('a 400 from a server without the actions keeps the job pending',
      () async {
    await queue.enqueue(_wo('wo-1'));
    answers(const UploadClientError('"capture" is not something a device may '
        'ask for', enforces: ['batch_atomic']));

    final r = await worker.drain();

    final e = (await queue.all()).single;
    expect(e.status, UploadStatus.pending);
    expect(e.lastError, UploadWorker.serverNotReady);
    expect(r.waitingForServer, 1);
    expect(r.failed, 0);
  });

  test('once the server is known not to take them, it is not asked again',
      () async {
    await queue.enqueue(_wo('wo-1'));
    answers(const UploadClientError('no', enforces: ['batch_atomic']));
    await worker.drain();
    await worker.drain();

    expect(sends(), 1);
    expect((await queue.all()).single.status, UploadStatus.pending);
  });

  test('a 400 from a server that does take them is a real failure', () async {
    await queue.enqueue(_wo('wo-1'));
    answers(const UploadClientError('malformed', enforces: _ready));

    final r = await worker.drain();

    expect((await queue.all()).single.status, UploadStatus.failed);
    expect(r.failed, 1);
  });

  for (final reason in ['open_work_order', 'asset_on_loan', 'asset_inactive',
      'not_found', 'already_signed']) {
    test('$reason sets the job aside and never deletes it', () async {
      await queue.enqueue(_wo('wo-1'));
      answers(UploadRejected([
        UploadRejection(table: 'Repair', mobileId: 'wo-1', reason: reason,
            message: 'refused'),
      ], enforces: _ready));

      await worker.drain();

      final e = (await queue.all()).single;
      expect(e.status, UploadStatus.rejected);
      expect(e.reason, reason);
    });
  }

  test('invalid keeps the field', () async {
    await queue.enqueue(_wo('wo-1'));
    answers(const UploadRejected([
      UploadRejection(table: 'Repair', mobileId: 'wo-1', reason: 'invalid',
          message: 'Choose the type of work', field: 'jobworktype'),
    ], enforces: _ready));

    await worker.drain();

    expect((await queue.all()).single.field, 'jobworktype');
  });

  test('no signal: stays pending, unchanged, for the identical resend',
      () async {
    final wo = _wo('wo-1');
    await queue.enqueue(wo);
    answers(const UploadTransportError(0, 'Cannot reach the server.'));

    await worker.drain();

    final e = (await queue.all()).single;
    expect(e.status, UploadStatus.pending);
    expect(e.upload.toJson(), wo.toJson());
  });
}
