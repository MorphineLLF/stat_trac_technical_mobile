import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stat_trac_technical/sync/upload/certificate_upload.dart';
import 'package:stat_trac_technical/sync/upload/upload_queue.dart';

CertificateUpload _upload(String id, {CertificateIssue? issue}) =>
    CertificateUpload(
      mobileId: id,
      certificate: const {'TestAssetID': 9304, 'TestDate': '2026-09-05'},
      lines: const [
        CertificateLineUpload(
          mobileId: 'line-0',
          data: {'TestDescription': 'Earth continuity', 'TestPass': true},
        ),
      ],
      issue: issue,
    );

void main() {
  sqfliteFfiInit();

  late Database db;
  late UploadQueue queue;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await UploadQueue.createTable(db);
    queue = UploadQueue(db);
  });

  tearDown(() async => db.close());

  group('queueing', () {
    test('a queued certificate survives being read back', () async {
      await queue.enqueue(_upload('cert-1'));

      final pending = await queue.pending();
      expect(pending, hasLength(1));
      expect(pending.single.upload.mobileId, 'cert-1');
      expect(pending.single.upload.certificate['TestAssetID'], 9304);
      expect(pending.single.upload.lines.single.mobileId, 'line-0');
    });

    test('the issue decisions survive the round trip', () async {
      await queue.enqueue(_upload(
        'cert-2',
        issue: const CertificateIssue(
          verdict: 0,
          notes: 'failed leakage',
          nextService: '2027-03-01',
          completePmWorkOrder: true,
        ),
      ));

      final issue = (await queue.pending()).single.upload.issue!;
      // 0 is Non-Compliant and must survive as 0, not as absent.
      expect(issue.verdict, 0);
      expect(issue.notes, 'failed leakage');
      expect(issue.nextService, '2027-03-01');
      expect(issue.completePmWorkOrder, isTrue);
      expect(issue.completePmJobCard, isFalse);
    });

    // A retried save must not queue the same certificate twice — the mobile
    // id is the identity, on the device as well as on the server.
    test('re-queueing the same certificate replaces rather than duplicates',
        () async {
      await queue.enqueue(_upload('cert-1'));
      await queue.enqueue(_upload('cert-1'));

      expect(await queue.pending(), hasLength(1));
    });
  });

  group('draining', () {
    // The whole point. A queue that cannot empty is the defect this codebase
    // has hit four times today in other guises.
    test('an applied certificate leaves the queue', () async {
      await queue.enqueue(_upload('cert-1'));
      await queue.markApplied('cert-1');

      expect(await queue.pending(), isEmpty);
      expect(await queue.count(), 0);
    });

    test('a conflicted certificate stays, and stays out of the retry set',
        () async {
      await queue.enqueue(_upload('cert-1'));
      await queue.markConflicted('cert-1', 'TestDate differs');

      expect(await queue.pending(), isEmpty);
      final all = await queue.all();
      expect(all.single.status, UploadStatus.conflicted);
      expect(all.single.lastError, contains('TestDate'));
    });

    // 422 is understood-and-refused. Retrying it forever would be the app
    // arguing with an answer.
    test('a rejected certificate keeps its reason and is not retried',
        () async {
      await queue.enqueue(_upload('cert-1'));
      await queue.markRejected(
        'cert-1',
        reason: 'incomplete_values',
        message: 'not every test has a reading against it',
      );

      expect(await queue.pending(), isEmpty);
      final entry = (await queue.all()).single;
      expect(entry.status, UploadStatus.rejected);
      expect(entry.reason, 'incomplete_values');
      expect(entry.lastError, contains('reading'));
    });

    // ...but the technician can fix it on the device and send it again, so
    // the state must be leavable.
    test('a rejected certificate can be re-queued after being corrected',
        () async {
      await queue.enqueue(_upload('cert-1'));
      await queue.markRejected('cert-1', reason: 'incomplete_values',
          message: 'x');
      await queue.enqueue(_upload('cert-1'));

      expect(await queue.pending(), hasLength(1));
      expect((await queue.all()).single.status, UploadStatus.pending);
    });
  });

  group('retrying', () {
    test('a transport failure stays pending and counts the attempt', () async {
      await queue.enqueue(_upload('cert-1'));
      await queue.markRetryable('cert-1', 'no signal');

      final entry = (await queue.pending()).single;
      expect(entry.status, UploadStatus.pending);
      expect(entry.attempts, 1);
      expect(entry.lastError, 'no signal');
    });

    test('oldest first, so work is sent in the order it was done', () async {
      await queue.enqueue(_upload('cert-1'));
      await queue.enqueue(_upload('cert-2'));

      final ids = (await queue.pending()).map((e) => e.upload.mobileId);
      expect(ids, ['cert-1', 'cert-2']);
    });
  });
}
