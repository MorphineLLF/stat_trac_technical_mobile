import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/features/work_orders/domain/work_order_summary.dart';

WorkOrderSummary synced(int id, String? mobile) =>
    WorkOrderSummary(trackId: id, mobileId: mobile, status: 'WO Completed');

WorkOrderSummary queued(String mobile) => WorkOrderSummary(
  mobileId: mobile,
  status: 'Waiting to sync',
  queueState: WorkOrderQueueState.waiting,
);

void main() {
  test('queued first, then synced', () {
    final m = mergeWorklist(
      queued: [queued('wo-9')],
      synced: [synced(1, 'wo-1')],
    );
    expect([for (final w in m) w.mobileId], ['wo-9', 'wo-1']);
  });

  // Applied but the queue row not yet gone, or archived and synced in the
  // same moment: the synced row wins and the job shows once.
  test('a job that has synced is not also shown as queued', () {
    final m = mergeWorklist(
      queued: [queued('wo-1')],
      synced: [synced(1, 'wo-1')],
    );
    expect(m, hasLength(1));
    expect(m.single.trackId, 1);
  });
}
