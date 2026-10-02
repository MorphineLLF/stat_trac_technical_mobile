import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stat_trac_technical/core/theme/app_theme.dart';
import 'package:stat_trac_technical/features/work_orders/presentation/providers/work_order_providers.dart';
import 'package:stat_trac_technical/features/work_orders/presentation/screens/work_order_detail_screen.dart';
import 'package:stat_trac_technical/sync/upload/upload_providers.dart';
import 'package:stat_trac_technical/sync/upload/upload_queue.dart';
import 'package:stat_trac_technical/sync/upload/work_order_upload.dart';

WorkOrderUpload _job({List<Map<String, Object?>>? parts}) => WorkOrderUpload(
  mobileId: 'wo-1',
  capture: {
    'asset_id': 100,
    'work_type': 1,
    'date_in': '2026-10-01',
    'time_in': '08:00',
    'date_out': '2026-10-01',
    'time_out': '09:00',
    'fault': '',
    'work': '',
    'note': '',
    'client_name': 'X',
    'job_card_no': '',
    'parts': ?parts,
  },
  techPng: 'AAAA',
  clientPng: 'BBBB',
  clientName: 'X',
);

/// A real in-memory outbox with [_job] set aside for [reason].
Future<UploadQueue> _queue(
  WidgetTester tester,
  String reason, {
  WorkOrderUpload? job,
}) async {
  final db = await tester.runAsync(
    () => databaseFactoryFfi.openDatabase(inMemoryDatabasePath),
  );
  await tester.runAsync(() => UploadQueue.createTable(db!));
  final queue = UploadQueue(db!);
  await tester.runAsync(() async {
    await queue.enqueue(job ?? _job());
    await queue.markRejected(
      'wo-1',
      reason: reason,
      message: 'The server said no',
      field: 'jobfault',
    );
  });
  return queue;
}

Future<void> _open(
  WidgetTester tester,
  UploadQueue queue, {
  WorkOrderUpload? signatures,
}) async {
  tester.view.physicalSize = const Size(1080, 2316);
  tester.view.devicePixelRatio = 1080 / 384;
  addTearDown(tester.view.reset);
  // Read up front: the queue's SQLite reads only finish on the real clock.
  final entry = (await tester.runAsync(queue.all))!.firstOrNull;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        uploadQueueProvider.overrideWith((ref) async => queue),
        queuedWorkOrderProvider('wo-1').overrideWith((ref) async => entry),
        phoneSignaturesProvider('wo-1').overrideWith((ref) async => signatures),
      ],
      child: MaterialApp(
        theme: appTheme,
        home: Builder(
          builder: (c) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(c).push(
                MaterialPageRoute<void>(
                  builder: (_) => const WorkOrderDetailScreen(mobileId: 'wo-1'),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a queued job lists its parts', (t) async {
    final q = await _queue(
      t,
      'invalid',
      job: _job(
        parts: [
          {'part_no': 'FUSE-5A', 'description': 'Fuse 5A', 'qty': 2.0},
          {'part_no': '', 'description': 'Travel 40 km', 'qty': 1.0, 'kind': 2},
        ],
      ),
    );
    await _open(t, q);
    await t.scrollUntilVisible(find.text('Travel 40 km'), 200);
    expect(find.text('× 2'), findsOneWidget);
    // Each line under its own heading, as on the job card.
    final parts = t.getTopLeft(find.text('Parts')).dy;
    final rates = t.getTopLeft(find.text('Charged rates')).dy;
    expect(
      t.getTopLeft(find.text('FUSE-5A — Fuse 5A')).dy,
      inExclusiveRange(parts, rates),
    );
    expect(t.getTopLeft(find.text('Travel 40 km')).dy, greaterThan(rates));
  });

  testWidgets('invalid: Fix and resend and Discard both offered', (t) async {
    final q = await _queue(t, 'invalid');
    await _open(t, q);
    expect(find.text('Set aside by the server'), findsOneWidget);
    // Below the fold on a phone; the list scrolls to it.
    await t.scrollUntilVisible(find.text('Discard'), 200);
    expect(find.text('Fix and resend'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);
  });

  testWidgets('open_work_order: no resend, only Discard', (t) async {
    final q = await _queue(t, 'open_work_order');
    await _open(t, q);
    expect(find.text('Fix and resend'), findsNothing);
    await t.scrollUntilVisible(find.text('Discard'), 200);
    expect(find.text('Discard'), findsOneWidget);
  });

  testWidgets('Keep leaves the row; Discard removes it', (t) async {
    final q = await _queue(t, 'open_work_order');
    await _open(t, q);
    // Below the fold on a phone; the list scrolls to it.
    await t.scrollUntilVisible(find.text('Discard'), 200);
    await t.ensureVisible(find.text('Discard'));
    await t.pumpAndSettle();

    await t.tap(find.text('Discard'));
    await t.pumpAndSettle();
    expect(find.text('Discard this work order?'), findsOneWidget);
    await t.tap(find.text('Keep'));
    await t.pumpAndSettle();
    expect((await t.runAsync(q.all))!.length, 1);

    await t.tap(find.text('Discard'));
    await t.pumpAndSettle();
    await t.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Discard'),
      ),
    );
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pumpAndSettle();
    expect((await t.runAsync(q.all))!, isEmpty);
    expect(find.byType(WorkOrderDetailScreen), findsNothing);
  });

  testWidgets('no phone signatures: says where they are', (t) async {
    final q = await _queue(t, 'invalid');
    await _open(t, q);
    expect(
      find.text('Signed on another device or at the office'),
      findsOneWidget,
    );
  });
}
