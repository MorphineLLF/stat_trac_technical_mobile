import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/sync/upload/sync_upload_batch.dart';

void main() {
  group('capture', () {
    test('is an action on Repair carrying the job', () {
      final op = SyncUploadOp.capture(
        mobileId: 'wo-1',
        data: const {'asset_id': 1234, 'work_type': 1},
      ).toJson();

      expect(op['table'], 'Repair');
      expect(op['mobile_id'], 'wo-1');
      expect(op['action'], 'capture');
      expect(op['data'], {'asset_id': 1234, 'work_type': 1});
    });

    // The server writes the technician from the token. A device able to
    // name one could file work under somebody else.
    for (final key in ['tech', 'tech_id', 'RepairTech', 'RepairTechID']) {
      test('refuses a technician field: $key', () {
        expect(
          () => SyncUploadOp.capture(mobileId: 'wo-1', data: {key: 'x'}),
          throwsArgumentError,
        );
      });
    }
  });

  test('sign can name Repair', () {
    final op = SyncUploadOp.sign(
      table: 'Repair',
      mobileId: 'wo-1',
      which: SignatureSide.client,
      png: 'AAAA',
      clientName: 'Sister Dlamini',
    ).toJson();

    expect(op['table'], 'Repair');
    expect(op['action'], 'sign');
    expect(op['data'], {
      'which': 'client',
      'png': 'AAAA',
      'client_name': 'Sister Dlamini',
    });
  });

  test('sign still defaults to the certificate', () {
    final op = SyncUploadOp.sign(
      mobileId: 'c-1',
      which: SignatureSide.tech,
      png: 'AAAA',
    ).toJson();
    expect(op['table'], 'TestCertificate');
  });
}
