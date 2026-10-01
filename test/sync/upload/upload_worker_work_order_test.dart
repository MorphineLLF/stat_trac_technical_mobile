import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stat_trac_technical/sync/upload/certificate_upload.dart';
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
    answers(
      const UploadApplied(
        applied: 0,
        assigned: {'wo-1': 1801},
        issued: [],
        enforces: _ready,
      ),
    );

    final r = await worker.drain();

    expect(r.applied, 1);
    expect(r.appliedWorkOrders, 1);
    expect(await queue.count(), 0);
    expect((await archive.all()).single.mobileId, 'wo-1');
    expect(confirmed, isEmpty);
  });

  // An older server refuses `capture` as a 400 and applies nothing. That is
  // "not ready yet", not a broken app — the job must wait, not be parked.
  test(
    'a 400 from a server without the actions keeps the job pending',
    () async {
      await queue.enqueue(_wo('wo-1'));
      answers(
        const UploadClientError(
          '"capture" is not something a device may '
          'ask for',
          enforces: ['batch_atomic'],
        ),
      );

      final r = await worker.drain();

      final e = (await queue.all()).single;
      expect(e.status, UploadStatus.pending);
      expect(e.lastError, UploadWorker.serverNotReady);
      expect(r.waitingForServer, 1);
      expect(r.failed, 0);
    },
  );

  // Asked once per drain, not never again: a server updated after the gate
  // closed must be found out without anyone reinstalling the app.
  test('once the server is known not to take them, it is asked once per '
      'drain', () async {
    await queue.enqueue(_wo('wo-1'));
    answers(const UploadClientError('no', enforces: ['batch_atomic']));
    await worker.drain();
    await worker.drain();

    expect(sends(), 2);
    expect((await queue.all()).single.status, UploadStatus.pending);
  });

  test(
    'a closed gate sends one probe per drain, however many are held',
    () async {
      await queue.enqueue(_wo('wo-1'));
      answers(const UploadClientError('no', enforces: ['batch_atomic']));
      await worker.drain();
      await queue.enqueue(_wo('wo-2'));
      clearInteractions(client);

      final r = await worker.drain();

      expect(sends(), 1);
      expect(r.waitingForServer, 2);
      final left = await queue.all();
      expect(left, hasLength(2));
      expect(left.every((e) => e.status == UploadStatus.pending), isTrue);
    },
  );

  test(
    'a server updated after the gate closed takes the held work orders',
    () async {
      await queue.enqueue(_wo('wo-1'));
      await queue.enqueue(_wo('wo-2'));
      answers(const UploadClientError('no', enforces: ['batch_atomic']));
      await worker.drain();
      expect(await queue.count(), 2);

      answers(
        const UploadApplied(
          applied: 0,
          assigned: {},
          issued: [],
          enforces: _ready,
        ),
      );
      final r = await worker.drain();

      expect(r.appliedWorkOrders, 2);
      expect(r.waitingForServer, 0);
      expect(await queue.count(), 0);
    },
  );

  test('a 400 from a server that does take them is a real failure', () async {
    await queue.enqueue(_wo('wo-1'));
    answers(const UploadClientError('malformed', enforces: _ready));

    final r = await worker.drain();

    expect((await queue.all()).single.status, UploadStatus.failed);
    expect(r.failed, 1);
  });

  for (final reason in [
    'open_work_order',
    'asset_on_loan',
    'asset_inactive',
    'not_found',
    'already_signed',
  ]) {
    test('$reason sets the job aside and never deletes it', () async {
      await queue.enqueue(_wo('wo-1'));
      answers(
        UploadRejected([
          UploadRejection(
            table: 'Repair',
            mobileId: 'wo-1',
            reason: reason,
            message: 'refused',
          ),
        ], enforces: _ready),
      );

      await worker.drain();

      final e = (await queue.all()).single;
      expect(e.status, UploadStatus.rejected);
      expect(e.reason, reason);
    });
  }

  test('invalid keeps the field', () async {
    await queue.enqueue(_wo('wo-1'));
    answers(
      const UploadRejected([
        UploadRejection(
          table: 'Repair',
          mobileId: 'wo-1',
          reason: 'invalid',
          message: 'Choose the type of work',
          field: 'jobworktype',
        ),
      ], enforces: _ready),
    );

    await worker.drain();

    expect((await queue.all()).single.field, 'jobworktype');
  });

  test(
    'no signal: stays pending, unchanged, for the identical resend',
    () async {
      final wo = _wo('wo-1');
      await queue.enqueue(wo);
      answers(const UploadTransportError(0, 'Cannot reach the server.'));

      await worker.drain();

      final e = (await queue.all()).single;
      expect(e.status, UploadStatus.pending);
      expect(e.upload.toJson(), wo.toJson());
    },
  );

  // The local size check never reached the server, so it says nothing about
  // what the server takes.
  test('a local too-large result does not close the work-order gate', () async {
    await queue.enqueue(
      CertificateUpload(
        mobileId: 'cert-big',
        certificate: const {'TestAssetID': 1},
        lines: const [],
      ),
    );
    await queue.enqueue(_wo('wo-1'));
    when(
      () => client.upload(
        company: any(named: 'company'),
        deviceToken: any(named: 'deviceToken'),
        upload: any(named: 'upload'),
      ),
    ).thenAnswer((i) async {
      final u = i.namedArguments[#upload] as dynamic;
      return u is WorkOrderUpload
          ? const UploadApplied(
              applied: 0,
              assigned: {'wo-1': 1801},
              issued: [],
              enforces: _ready,
            )
          : const UploadTooLarge('too big');
    });

    final r = await worker.drain();

    expect(sends(), 2);
    expect(r.waitingForServer, 0);
    expect(r.appliedWorkOrders, 1);
  });

  test('a held work order does not stop a certificate behind it', () async {
    await queue.enqueue(_wo('wo-1'));
    answers(const UploadClientError('no', enforces: ['batch_atomic']));
    await worker.drain();

    await queue.enqueue(
      CertificateUpload(
        mobileId: 'cert-1',
        certificate: const {'TestAssetID': 1},
        lines: const [],
      ),
    );
    when(
      () => client.upload(
        company: any(named: 'company'),
        deviceToken: any(named: 'deviceToken'),
        upload: any(named: 'upload'),
      ),
    ).thenAnswer((i) async {
      final u = i.namedArguments[#upload] as dynamic;
      // The work order is probed again and the server still refuses it.
      return u is WorkOrderUpload
          ? const UploadClientError('no', enforces: ['batch_atomic'])
          : const UploadApplied(
              applied: 1,
              assigned: {'cert-1': 77},
              issued: [],
              enforces: ['batch_atomic'],
            );
    });

    final r = await worker.drain();

    expect(r.applied, 1);
    expect(r.waitingForServer, 1);
    expect(confirmed, [('cert-1', 77)]);
    final left = await queue.all();
    expect(left.single.upload.mobileId, 'wo-1');
    expect(left.single.status, UploadStatus.pending);
  });
}
