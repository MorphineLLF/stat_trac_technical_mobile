import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stat_trac_technical/sync/upload/certificate_upload.dart';
import 'package:stat_trac_technical/sync/upload/upload_queue.dart';

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

  Future<void> park(String mobileId, Map<String, Object?> certificate) async {
    await queue.enqueue(
      CertificateUpload(
        mobileId: mobileId,
        certificate: certificate,
        lines: [
          CertificateLineUpload(mobileId: '$mobileId-l', data: const {'a': 1}),
        ],
      ),
    );
    await queue.markRejected(
      mobileId,
      reason: 'already_issued',
      message: 'this certificate has been issued and cannot be changed',
    );
  }

  // Certificates refused because the row op carried TestCertPatientSafe: the
  // column marked them issued, so the issue op behind it was refused and the
  // whole batch — readings included — rolled back. The work is still on the
  // device and the payload is one key away from being sendable.
  test('re-queues a certificate parked for carrying the verdict', () async {
    await park('cert-1', const {'TestAssetID': 9304, 'TestCertPatientSafe': 1});

    final repaired = await queue.repairVerdictInRowOp();

    expect(repaired, 1);
    final entry = (await queue.all()).single;
    expect(entry.status, UploadStatus.pending);
    expect(entry.upload.certificate.containsKey('TestCertPatientSafe'), isFalse);
    // Everything else survives — this is a repair, not a rewrite.
    expect(entry.upload.certificate['TestAssetID'], 9304);
    expect(entry.upload.lines, hasLength(1));
  });

  // Anything parked for another reason is left exactly where it is. A repair
  // that re-queues refusals it does not understand would send them back into
  // the same wall and teach a technician the queue is noise.
  test('leaves a rejection it does not explain alone', () async {
    await park('cert-2', const {'TestAssetID': 1});

    expect(await queue.repairVerdictInRowOp(), 0);
    expect((await queue.all()).single.status, UploadStatus.rejected);
  });

  test('does not disturb work that is waiting to go', () async {
    await queue.enqueue(
      CertificateUpload(
        mobileId: 'cert-3',
        certificate: const {'TestCertPatientSafe': 1},
        lines: const [],
      ),
    );

    expect(await queue.repairVerdictInRowOp(), 0);
    expect((await queue.all()).single.status, UploadStatus.pending);
  });

  test('runs twice without doing anything the second time', () async {
    await park('cert-4', const {'TestCertPatientSafe': 0});

    expect(await queue.repairVerdictInRowOp(), 1);
    expect(await queue.repairVerdictInRowOp(), 0);
  });

  test('keeps the payload readable as a payload', () async {
    await park('cert-5', const {'TestAssetID': 7, 'TestCertPatientSafe': 2});
    await queue.repairVerdictInRowOp();

    final row = (await db.query(UploadQueue.table)).single;
    expect(
      () => jsonDecode(row['payload']! as String),
      returnsNormally,
    );
  });
}
