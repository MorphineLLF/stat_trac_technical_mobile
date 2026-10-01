import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stat_trac_technical/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:stat_trac_technical/features/auth/presentation/providers/auth_providers.dart';
import 'package:stat_trac_technical/features/certification/data/datasources/cert_local_data_source.dart';
import 'package:stat_trac_technical/features/certification/presentation/providers/certificate_providers.dart';
import 'package:stat_trac_technical/sync/upload/upload_archive.dart';
import 'package:stat_trac_technical/sync/upload/upload_providers.dart';
import 'package:stat_trac_technical/sync/upload/upload_queue.dart';

class _Local extends Mock implements AuthLocalDataSource {}

class _CertLocal extends Mock implements CertLocalDataSource {}

// On the phone, pressing sync said "Could not send" and nothing ever reached
// the server: "Cannot use the Ref of uploadWorkerProvider after it has been
// disposed". The app reads the worker with ref.read(...future), which does
// not keep it alive, so it was disposed while it awaited the database — and
// the ref.watch that came AFTER that await threw. The delays here stand in
// for the real database opening.
void main() {
  sqfliteFfiInit();

  test('the worker is built even when nothing listens to it', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await UploadQueue.createTable(db);
    await UploadArchive.createTable(db);

    final container = ProviderContainer(
      overrides: [
        uploadQueueProvider.overrideWith((ref) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return UploadQueue(db);
        }),
        uploadArchiveProvider.overrideWith((ref) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return UploadArchive(db);
        }),
        authLocalDataSourceProvider.overrideWithValue(_Local()),
        certLocalDataSourceProvider.overrideWithValue(_CertLocal()),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(container.read(uploadWorkerProvider.future), completes);
  });
}
