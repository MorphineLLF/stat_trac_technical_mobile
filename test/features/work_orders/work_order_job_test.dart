import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/features/work_orders/domain/work_order_job.dart';
import 'package:stat_trac_technical/features/work_orders/domain/work_type.dart';

WorkOrderJob job({
  WorkType? workType = WorkType.repair,
  DateTime? started,
  DateTime? finished,
  int? equipHrs,
  int? nop,
  String fault = '',
  String note = '',
  String clientName = 'Sister Dlamini',
  String jobCardNo = '',
}) => WorkOrderJob(
  assetId: 1234,
  workType: workType,
  started: started ?? DateTime(2026, 10, 1, 8, 15),
  finished: finished ?? DateTime(2026, 10, 1, 10, 40),
  equipHrs: equipHrs,
  nop: nop,
  fault: fault,
  note: note,
  clientName: clientName,
  jobCardNo: jobCardNo,
);

void main() {
  test('PM is never offered', () {
    expect(WorkType.values.map((w) => w.code), [1, 2, 3, 4, 6]);
    expect(WorkType.fromCode(5), isNull);
  });

  test('a complete job is valid', () {
    expect(job().validate(), isNull);
  });

  group('refuses as the server does', () {
    void refuses(WorkOrderJob j, String field, String message) {
      final e = j.validate();
      expect(e?.field, field);
      expect(e?.message, message);
    }

    test(
      'no work type',
      () => refuses(
        job(workType: null),
        'jobworktype',
        'Choose the type of work',
      ),
    );
    test(
      'no start',
      () => refuses(
        WorkOrderJob(
          assetId: 1,
          workType: WorkType.repair,
          finished: DateTime(2026),
        ),
        'datein',
        'The date in is needed',
      ),
    );
    test(
      'no finish',
      () => refuses(
        WorkOrderJob(
          assetId: 1,
          workType: WorkType.repair,
          started: DateTime(2026),
        ),
        'dateout',
        'The date completed is needed',
      ),
    );
    test(
      'finished on an earlier day',
      () => refuses(
        job(
          started: DateTime(2026, 10, 2, 8),
          finished: DateTime(2026, 10, 1, 9),
        ),
        'dateout',
        'The date completed is before the date in',
      ),
    );
    test(
      'negative hours',
      () => refuses(
        job(equipHrs: -1),
        'equiphrs',
        'Equipment hours cannot be negative',
      ),
    );
    // Stricter than the server here, and deliberately: the server checks
    // only for a negative, and a larger number fails the database's integer
    // column as a 500 that holds the whole queue for ever.
    test(
      'hours too large',
      () => refuses(
        job(equipHrs: 1000000000),
        'equiphrs',
        'Equipment hours is too large',
      ),
    );
    test(
      'N.O.P too large',
      () => refuses(job(nop: 1000000000), 'nop', 'N.O.P is too large'),
    );
    test('the largest nine-digit values are allowed', () {
      expect(job(equipHrs: 999999999, nop: 999999999).validate(), isNull);
    });
    test(
      'fault too long',
      () => refuses(
        job(fault: 'x' * 201),
        'jobfault',
        'The fault is longer than 200 characters',
      ),
    );
    test(
      'notes too long',
      () => refuses(
        job(note: 'x' * 101),
        'jobnote',
        'Comments is longer than 100 characters',
      ),
    );
    test(
      'job card no too long',
      () => refuses(
        job(jobCardNo: 'x' * 31),
        'jobcardno',
        'The job card no is longer than 30 characters',
      ),
    );
  });

  // The server compares dates, not times. A job that ends earlier in the
  // clock on the same day is the server's to judge, and the phone must not be
  // stricter than the server.
  test('same day, time out before time in, is allowed', () {
    expect(
      job(
        started: DateTime(2026, 10, 1, 10),
        finished: DateTime(2026, 10, 1, 9),
      ).validate(),
      isNull,
    );
  });

  test('wire shape', () {
    expect(job(equipHrs: 5120, fault: ' Beeps ').toWire(), {
      'asset_id': 1234,
      'work_type': 1,
      'date_in': '2026-10-01',
      'time_in': '08:15',
      'date_out': '2026-10-01',
      'time_out': '10:40',
      'equip_hrs': 5120,
      'fault': 'Beeps',
      'work': '',
      'note': '',
      'client_name': 'Sister Dlamini',
      'job_card_no': '',
    });
  });

  test('wire round trip', () {
    final j = job(equipHrs: 7, fault: 'Beeps');
    expect(WorkOrderJob.fromWire(j.toWire()).toWire(), j.toWire());
  });
}
