import 'package:sqflite/sqflite.dart';

import '../../sync/upload/upload_archive.dart';

/// What was sent and what the server said it applied, kept after the queue row
/// is gone.
///
/// As with the outbox, the table definition lives with the code that reads it
/// so the two cannot drift, and so the tests build the same table in memory.
Future<void> migration017UploadArchive(Database db) async {
  await UploadArchive.createTable(db);
}
