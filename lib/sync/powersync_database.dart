import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';

import 'powersync_schema.dart';

/// Opens the device's PowerSync database.
///
/// This is deliberately thin wiring. It cannot be exercised by a unit test —
/// it needs PowerSync's native libraries and a real filesystem — so the
/// testable behaviour lives next door: the schema's guarantees in
/// `powersync_schema_test.dart` and the credentials logic in
/// `stat_trac_connector_test.dart`. Keep this file small enough that there is
/// little here to be wrong.
///
/// It lives in the application support directory rather than a cache
/// directory: the sync database is not disposable, and a technician three
/// weeks offline holds unuploaded work in it.
Future<PowerSyncDatabase> openSyncDatabase() async {
  final dir = await getApplicationSupportDirectory();
  final db = PowerSyncDatabase(
    schema: schema,
    path: p.join(dir.path, 'stattrac_sync.sqlite'),
  );
  await db.initialize();
  return db;
}
