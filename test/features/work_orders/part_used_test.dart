import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/features/work_orders/domain/work_order_job.dart';
import 'package:stat_trac_technical/features/work_orders/domain/work_type.dart';

WorkOrderJob _job(List<PartUsed> parts) => WorkOrderJob(
  assetId: 100,
  workType: WorkType.values.first,
  started: DateTime(2026, 10, 2, 8),
  finished: DateTime(2026, 10, 2, 9),
  parts: parts,
);

void main() {
  group('wire', () {
    test('no lines, no parts key', () {
      expect(_job(const []).toWire().containsKey('parts'), isFalse);
    });

    // A part dropped from the register after the phone synced is kept by the
    // server as what the phone sent — so a picked line carries its name too.
    test('a picked line sends its id, number, description and qty', () {
      final w = _job(const [
        PartUsed(
          partId: 412,
          partNo: 'FUSE-5A',
          description: 'Fuse 5A',
          qty: 2,
        ),
      ]).toWire();
      expect(w['parts'], [
        {
          'part_id': 412,
          'part_no': 'FUSE-5A',
          'description': 'Fuse 5A',
          'qty': 2.0,
        },
      ]);
    });

    test('a typed line sends no part id', () {
      final w = _job(const [
        PartUsed(partNo: '', description: 'Cable tie', qty: 1.5),
      ]).toWire();
      expect(w['parts'], [
        {'part_no': '', 'description': 'Cable tie', 'qty': 1.5},
      ]);
    });

    test('back from the wire for Fix and resend', () {
      final job = _job(const [
        PartUsed(
          partId: 412,
          partNo: 'FUSE-5A',
          description: 'Fuse 5A',
          qty: 2,
        ),
        PartUsed(description: 'Cable tie', qty: 1.5),
      ]);
      final back = WorkOrderJob.fromWire(job.toWire());
      expect(back.parts.length, 2);
      expect(back.parts[0].partId, 412);
      expect(back.parts[1].picked, isFalse);
      expect(back.parts[1].qty, 1.5);
    });
  });

  group('validate', () {
    test('a line needs a code or a description', () {
      final e = _job(const [PartUsed(qty: 1)]).validate();
      expect(e?.field, 'parts[0].description');
    });

    test('a quantity of nought is refused, naming the line', () {
      final e = _job(const [
        PartUsed(description: 'a', qty: 1),
        PartUsed(description: 'b', qty: 0),
      ]).validate();
      expect(e?.field, 'parts[1].qty');
    });

    test('a code over 50 or a description over 100 is refused', () {
      expect(
        _job([PartUsed(partNo: 'x' * 51, qty: 1)]).validate()?.field,
        'parts[0].part_no',
      );
      expect(
        _job([PartUsed(description: 'x' * 101, qty: 1)]).validate()?.field,
        'parts[0].description',
      );
    });

    test('good lines pass', () {
      expect(_job(const [PartUsed(partNo: 'A1', qty: 0.5)]).validate(), isNull);
    });
  });

  group('quantity text', () {
    // A South African keyboard types a comma.
    test('reads a comma as a decimal point', () {
      expect(PartUsed.parseQty('1,5'), 1.5);
      expect(PartUsed.parseQty(' 2 '), 2);
      expect(PartUsed.parseQty(''), isNull);
      expect(PartUsed.parseQty('abc'), isNull);
    });

    test('shows whole numbers without .0', () {
      expect(const PartUsed(description: 'a', qty: 2).qtyText, '2');
      expect(const PartUsed(description: 'a', qty: 1.5).qtyText, '1.5');
    });
  });
}
