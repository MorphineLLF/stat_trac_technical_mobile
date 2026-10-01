import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stat_trac_technical/core/theme/app_theme.dart';
import 'package:stat_trac_technical/features/auth/domain/entities/user.dart';
import 'package:stat_trac_technical/features/auth/presentation/providers/auth_providers.dart';
import 'package:stat_trac_technical/features/auth/presentation/providers/auth_state.dart';
import 'package:stat_trac_technical/features/work_orders/data/powersync_work_order_data_source.dart';
import 'package:stat_trac_technical/features/work_orders/presentation/providers/work_order_providers.dart';
import 'package:stat_trac_technical/features/work_orders/presentation/screens/create_work_order_screen.dart';
import 'package:stat_trac_technical/sync/upload/upload_providers.dart';
import 'package:stat_trac_technical/sync/upload/upload_queue.dart';
import 'package:stat_trac_technical/sync/upload/upload_worker.dart';
import 'package:stat_trac_technical/sync/upload/work_order_upload.dart';

class _Source extends Mock implements PowerSyncWorkOrderDataSource {}

class _Worker extends Mock implements UploadWorker {}

class _SignedIn extends AuthNotifier {
  @override
  AuthState build() => const AuthAuthenticated(User(
    id: 31, name: 'Athi', email: '', role: UserRole.technician,
    technicianCode: '',
  ));
}

void main() {
  sqfliteFfiInit();
  setUpAll(() => registerFallbackValue(<int>{}));

  testWidgets('fix and resend keeps the id and the signatures, replaces the '
      'row', (tester) async {
    tester.view.physicalSize = const Size(1080, 2316);
    tester.view.devicePixelRatio = 1080 / 384;
    addTearDown(tester.view.reset);

    final db = await tester.runAsync(
        () => databaseFactoryFfi.openDatabase(inMemoryDatabasePath));
    await tester.runAsync(() => UploadQueue.createTable(db!));
    final queue = UploadQueue(db!);
    final original = WorkOrderUpload(
      mobileId: 'wo-1',
      capture: const {'asset_id': 100, 'work_type': 1,
          'date_in': '2026-10-01', 'time_in': '08:00',
          'date_out': '2026-10-01', 'time_out': '09:00',
          'fault': '', 'work': '', 'note': '', 'client_name': 'X',
          'job_card_no': ''},
      techPng: 'AAAA', clientPng: 'BBBB', clientName: 'X',
    );
    await tester.runAsync(() => queue.enqueue(original));

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
        // Behind a pushed route, as the app opens it: Save pops back to
        // where the technician came from, and that pop is under test.
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CreateWorkOrderScreen(resend: original,
                        resendField: 'jobfault',
                        resendMessage: 'Add the fault'),
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

    expect(find.text('Add the fault'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('wo-fault')), 'Beeps');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Signatures kept'), findsOneWidget);
    await tester.tap(find.text('Save work order'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.byType(CreateWorkOrderScreen), findsNothing);
    expect(find.text('Open'), findsOneWidget);

    final rows = await tester.runAsync(queue.all);
    expect(rows, hasLength(1));
    final saved = rows!.single.upload as WorkOrderUpload;
    expect(saved.mobileId, 'wo-1');
    expect(saved.techPng, 'AAAA');
    expect(saved.capture['fault'], 'Beeps');
    expect(rows.single.status, UploadStatus.pending);
    await tester.runAsync(db.close);
  });
}
