import 'package:flutter_test/flutter_test.dart';
import 'package:powersync/powersync.dart';
import 'package:stat_trac_technical/sync/powersync_schema.dart';

Table _table(String name) =>
    schema.tables.firstWhere((t) => t.name == name);

Iterable<String> _columnNames(String table) =>
    _table(table).columns.map((c) => c.name);

void main() {
  group('powersync schema', () {
    test('declares the tables this app reads', () {
      final names = schema.tables.map((t) => t.name).toSet();
      expect(
        names,
        containsAll([
          'Asset',
          'AssetPmTask',
          'Repair',
          'RepairDetail',
          'RepairProgress',
          'TestCertificate',
          'TestOutput',
          'TestTemplateName',
          'TestTemplate',
          'ComboStatus',
        ]),
      );
    });

    // PowerSync gives every table a text `id` and the sync rules alias the
    // real key to it. Declaring one would collide with that.
    test('never declares an id column', () {
      for (final table in schema.tables) {
        expect(
          table.columns.map((c) => c.name),
          isNot(contains('id')),
          reason: '${table.name} declares an id column',
        );
      }
    });

    // Signatures are bytea. PowerSync delivered null for every one of them,
    // so they are omitted deliberately — a column that is always null is
    // worse than its absence. Binary transport is a separate mechanism.
    test('omits the bytea signature columns', () {
      expect(
        _columnNames('TestCertificate'),
        isNot(anyOf(
          contains('TestTechSignature'),
          contains('TestClientSignature'),
        )),
      );
      expect(
        _columnNames('Repair'),
        isNot(anyOf(
          contains('RepairTechSignature'),
          contains('RepairClientSignature'),
        )),
      );
    });

    // numeric arrives as a STRING. Typing these as integer or real would
    // silently drop the value.
    test('maps numeric columns to text', () {
      final assetPrice = _table('Asset')
          .columns
          .firstWhere((c) => c.name == 'AssetPurchasePrice');
      expect(assetPrice.type, ColumnType.text);

      final progressHrs = _table('RepairProgress')
          .columns
          .firstWhere((c) => c.name == 'ProgressHrs');
      expect(progressHrs.type, ColumnType.text);
    });

    // Postgres booleans arrive as 0/1.
    test('maps boolean columns to integer', () {
      for (final name in ['TestPass', 'TestFail', 'TestNA']) {
        final column =
            _table('TestOutput').columns.firstWhere((c) => c.name == name);
        expect(column.type, ColumnType.integer, reason: name);
      }
    });

    // The client-generated ids from migration 023 are what uploadData will
    // key on, so their absence would be silent breakage.
    test('carries the client-generated mobile id columns', () {
      expect(_columnNames('TestCertificate'), contains('TestMobileID'));
      expect(_columnNames('TestOutput'), contains('TestOutputMobileID'));
      expect(_columnNames('Repair'), contains('RepairMobileID'));
      expect(_columnNames('RepairDetail'), contains('RepairDetailMobileID'));
      expect(_columnNames('RepairProgress'), contains('ProgressMobileID'));
    });

    // Optimistic concurrency is detected on this column.
    test('carries SyncUpdatedAt on the writable tables', () {
      for (final table in [
        'Asset',
        'Repair',
        'RepairDetail',
        'RepairProgress',
        'TestCertificate',
        'TestOutput',
      ]) {
        expect(_columnNames(table), contains('SyncUpdatedAt'),
            reason: table);
      }
    });
  });
}
