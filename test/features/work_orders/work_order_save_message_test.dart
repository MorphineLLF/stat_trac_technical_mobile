import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/features/work_orders/presentation/screens/create_work_order_screen.dart';
import 'package:stat_trac_technical/sync/upload/upload_run_message.dart';

void main() {
  // The send right after Save went through: saying "waiting to sync" sent the
  // technician looking for a count that was rightly 0.
  test('a job sent straight away says it was sent', () {
    expect(
      workOrderSaveMessage(
        const UploadRunMessage('Sent 1 work order.', UploadMessageTone.success),
      ),
      'Sent 1 work order.',
    );
  });

  test('no send result: saved, waiting to sync', () {
    expect(workOrderSaveMessage(null), 'Saved — waiting to sync');
    expect(
      workOrderSaveMessage(
        const UploadRunMessage(
          'Nothing waiting to send.',
          UploadMessageTone.quiet,
        ),
      ),
      'Saved — waiting to sync',
    );
  });

  test('a warning or an alarm is said as it is', () {
    const offline = UploadRunMessage(
      'No connection — 1 still queued.',
      UploadMessageTone.warning,
    );
    const refused = UploadRunMessage(
      '1 could not be sent — open it to see why.',
      UploadMessageTone.alarm,
    );
    expect(workOrderSaveMessage(offline), offline.text);
    expect(workOrderSaveMessage(refused), refused.text);
  });
}
