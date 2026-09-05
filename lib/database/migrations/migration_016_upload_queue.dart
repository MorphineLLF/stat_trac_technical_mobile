import 'package:sqflite/sqflite.dart';

import '../../sync/upload/upload_queue.dart';

/// The outbox a finished certificate waits in.
///
/// The table definition lives with the queue rather than here, so the code
/// that reads it and the code that creates it cannot drift apart — and so the
/// tests can build the same table in memory.
Future<void> migration016UploadQueue(Database db) async {
  await UploadQueue.createTable(db);
}
