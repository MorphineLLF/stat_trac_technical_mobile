import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stat_trac_technical/sync/upload/certificate_upload.dart';
import 'package:stat_trac_technical/sync/upload/upload_archive.dart';

CertificateUpload _upload(String id, {int lines = 23}) => CertificateUpload(
  mobileId: id,
  certificate: const {'TestAssetID': 9304},
  lines: [
    for (var i = 0; i < lines; i++)
      CertificateLineUpload(
        mobileId: 'line-$i',
        data: const {'TestPass': true},
      ),
  ],
);

void main() {
  sqfliteFfiInit();

  late Database db;
  late UploadArchive archive;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await UploadArchive.createTable(db);
    archive = UploadArchive(db);
  });

  tearDown(() async => db.close());

  test('records what was sent alongside what the server said it applied',
      () async {
    await archive.record(
      upload: _upload('cert-1'),
      applied: 24,
      assigned: const {'cert-1': 5031},
    );

    final entry = (await archive.all()).single;
    expect(entry.mobileId, 'cert-1');
    expect(entry.linesSent, 23);
    // The certificate op plus its 23 lines.
    expect(entry.opsSent, 24);
    expect(entry.applied, 24);
    expect(entry.shortBy, 0);
    expect(entry.isShort, isFalse);
  });

  test('a certificate applied without its lines is recorded as short',
      () async {
    await archive.record(
      upload: _upload('cert-2'),
      applied: 1,
      assigned: const {'cert-2': 5032},
    );

    final entry = (await archive.all()).single;
    expect(entry.opsSent, 24);
    expect(entry.applied, 1);
    expect(entry.shortBy, 23);
    expect(entry.isShort, isTrue);
  });

  test('keeps the payload so a lost upload can be read back after the fact',
      () async {
    await archive.record(
      upload: _upload('cert-3', lines: 2),
      applied: 3,
      assigned: const {},
    );

    final restored = (await archive.all()).single.upload;
    expect(restored.mobileId, 'cert-3');
    expect(restored.lines, hasLength(2));
    expect(restored.certificate['TestAssetID'], 9304);
  });

  test('a certificate re-queued after a rejection archives both attempts',
      () async {
    await archive.record(
      upload: _upload('cert-4'),
      applied: 1,
      assigned: const {},
    );
    await archive.record(
      upload: _upload('cert-4'),
      applied: 24,
      assigned: const {'cert-4': 5033},
    );

    expect(await archive.all(), hasLength(2));
  });

  test('newest first, so the run just made is the one read', () async {
    await archive.record(
      upload: _upload('older'),
      applied: 24,
      assigned: const {},
    );
    await archive.record(
      upload: _upload('newer'),
      applied: 24,
      assigned: const {},
    );

    expect((await archive.all()).first.mobileId, 'newer');
  });
}
