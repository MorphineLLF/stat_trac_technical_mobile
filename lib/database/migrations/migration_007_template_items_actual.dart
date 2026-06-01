import 'package:sqflite/sqflite.dart';

Future<void> migration007TemplateItemsActual(Database db) async {
  await db.execute(
    'ALTER TABLE test_template_items ADD COLUMN actual_value_template TEXT',
  );
}
