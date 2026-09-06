import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stat_trac_technical/sync/upload/certificate_upload.dart';
import 'package:stat_trac_technical/sync/upload/sync_upload_client.dart';
import 'package:stat_trac_technical/sync/upload/sync_upload_result.dart';
import 'package:stat_trac_technical/sync/upload/upload_archive.dart';
import 'package:stat_trac_technical/sync/upload/upload_queue.dart';
import 'package:stat_trac_technical/sync/upload/upload_worker.dart';

class MockClient extends Mock implements SyncUploadClient {}

CertificateUpload _upload(String id) => CertificateUpload(
  mobileId: id,
  certificate: const {'TestAssetID': 9304},
  lines: const [CertificateLineUpload(mobileId: 'l', data: {'TestPass': true})],
);

void main() {
  sqfliteFfiInit();
  setUpAll(() => registerFallbackValue(_upload('fallback')));

  late Database db;
  late UploadQueue queue;
  late UploadArchive archive;
  late MockClient client;
  late UploadWorker worker;
  late List<(String, int)> confirmed;

  setUp(() async {
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
      confirm: (mobileId, serverId) async {
        confirmed.add((mobileId, serverId));
        return true;
      },
      company: () async => 'demo',
      deviceToken: () async => 'token',
    );
  });

  tearDown(() async => db.close());

  void answers(SyncUploadResult r) {
    when(
      () => client.upload(
        company: any(named: 'company'),
        deviceToken: any(named: 'deviceToken'),
        upload: any(named: 'upload'),
      ),
    ).thenAnswer((_) async => r);
  }

  test('sends nothing when the queue is empty', () async {
    final sent = await worker.drain();

    expect(sent.attempted, 0);
    verifyNever(
      () => client.upload(
        company: any(named: 'company'),
        deviceToken: any(named: 'deviceToken'),
        upload: any(named: 'upload'),
      ),
    );
  });

  test('an applied certificate leaves the queue', () async {
    await queue.enqueue(_upload('cert-1'));
    answers(const UploadApplied(applied: 2, assigned: {'cert-1': 5031},
        issued: []));

    final result = await worker.drain();

    expect(result.applied, 1);
    expect(await queue.count(), 0);
  });

  test('a rejection is kept with its message and not retried', () async {
    await queue.enqueue(_upload('cert-1'));
    answers(const UploadRejected([
      UploadRejection(
        table: 'TestCertificate',
        mobileId: 'cert-1',
        reason: 'incomplete_values',
        message: 'not every test has a reading against it',
      ),
    ]));

    await worker.drain();

    final entry = (await queue.all()).single;
    expect(entry.status, UploadStatus.rejected);
    expect(entry.reason, 'incomplete_values');
    expect(await queue.pending(), isEmpty);

    // A second drain must not send it again — the answer will not change.
    await worker.drain();
    verify(
      () => client.upload(
        company: any(named: 'company'),
        deviceToken: any(named: 'deviceToken'),
        upload: any(named: 'upload'),
      ),
    ).called(1);
  });

  test('a conflict is kept for a person to resolve', () async {
    await queue.enqueue(_upload('cert-1'));
    answers(const UploadConflict([
      UploadRowConflict(
        table: 'TestCertificate',
        mobileId: 'cert-1',
        fields: [
          UploadFieldDiff(
            field: 'TestDate',
            mine: '2026-09-05',
            server: '2026-01-31',
            differs: true,
          ),
        ],
      ),
    ]));

    await worker.drain();

    final entry = (await queue.all()).single;
    expect(entry.status, UploadStatus.conflicted);
    expect(entry.lastError, contains('TestDate'));
  });

  test('a transport failure stays pending and stops the run', () async {
    await queue.enqueue(_upload('cert-1'));
    await queue.enqueue(_upload('cert-2'));
    answers(const UploadTransportError(0, 'no signal'));

    final result = await worker.drain();

    // Signal did not come back between two certificates; sending the second
    // would only fail the same way and burn a technician's battery.
    expect(result.attempted, 1);
    expect((await queue.pending()), hasLength(2));
    expect((await queue.pending()).first.attempts, 1);
  });

  test('a client error is held for a developer, not the technician', () async {
    await queue.enqueue(_upload('cert-1'));
    answers(const UploadClientError('unknown field "complete_pm_workorder"'));

    await worker.drain();

    expect((await queue.all()).single.status, UploadStatus.failed);
  });

  test('does nothing at all when there is no device token', () async {
    await queue.enqueue(_upload('cert-1'));
    final signedOut = UploadWorker(
      queue: queue,
      archive: archive,
      client: client,
      confirm: (_, _) async => true,
      company: () async => 'demo',
      deviceToken: () async => null,
    );

    final result = await signedOut.drain();

    expect(result.attempted, 0);
    expect(await queue.pending(), hasLength(1));
  });

  test('a certificate applied without its readings is reported, not counted '
      'as a clean success', () async {
    // The batch is the certificate plus one reading, so the server applying
    // one row op means the reading did not land. A 200 said success and the
    // count that contradicted it used to be discarded.
    await queue.enqueue(_upload('cert-1'));
    answers(const UploadApplied(applied: 1, assigned: {'cert-1': 5031},
        issued: []));

    final result = await worker.drain();

    expect(result.applied, 1);
    expect(result.shortApplied, 1);

    final entry = (await archive.shortApplies()).single;
    expect(entry.mobileId, 'cert-1');
    expect(entry.opsSent, 2);
    expect(entry.applied, 1);
    expect(entry.shortBy, 1);
  });

  test('a full apply is archived with nothing short', () async {
    await queue.enqueue(_upload('cert-1'));
    answers(const UploadApplied(applied: 2, assigned: {'cert-1': 5031},
        issued: []));

    final result = await worker.drain();

    expect(result.shortApplied, 0);
    expect(await archive.shortApplies(), isEmpty);

    final entry = (await archive.all()).single;
    expect(entry.opsSent, 2);
    expect(entry.applied, 2);
    expect(entry.assigned['cert-1'], 5031);
  });

  test('the payload survives the queue row being deleted', () async {
    await queue.enqueue(_upload('cert-1'));
    answers(const UploadApplied(applied: 1, assigned: {}, issued: []));

    await worker.drain();

    // The queue is drained, which is what destroyed the evidence before.
    expect(await queue.count(), 0);
    expect((await archive.all()).single.upload.lines, hasLength(1));
  });

  test('the server key is written back against the mobile id', () async {
    // Without this the device can never say its own work landed: the server
    // names the certificate by the uuid it travelled under and by nothing
    // else, and the queue row is gone the moment it succeeds.
    await queue.enqueue(_upload('cert-1'));
    answers(const UploadApplied(applied: 2, assigned: {'cert-1': 5031},
        issued: []));

    await worker.drain();

    expect(confirmed, [('cert-1', 5031)]);
  });

  test('nothing is written back when the server assigned no key', () async {
    await queue.enqueue(_upload('cert-1'));
    answers(const UploadApplied(applied: 2, assigned: {}, issued: []));

    await worker.drain();

    expect(confirmed, isEmpty);
  });

  test('a server that will not promise a cert ref is reported, not trusted',
      () async {
    await queue.enqueue(_upload('cert-1'));
    // A 200 with no enforces: the shape of the build that orphaned 46
    // readings while reporting success.
    answers(const UploadApplied(applied: 2, assigned: {'cert-1': 5031},
        issued: []));

    final result = await worker.drain();

    expect(result.applied, 1);
    expect(result.unguaranteed, 1);
  });

  test('a server that does promise it is not flagged', () async {
    await queue.enqueue(_upload('cert-1'));
    answers(const UploadApplied(
      applied: 2,
      assigned: {'cert-1': 5031},
      issued: [],
      enforces: ['cert_ref_required'],
    ));

    final result = await worker.drain();

    expect(result.unguaranteed, 0);
  });

  test('already_signed clears the queue instead of holding it', () async {
    // The certificate has the signature. Calling that a rejection teaches a
    // technician to ignore the queue.
    await queue.enqueue(_upload('cert-1'));
    answers(const UploadRejected([
      UploadRejection(
        table: 'TestCertificate',
        mobileId: 'cert-1',
        reason: 'already_signed',
        message: 'that side has already signed',
      ),
    ]));

    final result = await worker.drain();

    expect(result.rejected, 0);
    expect(result.applied, 1);
    expect(await queue.count(), 0);
  });

  test('no_client_signature is held for the technician', () async {
    await queue.enqueue(_upload('cert-1'));
    answers(const UploadRejected([
      UploadRejection(
        table: 'TestCertificate',
        mobileId: 'cert-1',
        reason: 'no_client_signature',
        message: 'this design does not ask for a client signature',
      ),
    ]));

    await worker.drain();

    final entry = (await queue.all()).single;
    expect(entry.status, UploadStatus.rejected);
    expect(entry.reason, 'no_client_signature');
  });
}
