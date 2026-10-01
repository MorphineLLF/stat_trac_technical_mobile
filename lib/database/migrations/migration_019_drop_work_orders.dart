import 'package:sqflite/sqflite.dart';

import '../../sync/upload/upload_queue.dart';

/// v19 — the Horse-era work-order tables go, and a refusal can name its field.
///
/// The four tables sat behind dashboard tiles that were switched off in every
/// released build, so they hold nothing. Work orders are read from PowerSync
/// and wait to upload in `upload_queue`. `change_log` stays; this migration
/// does not touch it.
///
/// `field` carries the server's `ValidationError` field on a refusal, so a
/// set-aside work order can reopen at the box that was wrong. Guarded, because
/// a fresh install creates the queue with the column already.
Future<void> migration019DropWorkOrders(DatabaseExecutor db) async {
  for (final table in [
    'work_order_signatures',
    'work_order_photos',
    'work_order_status_history',
    'work_orders',
  ]) {
    await db.execute('DROP TABLE IF EXISTS $table');
  }

  final cols = await db.rawQuery('PRAGMA table_info(${UploadQueue.table})');
  if (!cols.any((c) => c['name'] == 'field')) {
    await db.execute('ALTER TABLE ${UploadQueue.table} ADD COLUMN field TEXT');
  }
}
