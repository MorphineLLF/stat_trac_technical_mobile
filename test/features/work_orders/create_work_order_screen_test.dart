import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stat_trac_technical/core/theme/app_theme.dart';
import 'package:stat_trac_technical/features/auth/domain/entities/user.dart';
import 'package:stat_trac_technical/features/auth/presentation/providers/auth_providers.dart';
import 'package:stat_trac_technical/features/auth/presentation/providers/auth_state.dart';
import 'package:stat_trac_technical/features/certification/presentation/widgets/cert_signature_step.dart';
import 'package:stat_trac_technical/features/work_orders/data/powersync_work_order_data_source.dart';
import 'package:stat_trac_technical/features/work_orders/presentation/providers/work_order_providers.dart';
import 'package:stat_trac_technical/features/work_orders/presentation/screens/create_work_order_screen.dart';
import 'package:stat_trac_technical/sync/upload/upload_providers.dart';
import 'package:stat_trac_technical/sync/upload/upload_queue.dart';
import 'package:stat_trac_technical/sync/upload/upload_worker.dart';
import 'package:stat_trac_technical/sync/upload/work_order_upload.dart';

class _Source extends Mock implements PowerSyncWorkOrderDataSource {}

class _Worker extends Mock implements UploadWorker {}

class _Queue extends Mock implements UploadQueue {}

class _SignedIn extends AuthNotifier {
  @override
  AuthState build() => const AuthAuthenticated(User(
    id: 31, name: 'Athi', email: '', role: UserRole.technician,
    technicianCode: '',
  ));
}

WorkOrderUpload _original({String client = 'X'}) => WorkOrderUpload(
  mobileId: 'wo-1',
  capture: {'asset_id': 100, 'work_type': 1,
      'date_in': '2026-10-01', 'time_in': '08:00',
      'date_out': '2026-10-01', 'time_out': '09:00',
      'fault': '', 'work': '', 'note': '', 'client_name': client,
      'job_card_no': ''},
  techPng: 'AAAA', clientPng: 'BBBB', clientName: 'X',
);

/// A real in-memory outbox holding [original], as a set-aside job would be.
Future<(Database, UploadQueue)> _queueWith(
  WidgetTester tester,
  WorkOrderUpload original,
) async {
  final db = await tester.runAsync(
      () => databaseFactoryFfi.openDatabase(inMemoryDatabasePath));
  await tester.runAsync(() => UploadQueue.createTable(db!));
  final queue = UploadQueue(db!);
  await tester.runAsync(() => queue.enqueue(original));
  return (db, queue);
}

/// The resend screen, pushed over a home as the app opens it: Save and Leave
/// pop back to where the technician came from, and that pop is under test.
Future<void> _open(
  WidgetTester tester, {
  required UploadQueue queue,
  required WorkOrderUpload original,
  String field = 'jobfault',
  String message = 'Add the fault',
}) async {
  tester.view.physicalSize = const Size(1080, 2316);
  tester.view.devicePixelRatio = 1080 / 384;
  addTearDown(tester.view.reset);

  final source = _Source();
  when(() => source.assetsByIds(any())).thenAnswer((_) async => const {});
  when(() => source.openRepairOn(any())).thenAnswer((_) async => null);
  final worker = _Worker();
  when(() => worker.drain()).thenAnswer((_) async => const UploadRunResult(
      attempted: 0, applied: 0, conflicted: 0, rejected: 0, failed: 0,
      stoppedForSignal: false));

  await tester.pumpWidget(ProviderScope(
    overrides: [
      authProvider.overrideWith(_SignedIn.new),
      uploadQueueProvider.overrideWith((ref) async => queue),
      uploadWorkerProvider.overrideWith((ref) async => worker),
      workOrderSourceProvider.overrideWith((ref) async => source),
    ],
    child: MaterialApp(
      theme: appTheme,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CreateWorkOrderScreen(resend: original,
                      resendField: field, resendMessage: message),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

/// The client box sits below the fold of the form's lazy list.
Future<void> _toClient(WidgetTester tester) async {
  final client = find.byKey(const Key('wo-client'));
  await tester.dragUntilVisible(client, find.byType(ListView),
      const Offset(0, -200));
  await tester.pumpAndSettle();
}

/// Taps Save and lets the real sqflite I/O behind it finish.
Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.text('Save work order'));
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await tester.pumpAndSettle();
}

void main() {
  sqfliteFfiInit();
  setUpAll(() {
    registerFallbackValue(<int>{});
    registerFallbackValue(_original());
  });

  testWidgets('fix and resend keeps the id and the signatures, replaces the '
      'row', (tester) async {
    final original = _original();
    final (db, queue) = await _queueWith(tester, original);
    await _open(tester, queue: queue, original: original);

    expect(find.text('Add the fault'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('wo-fault')), 'Beeps');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Signatures kept'), findsOneWidget);
    await _save(tester);
    expect(find.byType(CreateWorkOrderScreen), findsNothing);
    expect(find.text('Open'), findsOneWidget);

    final rows = await tester.runAsync(queue.all);
    expect(rows, hasLength(1));
    final saved = rows!.single.upload as WorkOrderUpload;
    expect(saved.mobileId, 'wo-1');
    expect(saved.techPng, 'AAAA');
    expect(saved.clientPng, 'BBBB');
    expect(saved.capture['fault'], 'Beeps');
    expect(rows.single.status, UploadStatus.pending);
    await tester.runAsync(db.close);
  });

  testWidgets('a client name set aside as too long is held on the form, and '
      'the corrected name is what is queued', (tester) async {
    final long = 'N' * 60;
    final original = _original(client: long);
    final (db, queue) = await _queueWith(tester, original);
    await _open(tester, queue: queue, original: original,
        field: 'client', message: 'Too long');

    // Refused on the device: Next stays off, nothing can reach the outbox.
    final next = find.widgetWithText(FilledButton, 'Next');
    expect(tester.widget<FilledButton>(next).onPressed, isNull);

    await _toClient(tester);
    await tester.enterText(find.byKey(const Key('wo-client')), 'Sister Mbeki');
    await tester.pumpAndSettle();
    await tester.tap(next);
    await tester.pumpAndSettle();
    // The kept signatures carry the corrected name.
    expect(find.text('Signed by the technician and Sister Mbeki'),
        findsOneWidget);
    await _save(tester);

    final rows = await tester.runAsync(queue.all);
    expect(rows, hasLength(1));
    final saved = rows!.single.upload as WorkOrderUpload;
    expect(saved.capture['client_name'], 'Sister Mbeki');
    expect(saved.clientName, 'Sister Mbeki');
    expect(saved.clientPng, 'BBBB');
    await tester.runAsync(db.close);
  });

  testWidgets('a resend with the client name cleared is refused on Save and '
      'the queued row is left as it was', (tester) async {
    final original = _original();
    final (db, queue) = await _queueWith(tester, original);
    await _open(tester, queue: queue, original: original);

    await tester.enterText(find.byKey(const Key('wo-fault')), 'Beeps');
    await _toClient(tester);
    await tester.enterText(find.byKey(const Key('wo-client')), '');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await _save(tester);

    expect(find.textContaining('Add the client contact name'), findsOneWidget);
    expect(find.byType(CreateWorkOrderScreen), findsOneWidget);
    final rows = await tester.runAsync(queue.all);
    expect(rows, hasLength(1));
    final kept = rows!.single.upload as WorkOrderUpload;
    expect(kept.capture['fault'], '');
    expect(kept.capture['client_name'], 'X');
    await tester.runAsync(db.close);
  });

  testWidgets('a failed outbox write says so and leaves Save usable',
      (tester) async {
    final queue = _Queue();
    when(() => queue.enqueue(any())).thenThrow(Exception('disk full'));
    await _open(tester, queue: queue, original: _original());

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await _save(tester);

    expect(find.textContaining('Could not save'), findsOneWidget);
    expect(find.byType(CreateWorkOrderScreen), findsOneWidget);
    final save = find.widgetWithText(FilledButton, 'Save work order');
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
  });

  testWidgets('back from the signatures steps back, then asks before leaving '
      'a resend', (tester) async {
    final original = _original();
    final (db, queue) = await _queueWith(tester, original);
    await _open(tester, queue: queue, original: original);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Step 3 of 3 — Signatures'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of 3 — Work order'), findsOneWidget);
    expect(find.text('Leave without resending?'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Leave without resending?'), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.byType(CreateWorkOrderScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(find.byType(CreateWorkOrderScreen), findsNothing);
    expect(find.text('Open'), findsOneWidget);
    await tester.runAsync(db.close);
  });

  testWidgets('the client name on the signature step is held to the card '
      'limit', (tester) async {
    tester.view.physicalSize = const Size(1080, 2316);
    tester.view.devicePixelRatio = 1080 / 384;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: appTheme,
      home: Scaffold(
        body: CertSignatureStep(
          requiresCustomerSig: true,
          clientLabel: 'Client',
          clientNameMaxLength: 50,
          onSigned: (_) {},
        ),
      ),
    ));
    await tester.enterText(find.byType(TextFormField), 'N' * 60);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, hasLength(50));
  });

  // The work-order screen keeps the signature step mounted once reached, so
  // a name corrected on the card afterwards arrives as a new widget, not a
  // new state. Seeded only once, the step kept the old name and Save sent it.
  testWidgets('the signature step takes a client name corrected on the card '
      'after it was first shown', (tester) async {
    tester.view.physicalSize = const Size(1080, 2316);
    tester.view.devicePixelRatio = 1080 / 384;
    addTearDown(tester.view.reset);
    var name = 'Sister Dlamini';
    late StateSetter rebuild;
    await tester.pumpWidget(MaterialApp(
      theme: appTheme,
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return CertSignatureStep(
              requiresCustomerSig: true,
              clientLabel: 'Client',
              initialClientName: name,
              clientNameMaxLength: 50,
              onSigned: (_) {},
            );
          },
        ),
      ),
    ));
    TextEditingController box() =>
        tester.widget<TextField>(find.byType(TextField)).controller!;
    expect(box().text, 'Sister Dlamini');

    rebuild(() => name = 'Sister Mbeki');
    await tester.pumpAndSettle();
    expect(box().text, 'Sister Mbeki');

    // A rebuild that does not change the card's name leaves what was typed
    // on the step alone.
    await tester.enterText(find.byType(TextFormField), 'Sr Mbeki');
    rebuild(() {});
    await tester.pumpAndSettle();
    expect(box().text, 'Sr Mbeki');
  });

  // With no machine chosen there is nothing to lose, so back simply leaves.
  // The "Leave without saving?" question once a machine is chosen needs the
  // asset picker, which reads the PowerSync database — that half is the
  // phone check.
  testWidgets('a new capture with nothing started leaves without asking',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2316);
    tester.view.devicePixelRatio = 1080 / 384;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [authProvider.overrideWith(_SignedIn.new)],
      child: MaterialApp(
        theme: appTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CreateWorkOrderScreen(),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 3 — Machine'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Leave without saving?'), findsNothing);
    expect(find.byType(CreateWorkOrderScreen), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  });
}
