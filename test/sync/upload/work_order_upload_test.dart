import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/sync/upload/queued_upload.dart';
import 'package:stat_trac_technical/sync/upload/work_order_upload.dart';

WorkOrderUpload upload() => WorkOrderUpload(
  mobileId: 'wo-1',
  capture: const {'asset_id': 1234, 'work_type': 1, 'date_in': '2026-10-01'},
  techPng: 'AAAA',
  clientPng: 'BBBB',
  clientName: 'Sister Dlamini',
);

void main() {
  test('one batch: capture, then the technician, then the client', () {
    final ops = [for (final op in upload().toBatch().ops) op.toJson()];

    expect([for (final o in ops) o['action']], ['capture', 'sign', 'sign']);
    expect({for (final o in ops) o['mobile_id']}, {'wo-1'});
    expect({for (final o in ops) o['table']}, {'Repair'});
    expect((ops[1]['data']! as Map)['which'], 'tech');
    expect((ops[2]['data']! as Map)['which'], 'client');
    expect((ops[2]['data']! as Map)['client_name'], 'Sister Dlamini');
  });

  // A resend after a lost reply must be the same batch, or the server's
  // replay rule cannot recognise it.
  test('the batch is identical every time it is built', () {
    final u = upload();
    expect(
      [for (final op in u.toBatch().ops) op.toJson()],
      [for (final op in u.toBatch().ops) op.toJson()],
    );
  });

  test('round trips through the queue as a work order', () {
    final restored = fromQueuedJson(upload().toJson());
    expect(restored, isA<WorkOrderUpload>());
    final w = restored as WorkOrderUpload;
    expect(w.mobileId, 'wo-1');
    expect(w.queueKey, 'wo-1');
    expect(w.capture['asset_id'], 1234);
    expect(w.techPng, 'AAAA');
    expect(w.clientPng, 'BBBB');
    expect(w.clientName, 'Sister Dlamini');
  });

  test('both signatures and a client name are required', () {
    expect(
      () => WorkOrderUpload(mobileId: 'w', capture: const {}, techPng: '',
          clientPng: 'B', clientName: 'x'),
      throwsArgumentError,
    );
    expect(
      () => WorkOrderUpload(mobileId: 'w', capture: const {}, techPng: 'A',
          clientPng: '', clientName: 'x'),
      throwsArgumentError,
    );
    expect(
      () => WorkOrderUpload(mobileId: 'w', capture: const {}, techPng: 'A',
          clientPng: 'B', clientName: '  '),
      throwsArgumentError,
    );
  });
}
