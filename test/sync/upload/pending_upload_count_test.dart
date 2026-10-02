import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stat_trac_technical/sync/upload/certificate_upload.dart';
import 'package:stat_trac_technical/sync/upload/upload_providers.dart';
import 'package:stat_trac_technical/sync/upload/upload_queue.dart';
import 'package:stat_trac_technical/sync/upload/work_order_upload.dart';

void main() {
  sqfliteFfiInit();

  // The app bar's orange count. It counted certificates only, so a phone with
  // a certificate and a work order waiting showed "1" — two jobs not sent.
  test('counts certificates and work orders waiting to send', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await UploadQueue.createTable(db);
    final queue = UploadQueue(db);

    await queue.enqueue(
      CertificateUpload(
        mobileId: 'cert-1',
        certificate: const {'TestAssetID': 9304},
        lines: const [
          CertificateLineUpload(mobileId: 'l', data: {'TestPass': true}),
        ],
      ),
    );
    await queue.enqueue(
      WorkOrderUpload(
        mobileId: 'wo-1',
        capture: {'asset_id': 100, 'work_type': 1},
        techPng: 'A',
        clientPng: 'B',
        clientName: 'X',
      ),
    );

    final container = ProviderContainer(
      overrides: [uploadQueueProvider.overrideWith((ref) async => queue)],
    );
    addTearDown(container.dispose);

    expect(await container.read(pendingUploadCountProvider.future), 2);
  });
}
