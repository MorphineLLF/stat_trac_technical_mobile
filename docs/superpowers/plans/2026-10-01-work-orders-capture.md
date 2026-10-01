# Work Orders — Capture on Site Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A technician captures a completed work order on site — machine, job card, both signatures — offline-first, and it reaches the server through the existing upload queue as one `capture` + two `sign` ops.

**Architecture:** The outbox (`upload_queue`) learns a second payload kind beside `CertificateUpload`: `WorkOrderUpload`, behind a small `QueuedUpload` interface. The worker sends it only when the server advertises `capture_action` and `job_sign_action`. Reads come from PowerSync's `Repair` / `RepairDetail` with no joins. The Horse-era `lib/features/work_orders/` is deleted and rewritten fresh.

**Tech Stack:** Flutter, Riverpod 3 codegen (`@riverpod`), sqflite / sqflite_common_ffi (tests), PowerSync, mocktail, uuid.

**Spec:** `docs/superpowers/specs/2026-10-01-work-orders-capture-design.md`
**Go side (not built here):** `docs/go-requirements-work-order-capture.md`

## Global Constraints

- **Never use, read or copy Horse-era code** (old `lib/features/work_orders/`, `*_model.dart` `fromJson`). Authorities: `lib/sync/powersync_schema.dart`, `E:\Stat_Trac_Go`, `docs/sync-client-handover.md`.
- **Do not edit anything in `E:\Stat_Trac_Go`.**
- Capture only. No book-in, no WO Request, no WO Progress, no priority field.
- **No technician field on any op.** The server writes it from the token.
- Never join PowerSync tables. Fetch separately, attach in Dart, timeout on secondary reads.
- Every `FilledButton` inside a `Row` is wrapped in `Expanded`.
- Widget tests pump the real `appTheme` at 384 dp wide (`physicalSize: Size(1080, 2316)`, `devicePixelRatio: 1080 / 384`).
- Phone layout only.
- Work type codes: Repair 1, Warranty Repair 2, Call-out 3, Quality Assurance 4, Installation 6. **Never 5 (PM). No default.**
- Text limits (server `maxJob*`): job card no 30, client 50, fault 200, work done 200, notes 100.
- Wire dates `YYYY-MM-DD`, times `HH:MM`.
- After any `@riverpod` change: `dart run build_runner build --delete-conflicting-outputs`.
- Gates every task: `flutter test` and `flutter analyze` clean. Commit to `master` (no branches).
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **A resend after a lost reply** — the server applied the batch, the phone never heard. The phone must resend the identical batch (same mobile id, same ops), never mint a new id. Pinned in Task 4 (`toBatch` deterministic) and Task 6 (transport error keeps the row pending, unchanged).
2. **An old server** that refuses `capture` with a 400. The job must stay pending with "server not ready", never be parked as `failed`. Pinned in Task 6.
3. **The card query hanging** on a large `RepairDetail` store. The Worklist must show queued jobs and a message, never spin and never leak book-in rows. Pinned in Task 8.
4. **A job set aside, then the technician fixes it.** The resend must keep the mobile id and the signatures, and replace the queue row rather than add one. Pinned in Task 4 (round trip) and Task 10 (resend mode).
5. **Queue rows written by the current release** (no `kind` key) must still restore as certificates after this ships. Pinned in Task 1.

---

## File Structure

**Create**
- `lib/sync/upload/queued_upload.dart` — the interface both payload kinds implement, and the `kind` dispatch.
- `lib/sync/upload/work_order_upload.dart` — a captured job as it waits in the queue; builds its batch.
- `lib/database/migrations/migration_019_drop_work_orders.dart` — drops the four Horse-era tables; adds `field` to `upload_queue`.
- `lib/features/work_orders/domain/work_type.dart` — the five capture work types.
- `lib/features/work_orders/domain/work_order_job.dart` — the job card values, server-matching validation, wire map.
- `lib/features/work_orders/domain/work_order_summary.dart` — one Worklist row, plus the merge.
- `lib/features/work_orders/domain/work_order_record.dart` — a synced work order for the detail screen.
- `lib/features/work_orders/data/powersync_work_order_data_source.dart` — all PowerSync reads.
- `lib/features/work_orders/presentation/providers/work_order_providers.dart` — Riverpod wiring.
- `lib/features/work_orders/presentation/screens/create_work_order_screen.dart` — three steps.
- `lib/features/work_orders/presentation/widgets/work_order_form.dart` — step 2.
- `lib/features/work_orders/presentation/screens/work_order_list_screen.dart` — Worklist.
- `lib/features/work_orders/presentation/screens/work_order_detail_screen.dart` — detail, set-aside actions.

**Modify**
- `lib/sync/upload/certificate_upload.dart` — implements `QueuedUpload`, writes `kind`.
- `lib/sync/upload/sync_upload_batch.dart` — `SyncUploadOp.capture`; `sign` takes a table.
- `lib/sync/upload/sync_upload_result.dart` — new guarantee and reason names.
- `lib/sync/upload/upload_queue.dart`, `upload_archive.dart`, `sync_upload_client.dart`, `upload_worker.dart`, `upload_run_message.dart`.
- `lib/database/database_helper.dart` — version 19.
- `lib/features/certification/presentation/widgets/cert_signature_step.dart`, `signature_step_validation.dart` — labels and an initial client name.
- `lib/features/assets/presentation/providers/asset_providers.dart`, `screens/asset_detail_screen.dart` — stop depending on the old work-order code.
- `lib/features/dashboard/presentation/providers/dashboard_providers.dart`, `screens/dashboard_screen.dart`.
- `CLAUDE.md` — module notes.

**Delete**
- `lib/features/work_orders/` (the whole Horse-era tree, before the new files are created).

---

### Task 1: The queue holds more than certificates

**Files:**
- Create: `lib/sync/upload/queued_upload.dart`
- Modify: `lib/sync/upload/certificate_upload.dart`, `upload_queue.dart`, `upload_archive.dart`, `sync_upload_client.dart`, `upload_worker.dart`
- Modify tests: `test/sync/upload/upload_archive_test.dart:73`, `upload_queue_repair_test.dart:51-54`, `upload_queue_test.dart:57-59,73`, `upload_worker_test.dart:22,302`
- Test: `test/sync/upload/queued_upload_test.dart`

**Interfaces:**
- Produces: `abstract interface class QueuedUpload { String get kind; String get mobileId; String get queueKey; Map<String, Object?> toJson(); SyncUploadBatch toBatch(); }` and `QueuedUpload fromQueuedJson(Map<String, Object?> j)`.
- Produces: `CertificateUpload.kindName == 'certificate'`.
- Changes: `UploadQueueEntry.upload` and `UploadArchiveEntry.upload` become `QueuedUpload`; `UploadQueue.enqueue(QueuedUpload)`; `UploadArchive.record({required QueuedUpload upload, ...})`; `SyncUploadClient.upload({..., required QueuedUpload upload})`.

- [ ] **Step 1: Write the failing test**

`test/sync/upload/queued_upload_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/sync/upload/certificate_upload.dart';
import 'package:stat_trac_technical/sync/upload/queued_upload.dart';

void main() {
  CertificateUpload cert() => CertificateUpload(
    mobileId: 'cert-1',
    certificate: const {'TestAssetID': 9304},
    lines: const [CertificateLineUpload(mobileId: 'l', data: {'TestPass': true})],
  );

  test('a certificate is stored with its kind', () {
    expect(cert().toJson()['kind'], 'certificate');
  });

  // Rows queued by builds before this one carry no kind. They are
  // certificates, and they must still go.
  test('a payload with no kind restores as a certificate', () {
    final json = cert().toJson()..remove('kind');
    final restored = fromQueuedJson(json);
    expect(restored, isA<CertificateUpload>());
    expect(restored.mobileId, 'cert-1');
  });

  test('an unknown kind is refused loudly', () {
    expect(
      () => fromQueuedJson({'kind': 'mystery', 'mobile_id': 'x'}),
      throwsFormatException,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/sync/upload/queued_upload_test.dart`
Expected: FAIL — `queued_upload.dart` does not exist.

- [ ] **Step 3: Write the interface**

`lib/sync/upload/queued_upload.dart`:

```dart
import 'certificate_upload.dart';
import 'sync_upload_batch.dart';

/// Something that waits in the outbox and becomes exactly one batch.
///
/// Certificates were the only kind until work orders. The queue, the archive
/// and the worker speak this, and only the code that needs a kind's details
/// looks past it.
abstract interface class QueuedUpload {
  /// Stored in the payload so the queue can restore the right class.
  String get kind;

  /// The uuid the server names this work by in `assigned`.
  String get mobileId;

  /// The outbox key. Usually [mobileId].
  String get queueKey;

  Map<String, Object?> toJson();

  SyncUploadBatch toBatch();
}

/// Restores a queued payload.
///
/// **No kind means certificate**: every row queued before work orders existed
/// was one, and they are still on technicians' phones.
QueuedUpload fromQueuedJson(Map<String, Object?> j) => switch (j['kind']) {
  null || CertificateUpload.kindName => CertificateUpload.fromJson(j),
  final other => throw FormatException('Unknown queued upload kind: $other'),
};
```

- [ ] **Step 4: Make `CertificateUpload` implement it**

In `lib/sync/upload/certificate_upload.dart`:
- `import 'queued_upload.dart';`
- `class CertificateUpload implements QueuedUpload {`
- add inside the class:

```dart
  static const kindName = 'certificate';

  @override
  String get kind => kindName;
```

- add `@override` above `final String mobileId;`, `String get queueKey`, `Map<String, Object?> toJson()`, `SyncUploadBatch toBatch()`.
- in `toJson()` add `'kind': kind,` as the first entry.

- [ ] **Step 5: Generalise the queue, archive and client**

`upload_queue.dart`:
- `import 'queued_upload.dart';` (keep the certificate import; `certificateCount` uses it)
- `final QueuedUpload upload;` in `UploadQueueEntry`
- `Future<void> enqueue(QueuedUpload upload) async {`
- in `_read`: `upload: fromQueuedJson(jsonDecode(r['payload']! as String) as Map<String, Object?>),`
- `certificateCount()` counts certificates only:

```dart
  Future<int> certificateCount() async {
    final entries = await all();
    return {
      for (final e in entries)
        if (e.upload is CertificateUpload) e.upload.mobileId,
    }.length;
  }
```

`upload_archive.dart`:
- `import 'queued_upload.dart';`
- `record({required QueuedUpload upload, ...})`, and inside:

```dart
    final cert = upload is CertificateUpload ? upload : null;
    await _db.insert(table, {
      'mobile_id': upload.mobileId,
      'archived_at': DateTime.now().toUtc().toIso8601String(),
      // A work order has no row ops for `applied` to count against.
      'ops_sent': cert?.rowOpCount ?? 0,
      'lines_sent': cert?.lines.length ?? 0,
      'applied': applied,
      'assigned': jsonEncode(assigned),
      'payload': jsonEncode(upload.toJson()),
    });
```

- in `all()`: `upload: fromQueuedJson(jsonDecode(r['payload']! as String) as Map<String, Object?>),`
- `final QueuedUpload upload;` in `UploadArchiveEntry`.

`sync_upload_client.dart`: `import 'queued_upload.dart';`, parameter `required QueuedUpload upload`. Nothing else changes.

- [ ] **Step 6: Generalise the worker without changing what it does to certificates**

In `upload_worker.dart`, at the top of the `for (final entry in pending)` body, before `attempted++`:

```dart
      final upload = entry.upload;
      final cert = upload is CertificateUpload ? upload : null;
```

Then in the loop replace every `entry.upload` with `upload`, and in `case UploadApplied`:

```dart
          if (cert != null &&
              cert.lines.isNotEmpty &&
              !result.guaranteesCertRef) {
            unguaranteed++;
            debugPrint(
              noGuaranteeNote(
                mobileId: upload.mobileId,
                enforces: result.enforces,
              ),
            );
          }
          await _archive.record(
            upload: upload,
            applied: rowsApplied,
            assigned: assigned,
          );
          final serverId = assigned[upload.mobileId];
          // Certificates only: the local certificate table is what this
          // writes to. A work order's number arrives with its synced row.
          if (cert != null && serverId != null) {
            await _confirm(upload.mobileId, serverId);
          }
          if (cert != null && rowsApplied < cert.rowOpCount) {
            shortApplied++;
            debugPrint(
              shortApplyNote(
                mobileId: upload.mobileId,
                opsSent: cert.rowOpCount,
                lines: cert.lines.length,
                applied: rowsApplied,
              ),
            );
          }
          await _queue.markApplied(upload.queueKey);
          applied++;
```

and in `case UploadRejected`:

```dart
          // Anything that is not a certificate carries a whole job.
          final carriesWork =
              cert == null ||
              cert.lines.isNotEmpty ||
              cert.certificate.isNotEmpty;
```

- [ ] **Step 7: Fix the existing tests that read certificate fields off an entry**

- `upload_worker_test.dart:22`: `setUpAll(() => registerFallbackValue<QueuedUpload>(_upload('fallback')));` and add `import 'package:stat_trac_technical/sync/upload/queued_upload.dart';`
- `upload_worker_test.dart:302`: `expect(((await archive.all()).single.upload as CertificateUpload).lines, hasLength(1));`
- `upload_archive_test.dart:73`: `final restored = (await archive.all()).single.upload as CertificateUpload;`
- `upload_queue_repair_test.dart:51-54`: introduce `final upload = entry.upload as CertificateUpload;` and use `upload.certificate` / `upload.lines`.
- `upload_queue_test.dart:57-59`: `final upload = pending.single.upload as CertificateUpload;` then `upload.mobileId`, `upload.certificate[...]`, `upload.lines...`.
- `upload_queue_test.dart:73`: `final issue = ((await queue.pending()).single.upload as CertificateUpload).issue!;`

- [ ] **Step 8: Run the tests**

Run: `flutter test test/sync/upload/` then `flutter analyze`
Expected: all PASS, analyze clean.

- [ ] **Step 9: Commit**

```bash
git add lib/sync/upload test/sync/upload
git commit -m "refactor(upload): the outbox holds any queued upload, not only certificates"
```

---

### Task 2: The `capture` op and a `sign` that names its table

**Files:**
- Modify: `lib/sync/upload/sync_upload_batch.dart`, `lib/sync/upload/sync_upload_result.dart`
- Test: `test/sync/upload/work_order_ops_test.dart`

**Interfaces:**
- Produces: `SyncUploadOp.capture({required String mobileId, required Map<String, Object?> data})`.
- Changes: `SyncUploadOp.sign({String table = 'TestCertificate', required String mobileId, required SignatureSide which, required String png, String? clientName})`.
- Produces: `SyncUploadGuarantee.captureAction = 'capture_action'`, `SyncUploadGuarantee.jobSignAction = 'job_sign_action'`; `UploadRejectionReason.assetInactive = 'asset_inactive'`, `.assetOnLoan = 'asset_on_loan'`, `.openWorkOrder = 'open_work_order'`.

- [ ] **Step 1: Write the failing test**

`test/sync/upload/work_order_ops_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/sync/upload/sync_upload_batch.dart';

void main() {
  group('capture', () {
    test('is an action on Repair carrying the job', () {
      final op = SyncUploadOp.capture(
        mobileId: 'wo-1',
        data: const {'asset_id': 1234, 'work_type': 1},
      ).toJson();

      expect(op['table'], 'Repair');
      expect(op['mobile_id'], 'wo-1');
      expect(op['action'], 'capture');
      expect(op['data'], {'asset_id': 1234, 'work_type': 1});
    });

    // The server writes the technician from the token. A device able to
    // name one could file work under somebody else.
    for (final key in ['tech', 'tech_id', 'RepairTech', 'RepairTechID']) {
      test('refuses a technician field: $key', () {
        expect(
          () => SyncUploadOp.capture(mobileId: 'wo-1', data: {key: 'x'}),
          throwsArgumentError,
        );
      });
    }
  });

  test('sign can name Repair', () {
    final op = SyncUploadOp.sign(
      table: 'Repair',
      mobileId: 'wo-1',
      which: SignatureSide.client,
      png: 'AAAA',
      clientName: 'Sister Dlamini',
    ).toJson();

    expect(op['table'], 'Repair');
    expect(op['action'], 'sign');
    expect(op['data'], {
      'which': 'client',
      'png': 'AAAA',
      'client_name': 'Sister Dlamini',
    });
  });

  test('sign still defaults to the certificate', () {
    final op = SyncUploadOp.sign(
      mobileId: 'c-1',
      which: SignatureSide.tech,
      png: 'AAAA',
    ).toJson();
    expect(op['table'], 'TestCertificate');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/sync/upload/work_order_ops_test.dart`
Expected: FAIL — `capture` not defined; `sign` has no `table` parameter.

- [ ] **Step 3: Implement**

In `sync_upload_batch.dart`, after `SyncUploadOp.sign`:

```dart
  /// Raise and complete a work order captured on site — runs the server's
  /// `CaptureWorkOrderWithCard`: the scope, active, on-loan and open-work-order
  /// checks, the work order, its job card, its two history lines and the
  /// completion, in one transaction.
  ///
  /// **An action, not two row ops.** Writing `Repair` and `RepairDetail` as
  /// rows would skip every one of those rules — the same trap as a
  /// certificate marked issued by writing a column.
  ///
  /// **No technician field, ever.** The server writes the person it
  /// authenticated; a device that could name one could file work as somebody
  /// else.
  factory SyncUploadOp.capture({
    required String mobileId,
    required Map<String, Object?> data,
  }) {
    for (final key in _technicianKeys) {
      if (data.containsKey(key)) {
        throw ArgumentError.value(
          data[key],
          'data',
          '$key is written by the server from the token, never by the device',
        );
      }
    }
    return SyncUploadOp._({
      'table': 'Repair',
      'mobile_id': mobileId,
      'action': 'capture',
      'data': data,
    });
  }

  static const _technicianKeys = {'tech', 'tech_id', 'RepairTech', 'RepairTechID'};
```

Change `SyncUploadOp.sign` to take `String table = 'TestCertificate',` as its first named parameter and use `'table': table,` in the map. Update its doc comment's first line to: `/// Attach a signature to a certificate or, with [table] `Repair`, to a captured work order's job card.`

In `sync_upload_result.dart`, inside `SyncUploadGuarantee`:

```dart
  /// `capture` on `Repair` runs the desktop's capture on site.
  static const captureAction = 'capture_action';

  /// `sign` on `Repair` signs the job card.
  static const jobSignAction = 'job_sign_action';
```

and inside `UploadRejectionReason`:

```dart
  static const assetInactive = 'asset_inactive';
  static const assetOnLoan = 'asset_on_loan';

  /// The machine already has a repair work order open — booked in at the
  /// counter or captured by somebody else.
  static const openWorkOrder = 'open_work_order';
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/sync/upload/` then `flutter analyze`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/sync/upload test/sync/upload/work_order_ops_test.dart
git commit -m "feat(upload): capture op on Repair; sign op can name its table"
```

---

### Task 3: The job card, validated as the server validates it

**Files:**
- The old tree is deleted in Task 7. These two files sit beside it until then; the old tree has only `domain/entities/` and `domain/repositories/`, so nothing collides (confirm with `ls lib/features/work_orders/domain`).
- Create: `lib/features/work_orders/domain/work_type.dart`, `lib/features/work_orders/domain/work_order_job.dart`
- Test: `test/features/work_orders/work_order_job_test.dart`

**Interfaces:**
- Produces: `enum WorkType { repair, warranty, callOut, qa, installation }` with `int code`, `String label`, `static WorkType? fromCode(int? code)`.
- Produces: `class WorkOrderJob` with fields `int assetId, WorkType? workType, DateTime? started, DateTime? finished, int? equipHrs, int? nop, String fault, work, note, clientName, jobCardNo`; `WorkOrderFieldError? validate()`; `Map<String, Object?> toWire()`; `factory WorkOrderJob.fromWire(Map<String, Object?>)`; `WorkOrderJob copyWith(...)`.
- Produces: `class WorkOrderFieldError { final String field; final String message; }` — `field` uses the server's `ValidationError` names.

- [ ] **Step 1: Write the failing test**

`test/features/work_orders/work_order_job_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/features/work_orders/domain/work_order_job.dart';
import 'package:stat_trac_technical/features/work_orders/domain/work_type.dart';

WorkOrderJob job({
  WorkType? workType = WorkType.repair,
  DateTime? started,
  DateTime? finished,
  int? equipHrs,
  String fault = '',
  String note = '',
  String clientName = 'Sister Dlamini',
  String jobCardNo = '',
}) => WorkOrderJob(
  assetId: 1234,
  workType: workType,
  started: started ?? DateTime(2026, 10, 1, 8, 15),
  finished: finished ?? DateTime(2026, 10, 1, 10, 40),
  equipHrs: equipHrs,
  fault: fault,
  note: note,
  clientName: clientName,
  jobCardNo: jobCardNo,
);

void main() {
  test('PM is never offered', () {
    expect(WorkType.values.map((w) => w.code), [1, 2, 3, 4, 6]);
    expect(WorkType.fromCode(5), isNull);
  });

  test('a complete job is valid', () {
    expect(job().validate(), isNull);
  });

  group('refuses as the server does', () {
    void refuses(WorkOrderJob j, String field, String message) {
      final e = j.validate();
      expect(e?.field, field);
      expect(e?.message, message);
    }

    test('no work type', () =>
        refuses(job(workType: null), 'jobworktype', 'Choose the type of work'));
    test('no start', () => refuses(
      WorkOrderJob(assetId: 1, workType: WorkType.repair, finished: DateTime(2026)),
      'datein',
      'The date in is needed',
    ));
    test('no finish', () => refuses(
      WorkOrderJob(assetId: 1, workType: WorkType.repair, started: DateTime(2026)),
      'dateout',
      'The date completed is needed',
    ));
    test('finished on an earlier day', () => refuses(
      job(started: DateTime(2026, 10, 2, 8), finished: DateTime(2026, 10, 1, 9)),
      'dateout',
      'The date completed is before the date in',
    ));
    test('negative hours', () => refuses(
      job(equipHrs: -1), 'equiphrs', 'Equipment hours cannot be negative'));
    test('fault too long', () => refuses(
      job(fault: 'x' * 201), 'jobfault', 'The fault is longer than 200 characters'));
    test('notes too long', () => refuses(
      job(note: 'x' * 101), 'jobnote', 'Comments is longer than 100 characters'));
    test('job card no too long', () => refuses(
      job(jobCardNo: 'x' * 31), 'jobcardno', 'The job card no is longer than 30 characters'));
  });

  // The server compares dates, not times. A job that ends earlier in the
  // clock on the same day is the server's to judge, and the phone must not be
  // stricter than the server.
  test('same day, time out before time in, is allowed', () {
    expect(
      job(started: DateTime(2026, 10, 1, 10), finished: DateTime(2026, 10, 1, 9))
          .validate(),
      isNull,
    );
  });

  test('wire shape', () {
    expect(job(equipHrs: 5120, fault: ' Beeps ').toWire(), {
      'asset_id': 1234,
      'work_type': 1,
      'date_in': '2026-10-01',
      'time_in': '08:15',
      'date_out': '2026-10-01',
      'time_out': '10:40',
      'equip_hrs': 5120,
      'fault': 'Beeps',
      'work': '',
      'note': '',
      'client_name': 'Sister Dlamini',
      'job_card_no': '',
    });
  });

  test('wire round trip', () {
    final j = job(equipHrs: 7, fault: 'Beeps');
    expect(WorkOrderJob.fromWire(j.toWire()).toWire(), j.toWire());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/work_orders/work_order_job_test.dart`
Expected: FAIL — files do not exist.

- [ ] **Step 3: Implement `work_type.dart`**

```dart
/// The kinds of work a captured work order can be.
///
/// The server's repair-module list (`internal/stats/workorder.go`). **PM (5) is
/// absent on purpose** — PM work orders belong to the PM module and the
/// server refuses one raised here.
enum WorkType {
  repair(1, 'Repair'),
  warranty(2, 'Warranty Repair'),
  callOut(3, 'Call-out'),
  qa(4, 'Quality Assurance'),
  installation(6, 'Installation');

  const WorkType(this.code, this.label);

  final int code;
  final String label;

  static WorkType? fromCode(int? code) {
    for (final w in values) {
      if (w.code == code) return w;
    }
    return null;
  }
}
```

- [ ] **Step 4: Implement `work_order_job.dart`**

```dart
import 'work_type.dart';

/// What is wrong with a job card, named as the server names it.
class WorkOrderFieldError {
  const WorkOrderFieldError(this.field, this.message);

  /// The server's `ValidationError` field — the form maps it to a box.
  final String field;
  final String message;
}

/// The Work Order tab of a captured job: what the technician fills in.
///
/// **The checks are the server's, word for word** (`JobCardInput.Validate`,
/// captured), and never stricter: a device check the server would not make
/// stops a technician finishing a job that was fine.
class WorkOrderJob {
  const WorkOrderJob({
    required this.assetId,
    this.workType,
    this.started,
    this.finished,
    this.equipHrs,
    this.nop,
    this.fault = '',
    this.work = '',
    this.note = '',
    this.clientName = '',
    this.jobCardNo = '',
  });

  final int assetId;

  /// No default. A default is filed as though somebody chose it.
  final WorkType? workType;

  /// Date in and time in.
  final DateTime? started;

  /// Date completed and time out. Saving a capture completes the work order,
  /// so the card is the whole record of the job.
  final DateTime? finished;

  final int? equipHrs;

  /// N.O.P, as the desktop labels it.
  final int? nop;

  final String fault;
  final String work;
  final String note;
  final String clientName;
  final String jobCardNo;

  static const maxJobCardNo = 30;
  static const maxClient = 50;
  static const maxFault = 200;
  static const maxWork = 200;
  static const maxNote = 100;

  WorkOrderFieldError? validate() {
    if (workType == null) {
      return const WorkOrderFieldError('jobworktype', 'Choose the type of work');
    }
    if (started == null) {
      return const WorkOrderFieldError('datein', 'The date in is needed');
    }
    if (finished == null) {
      return const WorkOrderFieldError('dateout', 'The date completed is needed');
    }
    // Dates, not times — the server compares the two dates only.
    if (_day(finished!).isBefore(_day(started!))) {
      return const WorkOrderFieldError(
        'dateout',
        'The date completed is before the date in',
      );
    }
    if ((equipHrs ?? 0) < 0) {
      return const WorkOrderFieldError(
        'equiphrs',
        'Equipment hours cannot be negative',
      );
    }
    for (final (field, label, value, max) in [
      ('jobcardno', 'The job card no', jobCardNo, maxJobCardNo),
      ('client', 'The client', clientName, maxClient),
      ('jobfault', 'The fault', fault, maxFault),
      ('jobwork', 'Work done', work, maxWork),
      ('jobnote', 'Comments', note, maxNote),
    ]) {
      if (value.trim().runes.length > max) {
        return WorkOrderFieldError(field, '$label is longer than $max characters');
      }
    }
    return null;
  }

  /// The `data` of the capture op. Call only on a job that validates.
  Map<String, Object?> toWire() => {
    'asset_id': assetId,
    'work_type': workType!.code,
    'date_in': _date(started!),
    'time_in': _time(started!),
    'date_out': _date(finished!),
    'time_out': _time(finished!),
    'equip_hrs': ?equipHrs,
    'nop': ?nop,
    'fault': fault.trim(),
    'work': work.trim(),
    'note': note.trim(),
    'client_name': clientName.trim(),
    'job_card_no': jobCardNo.trim(),
  };

  /// Back from a queued payload, for the Worklist and for Fix and resend.
  factory WorkOrderJob.fromWire(Map<String, Object?> w) => WorkOrderJob(
    assetId: (w['asset_id']! as num).toInt(),
    workType: WorkType.fromCode((w['work_type'] as num?)?.toInt()),
    started: _parse(w['date_in'], w['time_in']),
    finished: _parse(w['date_out'], w['time_out']),
    equipHrs: (w['equip_hrs'] as num?)?.toInt(),
    nop: (w['nop'] as num?)?.toInt(),
    fault: w['fault'] as String? ?? '',
    work: w['work'] as String? ?? '',
    note: w['note'] as String? ?? '',
    clientName: w['client_name'] as String? ?? '',
    jobCardNo: w['job_card_no'] as String? ?? '',
  );

  WorkOrderJob copyWith({
    WorkType? workType,
    DateTime? started,
    DateTime? finished,
    int? equipHrs,
    int? nop,
    String? fault,
    String? work,
    String? note,
    String? clientName,
    String? jobCardNo,
  }) => WorkOrderJob(
    assetId: assetId,
    workType: workType ?? this.workType,
    started: started ?? this.started,
    finished: finished ?? this.finished,
    equipHrs: equipHrs ?? this.equipHrs,
    nop: nop ?? this.nop,
    fault: fault ?? this.fault,
    work: work ?? this.work,
    note: note ?? this.note,
    clientName: clientName ?? this.clientName,
    jobCardNo: jobCardNo ?? this.jobCardNo,
  );

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

  static String _time(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

  static DateTime? _parse(Object? date, Object? time) {
    if (date is! String) return null;
    return DateTime.tryParse('${date}T${time is String ? time : '00:00'}');
  }
}
```

Note: `copyWith` cannot clear `equipHrs` / `nop` back to null. The form (Task 10) builds a fresh `WorkOrderJob` from its controllers on every change instead of using `copyWith` for those two, so this is not a gap.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/work_orders/work_order_job_test.dart` then `flutter analyze`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/work_orders/domain/work_type.dart lib/features/work_orders/domain/work_order_job.dart test/features/work_orders/work_order_job_test.dart
git commit -m "feat(work-orders): job card values with the server's own checks"
```

---

### Task 4: `WorkOrderUpload` — a captured job in the outbox

**Files:**
- Create: `lib/sync/upload/work_order_upload.dart`
- Modify: `lib/sync/upload/queued_upload.dart`
- Test: `test/sync/upload/work_order_upload_test.dart`

**Interfaces:**
- Consumes: `QueuedUpload`, `fromQueuedJson` (Task 1); `SyncUploadOp.capture`, `SyncUploadOp.sign(table:)` (Task 2).
- Produces: `class WorkOrderUpload implements QueuedUpload` with `WorkOrderUpload({required String mobileId, required Map<String, Object?> capture, required String techPng, required String clientPng, required String clientName})`, `static const kindName = 'work_order'`, `factory WorkOrderUpload.fromJson(Map<String, Object?>)`.

- [ ] **Step 1: Write the failing test**

`test/sync/upload/work_order_upload_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/sync/upload/queued_upload.dart';
import 'package:stat_trac_technical/sync/upload/work_order_upload.dart';

WorkOrderUpload upload() => WorkOrderUpload(
  mobileId: 'wo-1',
  capture: const {'asset_id': 1234, 'work_type': 1, 'date_in': '2026-10-01'},
  techPng: 'AAAA',
  clientPng: 'BBBB',
  clientName: 'Sister Dlamini',
);

void main() {
  test('one batch: capture, then the technician, then the client', () {
    final ops = [for (final op in upload().toBatch().ops) op.toJson()];

    expect([for (final o in ops) o['action']], ['capture', 'sign', 'sign']);
    expect({for (final o in ops) o['mobile_id']}, {'wo-1'});
    expect({for (final o in ops) o['table']}, {'Repair'});
    expect((ops[1]['data']! as Map)['which'], 'tech');
    expect((ops[2]['data']! as Map)['which'], 'client');
    expect((ops[2]['data']! as Map)['client_name'], 'Sister Dlamini');
  });

  // A resend after a lost reply must be the same batch, or the server's
  // replay rule cannot recognise it.
  test('the batch is identical every time it is built', () {
    final u = upload();
    expect(
      [for (final op in u.toBatch().ops) op.toJson()],
      [for (final op in u.toBatch().ops) op.toJson()],
    );
  });

  test('round trips through the queue as a work order', () {
    final restored = fromQueuedJson(upload().toJson());
    expect(restored, isA<WorkOrderUpload>());
    final w = restored as WorkOrderUpload;
    expect(w.mobileId, 'wo-1');
    expect(w.queueKey, 'wo-1');
    expect(w.capture['asset_id'], 1234);
    expect(w.techPng, 'AAAA');
    expect(w.clientPng, 'BBBB');
    expect(w.clientName, 'Sister Dlamini');
  });

  test('both signatures and a client name are required', () {
    expect(
      () => WorkOrderUpload(mobileId: 'w', capture: const {}, techPng: '',
          clientPng: 'B', clientName: 'x'),
      throwsArgumentError,
    );
    expect(
      () => WorkOrderUpload(mobileId: 'w', capture: const {}, techPng: 'A',
          clientPng: '', clientName: 'x'),
      throwsArgumentError,
    );
    expect(
      () => WorkOrderUpload(mobileId: 'w', capture: const {}, techPng: 'A',
          clientPng: 'B', clientName: '  '),
      throwsArgumentError,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/sync/upload/work_order_upload_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement**

`lib/sync/upload/work_order_upload.dart`:

```dart
import 'queued_upload.dart';
import 'sync_upload_batch.dart';

/// A work order captured on site, waiting to reach the server.
///
/// Becomes exactly one batch — capture, the technician's signature, the
/// client's — and a batch is all or nothing, so a job never lands without its
/// signatures or the signatures without a job.
///
/// [capture] is held already in wire shape (`WorkOrderJob.toWire`). The batch
/// is rebuilt from it at every send, and must come out identical each time: a
/// resend after a lost reply is recognised by the server only if it is the
/// same work under the same mobile id.
class WorkOrderUpload implements QueuedUpload {
  WorkOrderUpload({
    required this.mobileId,
    required this.capture,
    required this.techPng,
    required this.clientPng,
    required this.clientName,
  }) {
    // Both signatures are required for a captured job (the user's rule,
    // 2026-10-01). Checked here as well as on the screen, so nothing can queue
    // a job the server would take without them.
    if (techPng.isEmpty) {
      throw ArgumentError.value(techPng, 'techPng', 'the technician must sign');
    }
    if (clientPng.isEmpty) {
      throw ArgumentError.value(clientPng, 'clientPng', 'the client must sign');
    }
    if (clientName.trim().isEmpty) {
      throw ArgumentError.value(
        clientName,
        'clientName',
        'a client signature must name the person who gave it',
      );
    }
  }

  static const kindName = 'work_order';

  @override
  String get kind => kindName;

  @override
  final String mobileId;

  /// One job per row, so the job's own id is the key.
  @override
  String get queueKey => mobileId;

  final Map<String, Object?> capture;

  /// Standard, padded base64 of each pad's PNG.
  final String techPng;
  final String clientPng;
  final String clientName;

  factory WorkOrderUpload.fromJson(Map<String, Object?> j) => WorkOrderUpload(
    mobileId: j['mobile_id']! as String,
    capture: Map<String, Object?>.from(j['capture']! as Map),
    techPng: j['tech_png']! as String,
    clientPng: j['client_png']! as String,
    clientName: j['client_name']! as String,
  );

  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'mobile_id': mobileId,
    'capture': capture,
    'tech_png': techPng,
    'client_png': clientPng,
    'client_name': clientName,
  };

  @override
  SyncUploadBatch toBatch() => SyncUploadBatch([
    SyncUploadOp.capture(mobileId: mobileId, data: capture),
    SyncUploadOp.sign(
      table: 'Repair',
      mobileId: mobileId,
      which: SignatureSide.tech,
      png: techPng,
    ),
    SyncUploadOp.sign(
      table: 'Repair',
      mobileId: mobileId,
      which: SignatureSide.client,
      png: clientPng,
      clientName: clientName,
    ),
  ]);
}
```

In `queued_upload.dart` add `import 'work_order_upload.dart';` and the branch:

```dart
QueuedUpload fromQueuedJson(Map<String, Object?> j) => switch (j['kind']) {
  null || CertificateUpload.kindName => CertificateUpload.fromJson(j),
  WorkOrderUpload.kindName => WorkOrderUpload.fromJson(j),
  final other => throw FormatException('Unknown queued upload kind: $other'),
};
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/sync/upload/` then `flutter analyze`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/sync/upload test/sync/upload/work_order_upload_test.dart
git commit -m "feat(upload): WorkOrderUpload — capture and both job card signatures in one batch"
```

---

### Task 5: Migration 019 — drop the Horse-era tables, give refusals a field

**Files:**
- Create: `lib/database/migrations/migration_019_drop_work_orders.dart`
- Modify: `lib/database/database_helper.dart`, `lib/sync/upload/upload_queue.dart`
- Test: `test/database/migration_019_test.dart`

**Interfaces:**
- Produces: `Future<void> migration019DropWorkOrders(DatabaseExecutor db)`.
- Changes: `upload_queue` gains `field TEXT`; `UploadQueueEntry.field` (`String?`); `UploadQueue.markRejected(String mobileId, {required String reason, required String message, String? field})`; `UploadQueue.discard(String queueKey)`; `UploadQueue.workOrderCount()`.

- [ ] **Step 1: Write the failing test**

`test/database/migration_019_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stat_trac_technical/database/migrations/migration_001_work_orders.dart';
import 'package:stat_trac_technical/database/migrations/migration_019_drop_work_orders.dart';
import 'package:stat_trac_technical/sync/upload/upload_archive.dart';

Future<Set<String>> tables(Database db) async => {
  for (final r in await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table'",
  ))
    r['name']! as String,
};

Future<Set<String>> columns(Database db, String table) async => {
  for (final r in await db.rawQuery('PRAGMA table_info($table)'))
    r['name']! as String,
};

void main() {
  sqfliteFfiInit();

  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    // A version-18 phone: the Horse-era tables, and the queue as 016 made it.
    await migration001WorkOrders(db);
    await db.execute('''
      CREATE TABLE upload_queue (
        mobile_id TEXT PRIMARY KEY, payload TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        attempts INTEGER NOT NULL DEFAULT 0, last_error TEXT, reason TEXT,
        created_at TEXT NOT NULL, updated_at TEXT NOT NULL)
    ''');
    await db.insert('upload_queue', {
      'mobile_id': 'cert-1', 'payload': '{}',
      'created_at': 'x', 'updated_at': 'x',
    });
    await UploadArchive.createTable(db);
  });

  tearDown(() async => db.close());

  test('drops the four Horse-era work-order tables', () async {
    await migration019DropWorkOrders(db);
    final t = await tables(db);
    for (final gone in [
      'work_orders', 'work_order_status_history',
      'work_order_photos', 'work_order_signatures',
    ]) {
      expect(t, isNot(contains(gone)));
    }
    expect(t, containsAll(['change_log', 'upload_queue', 'upload_archive']));
  });

  test('adds field to the queue and keeps what is queued', () async {
    await migration019DropWorkOrders(db);
    expect(await columns(db, 'upload_queue'), contains('field'));
    expect((await db.query('upload_queue')).single['mobile_id'], 'cert-1');
  });

  test('running it twice is harmless', () async {
    await migration019DropWorkOrders(db);
    await migration019DropWorkOrders(db);
    expect(await columns(db, 'upload_queue'), contains('field'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/database/migration_019_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement the migration**

`lib/database/migrations/migration_019_drop_work_orders.dart`:

```dart
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
```

- [ ] **Step 4: Register it**

`database_helper.dart`:
- `import 'migrations/migration_019_drop_work_orders.dart';`
- `static const _dbVersion = 19;`
- last line of `_onCreate`: `await migration019DropWorkOrders(db);`
- last line of `_onUpgrade`: `if (oldVersion < 19) await migration019DropWorkOrders(db);`

- [ ] **Step 5: The queue reads and writes `field`; discard and work-order count**

`upload_queue.dart`:
- in `createTable`, add `field       TEXT,` after `reason      TEXT,`
- `UploadQueueEntry` gains `this.field,` in the constructor and:

```dart
  /// The server's `ValidationError` field when [reason] is `invalid`.
  final String? field;
```

- in `enqueue`, add `'field': null,` beside `'reason': null,`
- `markRejected`:

```dart
  Future<void> markRejected(
    String mobileId, {
    required String reason,
    required String message,
    String? field,
  }) => _mark(
    mobileId,
    UploadStatus.rejected,
    error: message,
    reason: reason,
    field: field,
  );
```

- `_mark` takes `String? field` and writes `'field': field,`
- in `_read`, `field: r['field'] as String?,`
- add:

```dart
  /// Work orders still on the phone — waiting or set aside.
  Future<int> workOrderCount() async =>
      (await all()).where((e) => e.upload is WorkOrderUpload).length;

  /// The technician chose to throw this away. Nothing else ever deletes a
  /// refused job.
  Future<void> discard(String queueKey) async {
    await _db.delete(table, where: 'mobile_id = ?', whereArgs: [queueKey]);
  }
```

  with `import 'work_order_upload.dart';`.

- [ ] **Step 6: Add a queue test for `field` and `discard`**

Append to `test/sync/upload/upload_queue_test.dart` inside `main()`:

```dart
  test('a refusal keeps the field the server named', () async {
    await queue.enqueue(_upload('cert-1'));
    await queue.markRejected('cert-1',
        reason: 'invalid', message: 'Choose the type of work',
        field: 'jobworktype');
    final e = (await queue.all()).single;
    expect(e.status, UploadStatus.rejected);
    expect(e.field, 'jobworktype');
  });

  test('discard removes only that row', () async {
    await queue.enqueue(_upload('cert-1'));
    await queue.enqueue(_upload('cert-2'));
    await queue.discard('cert-1');
    expect([for (final e in await queue.all()) e.upload.mobileId], ['cert-2']);
  });
```

- [ ] **Step 7: Run the tests**

Run: `flutter test test/database test/sync/upload` then `flutter analyze`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/database lib/sync/upload/upload_queue.dart test/database/migration_019_test.dart test/sync/upload/upload_queue_test.dart
git commit -m "feat(db): v19 drops the Horse-era work-order tables; a refusal keeps its field"
```

---

### Task 6: The worker sends work orders — only to a server that takes them

**Files:**
- Modify: `lib/sync/upload/upload_worker.dart`, `lib/sync/upload/upload_run_message.dart`
- Test: `test/sync/upload/upload_worker_work_order_test.dart`, append to `test/sync/upload/upload_run_message_test.dart`

**Interfaces:**
- Consumes: `WorkOrderUpload` (Task 4); `markRejected(..., field:)` (Task 5); `SyncUploadGuarantee.captureAction/jobSignAction` (Task 2).
- Produces: `UploadRunResult.waitingForServer` (`int`, default 0), `UploadRunResult.appliedWorkOrders` (`int`, default 0); `UploadWorker.serverNotReady` (`String` constant); `@visibleForTesting static void UploadWorker.forgetServer()`.

- [ ] **Step 1: Write the failing test**

`test/sync/upload/upload_worker_work_order_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stat_trac_technical/sync/upload/queued_upload.dart';
import 'package:stat_trac_technical/sync/upload/sync_upload_client.dart';
import 'package:stat_trac_technical/sync/upload/sync_upload_result.dart';
import 'package:stat_trac_technical/sync/upload/upload_archive.dart';
import 'package:stat_trac_technical/sync/upload/upload_queue.dart';
import 'package:stat_trac_technical/sync/upload/upload_worker.dart';
import 'package:stat_trac_technical/sync/upload/work_order_upload.dart';

class MockClient extends Mock implements SyncUploadClient {}

WorkOrderUpload _wo(String id) => WorkOrderUpload(
  mobileId: id,
  capture: const {'asset_id': 1234, 'work_type': 1},
  techPng: 'AAAA',
  clientPng: 'BBBB',
  clientName: 'Sister Dlamini',
);

const _ready = ['batch_atomic', 'capture_action', 'job_sign_action'];

void main() {
  sqfliteFfiInit();
  setUpAll(() => registerFallbackValue<QueuedUpload>(_wo('fallback')));

  late Database db;
  late UploadQueue queue;
  late UploadArchive archive;
  late MockClient client;
  late UploadWorker worker;
  late List<(String, int)> confirmed;

  setUp(() async {
    UploadWorker.forgetServer();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await UploadQueue.createTable(db);
    await UploadArchive.createTable(db);
    queue = UploadQueue(db);
    archive = UploadArchive(db);
    client = MockClient();
    confirmed = [];
    worker = UploadWorker(
      queue: queue,
      archive: archive,
      client: client,
      confirm: (m, s) async {
        confirmed.add((m, s));
        return true;
      },
      company: () async => 'demo',
      deviceToken: () async => 'token',
    );
  });

  tearDown(() async => db.close());

  void answers(SyncUploadResult r) => when(
    () => client.upload(
      company: any(named: 'company'),
      deviceToken: any(named: 'deviceToken'),
      upload: any(named: 'upload'),
    ),
  ).thenAnswer((_) async => r);

  int sends() => verify(
    () => client.upload(
      company: any(named: 'company'),
      deviceToken: any(named: 'deviceToken'),
      upload: any(named: 'upload'),
    ),
  ).callCount;

  test('applied: archived, then gone from the queue, never confirmed as a '
      'certificate', () async {
    await queue.enqueue(_wo('wo-1'));
    answers(const UploadApplied(applied: 0, assigned: {'wo-1': 1801},
        issued: [], enforces: _ready));

    final r = await worker.drain();

    expect(r.applied, 1);
    expect(r.appliedWorkOrders, 1);
    expect(await queue.count(), 0);
    expect((await archive.all()).single.mobileId, 'wo-1');
    expect(confirmed, isEmpty);
  });

  // An older server refuses `capture` as a 400 and applies nothing. That is
  // "not ready yet", not a broken app — the job must wait, not be parked.
  test('a 400 from a server without the actions keeps the job pending',
      () async {
    await queue.enqueue(_wo('wo-1'));
    answers(const UploadClientError('"capture" is not something a device may '
        'ask for', enforces: ['batch_atomic']));

    final r = await worker.drain();

    final e = (await queue.all()).single;
    expect(e.status, UploadStatus.pending);
    expect(e.lastError, UploadWorker.serverNotReady);
    expect(r.waitingForServer, 1);
    expect(r.failed, 0);
  });

  test('once the server is known not to take them, it is not asked again',
      () async {
    await queue.enqueue(_wo('wo-1'));
    answers(const UploadClientError('no', enforces: ['batch_atomic']));
    await worker.drain();
    await worker.drain();

    expect(sends(), 1);
    expect((await queue.all()).single.status, UploadStatus.pending);
  });

  test('a 400 from a server that does take them is a real failure', () async {
    await queue.enqueue(_wo('wo-1'));
    answers(const UploadClientError('malformed', enforces: _ready));

    final r = await worker.drain();

    expect((await queue.all()).single.status, UploadStatus.failed);
    expect(r.failed, 1);
  });

  for (final reason in ['open_work_order', 'asset_on_loan', 'asset_inactive',
      'not_found', 'already_signed']) {
    test('$reason sets the job aside and never deletes it', () async {
      await queue.enqueue(_wo('wo-1'));
      answers(UploadRejected([
        UploadRejection(table: 'Repair', mobileId: 'wo-1', reason: reason,
            message: 'refused'),
      ], enforces: _ready));

      await worker.drain();

      final e = (await queue.all()).single;
      expect(e.status, UploadStatus.rejected);
      expect(e.reason, reason);
    });
  }

  test('invalid keeps the field', () async {
    await queue.enqueue(_wo('wo-1'));
    answers(const UploadRejected([
      UploadRejection(table: 'Repair', mobileId: 'wo-1', reason: 'invalid',
          message: 'Choose the type of work', field: 'jobworktype'),
    ], enforces: _ready));

    await worker.drain();

    expect((await queue.all()).single.field, 'jobworktype');
  });

  test('no signal: stays pending, unchanged, for the identical resend',
      () async {
    final wo = _wo('wo-1');
    await queue.enqueue(wo);
    answers(const UploadTransportError(0, 'Cannot reach the server.'));

    await worker.drain();

    final e = (await queue.all()).single;
    expect(e.status, UploadStatus.pending);
    expect(e.upload.toJson(), wo.toJson());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/sync/upload/upload_worker_work_order_test.dart`
Expected: FAIL — `forgetServer`, `appliedWorkOrders`, `waitingForServer`, `serverNotReady` not defined.

- [ ] **Step 3: Implement in the worker**

`upload_worker.dart`:
- `import 'work_order_upload.dart';`
- `UploadRunResult` gains (constructor `this.waitingForServer = 0, this.appliedWorkOrders = 0,`):

```dart
  /// Work orders held back because the server does not yet take them.
  final int waitingForServer;

  /// Of [applied], how many were work orders.
  final int appliedWorkOrders;
```

- in `UploadWorker`:

```dart
  /// Shown on a work order held for a server that cannot take it yet.
  static const serverNotReady =
      'Waiting — the server is not ready for work orders yet.';

  /// What the server last said it guarantees. Null until it has answered.
  ///
  /// Static for the same reason [_running] is: every worker talks to one
  /// server. Unknown means "ask": an older server refuses `capture` outright
  /// and applies nothing, so asking costs one round trip and loses nothing.
  static List<String>? _lastEnforces;

  @visibleForTesting
  static void forgetServer() => _lastEnforces = null;

  static bool _takesWorkOrders(List<String>? enforces) =>
      enforces == null ||
      (enforces.contains(SyncUploadGuarantee.captureAction) &&
          enforces.contains(SyncUploadGuarantee.jobSignAction));
```

- declare `var waitingForServer = 0, appliedWorkOrders = 0;` beside the other counters, and pass both into **every** `UploadRunResult(...)` the loop returns (the auth, signal and final ones).
- at the top of the loop body, after `final cert = ...`, **before** `attempted++`:

```dart
      if (upload is WorkOrderUpload && !_takesWorkOrders(_lastEnforces)) {
        await _queue.markRetryable(upload.queueKey, serverNotReady);
        waitingForServer++;
        continue;
      }
```

- right after `final result = await _client.upload(...)`:

```dart
      if (result is! UploadTransportError && result is! UploadAuthExpired) {
        _lastEnforces = result.enforces;
      }
```

- in `case UploadApplied`, after `applied++;` add `if (upload is WorkOrderUpload) appliedWorkOrders++;`
- in `case UploadRejected`, pass `field: r?.field,` to `markRejected`, and change the fallback message to `r?.message ?? 'The server refused this.'`
- replace `case UploadClientError(:final message):` body with:

```dart
        case UploadClientError(:final message):
          // A server without the work-order actions refuses them with a 400
          // and applies nothing. That is a server not yet updated, not a
          // broken app, and the job waits rather than being parked.
          if (upload is WorkOrderUpload && !_takesWorkOrders(result.enforces)) {
            await _queue.markRetryable(upload.queueKey, serverNotReady);
            waitingForServer++;
            break;
          }
          await _queue.markFailed(upload.queueKey, message);
          failed++;
```

- [ ] **Step 4: Say it in the run message**

Append to `test/sync/upload/upload_run_message_test.dart` inside `main()`:

```dart
  test('only work orders waiting for the server is a warning, not "nothing"',
      () {
    final m = describeUploadRun(const UploadRunResult(
      attempted: 0, applied: 0, conflicted: 0, rejected: 0, failed: 0,
      stoppedForSignal: false, waitingForServer: 2,
    ));
    expect(m.tone, UploadMessageTone.warning);
    expect(m.text, '2 work orders waiting — the server is not ready for '
        'work orders yet.');
  });

  test('a sent work order is not called a certificate', () {
    final m = describeUploadRun(const UploadRunResult(
      attempted: 2, applied: 2, conflicted: 0, rejected: 0, failed: 0,
      stoppedForSignal: false, appliedWorkOrders: 1,
    ));
    expect(m.text, 'Sent 1 certificate and 1 work order.');
  });
```

(`UploadRunResult` is imported there already via `upload_worker.dart`; add the import if not.)

In `upload_run_message.dart`:
- first branch becomes:

```dart
  if (r.attempted == 0) {
    if (r.waitingForServer > 0) return _waitingForServer(r.waitingForServer);
    return const UploadRunMessage(
      'Nothing waiting to send.',
      UploadMessageTone.quiet,
    );
  }
```

- change the rejected/failed text to `'${r.rejected + r.failed} could not be sent — open it to see why.'`
- before the final success return:

```dart
  if (r.waitingForServer > 0) return _waitingForServer(r.waitingForServer);
```

- final success return:

```dart
  return UploadRunMessage('Sent ${_sent(r)}.', UploadMessageTone.success);
```

- helpers at the bottom of the file:

```dart
UploadRunMessage _waitingForServer(int n) => UploadRunMessage(
  '$n work order${n == 1 ? '' : 's'} waiting — the server is not ready for '
  'work orders yet.',
  UploadMessageTone.warning,
);

String _sent(UploadRunResult r) {
  final certs = r.applied - r.appliedWorkOrders;
  final wos = r.appliedWorkOrders;
  final parts = [
    if (certs > 0 || wos == 0) '$certs certificate${certs == 1 ? '' : 's'}',
    if (wos > 0) '$wos work order${wos == 1 ? '' : 's'}',
  ];
  return parts.join(' and ');
}
```

If an existing run-message test asserted the old "open the certificate to see why" wording, update it to the new text.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/sync/upload/` then `flutter analyze`
Expected: PASS, including every pre-existing worker and message test.

- [ ] **Step 6: Commit**

```bash
git add lib/sync/upload test/sync/upload
git commit -m "feat(upload): send work orders only to a server that takes capture and job signing"
```

---

### Task 7: Delete the Horse-era work-order code

**Files:**
- Delete: every file under `lib/features/work_orders/` **except** `domain/work_type.dart` and `domain/work_order_job.dart` (Task 3).
- Modify: `lib/features/assets/presentation/providers/asset_providers.dart`, `lib/features/assets/presentation/screens/asset_detail_screen.dart`, `lib/features/dashboard/presentation/providers/dashboard_providers.dart`, `lib/features/dashboard/presentation/screens/dashboard_screen.dart`, `test/features/dashboard/dashboard_module_grid_test.dart`

**Interfaces:**
- Moves: `assetLocalDataSourceProvider` now lives in `asset_providers.dart`.
- Changes: `DashboardStats({required int pendingWorkOrders, required int pendingCerts})` (Task 12 adds `capturedThisMonth`).

- [ ] **Step 1: Delete the old tree**

```bash
git rm -r lib/features/work_orders/data lib/features/work_orders/presentation lib/features/work_orders/domain/entities lib/features/work_orders/domain/repositories
ls lib/features/work_orders/domain
```

Expected: only `work_order_job.dart` and `work_type.dart` remain. If anything else remains under `domain/`, `git rm` it too.

- [ ] **Step 2: Move the one provider the asset feature used**

In `asset_providers.dart`, remove `import '../../../work_orders/presentation/providers/work_order_providers.dart';`, add `import '../../../../database/database_helper.dart';`, and add under the infrastructure section:

```dart
@riverpod
AssetLocalDataSource assetLocalDataSource(Ref ref) =>
    AssetLocalDataSourceImpl(DatabaseHelper.instance);
```

- [ ] **Step 3: The asset History tab stops reading the dead table**

In `asset_detail_screen.dart`:
- remove the four `work_orders` imports (lines 9–12);
- replace the whole `_HistoryTab` class body's `build` with:

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The old list read the Horse-era work_orders table, which nothing has
    // filled since 2026-09-05. Captured work orders are in the Worklist.
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Work orders for this machine are in the Worklist.',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
```

- delete the classes `_WoHistoryTile`, `_WoChip` and the function `_woStatusLabel` (and any other helper `flutter analyze` then reports unused).

- [ ] **Step 4: Dashboard counts from the outbox, no donut**

Replace `dashboard_providers.dart`'s `DashboardStats` and `dashboardStats` with:

```dart
class DashboardStats {
  const DashboardStats({
    required this.pendingWorkOrders,
    required this.pendingCerts,
  });

  /// Captured jobs still on this phone — waiting to send or set aside.
  final int pendingWorkOrders;
  final int pendingCerts;
}

/// Counted from the OUTBOX. A captured work order is completed the moment
/// the server applies it, so nothing synced is pending — what is pending is
/// what has not left the phone.
@riverpod
Future<DashboardStats> dashboardStats(Ref ref) async {
  final queue = UploadQueue(await DatabaseHelper.instance.database);
  return DashboardStats(
    pendingWorkOrders: await queue.workOrderCount(),
    pendingCerts: await queue.certificateCount(),
  );
}
```

In `dashboard_screen.dart`:
- remove `import 'package:fl_chart/fl_chart.dart';` and the two `work_orders` screen imports;
- in `_HomeBody.build`, remove the whole second `stats.when(...)` (donut + KPI row) and the `SizedBox(height: 16)` after it, and change the first to:

```dart
          stats.when(
            data: (s) => _PendingTasksRow(
              woCount: s.pendingWorkOrders,
              pmCount: 0,
              certsCount: s.pendingCerts,
            ),
            loading: () =>
                const _PendingTasksRow(woCount: 0, pmCount: 0, certsCount: 0),
            error: (e, _) =>
                const _PendingTasksRow(woCount: 0, pmCount: 0, certsCount: 0),
          ),
```

- delete classes `_StatsCard`, `_ChartLegend`, `_KpiRow`, `_KpiTile`;
- in `DashboardModuleGrid`, remove the `destination:` lines from the Worklist and Work Order tiles (they stay `enabled: false` until Task 12).

`fl_chart` stays in `pubspec.yaml` unless `grep -rn fl_chart lib` finds nothing; if nothing, remove it from `pubspec.yaml` and run `flutter pub get`.

- [ ] **Step 5: Regenerate and check**

Run:
```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```
Expected: analyze clean; all tests PASS (the dashboard grid test is unchanged — the tiles are still disabled).

- [ ] **Step 6: Commit**

```bash
git add -A lib test pubspec.yaml pubspec.lock
git commit -m "refactor: remove the Horse-era work-order module and the donut that read it"
```

---

### Task 8: Reading captured work orders from PowerSync

**Files:**
- Create: `lib/features/work_orders/domain/work_order_summary.dart`, `lib/features/work_orders/domain/work_order_record.dart`, `lib/features/work_orders/data/powersync_work_order_data_source.dart`
- Test: `test/features/work_orders/powersync_work_order_data_source_test.dart`, `test/features/work_orders/worklist_merge_test.dart`

**Interfaces:**
- Produces:
  - `typedef SqlRead = Future<List<Map<String, Object?>>> Function(String sql, List<Object?> args);`
  - `class AssetBrief { int id; String? equipment; String? serial; String? hospital; }`
  - `enum WorkOrderQueueState { waiting, setAside }`
  - `class WorkOrderSummary { int? trackId; String? mobileId; DateTime? dateIn; int? assetId; AssetBrief? asset; WorkType? workType; String status; WorkOrderQueueState? queueState; String? message; }`
  - `class SyncedWorklist { List<WorkOrderSummary> items; bool complete; }`
  - `List<WorkOrderSummary> mergeWorklist({required List<WorkOrderSummary> queued, required List<WorkOrderSummary> synced})`
  - `class WorkOrderRecord { int trackId; String? mobileId; int? assetId; WorkType? workType; String status; DateTime? started; DateTime? finished; int? equipHrs; int? nop; String fault, work, note, clientName, jobCardNo, tech; }`
  - `PowerSyncWorkOrderDataSource(SqlRead read, {Duration timeout})`, `.of(PowerSyncDatabase)`, methods `Future<int?> openRepairOn(int assetId)`, `Future<SyncedWorklist> capturedBy(int technicianId)`, `Future<Map<int, AssetBrief>> assetsByIds(Set<int> ids)`, `Future<WorkOrderRecord?> record(int trackId)`.

- [ ] **Step 1: Write the failing data-source test**

`test/features/work_orders/powersync_work_order_data_source_test.dart` — the SQL runs against real SQLite tables named as PowerSync names them:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stat_trac_technical/features/work_orders/data/powersync_work_order_data_source.dart';
import 'package:stat_trac_technical/features/work_orders/domain/work_type.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late PowerSyncWorkOrderDataSource ds;

  Future<void> repair(int id, {int tech = 31, int request = 1, int? status = 9,
      int asset = 100, String date = '2026-10-01', String? mobile}) =>
      db.insert('Repair', {
        'RepairTrackID': id, 'RepairTechID': tech, 'RepairRequest': request,
        'RepairStatus': status, 'RepairAssetID': asset, 'RepairDate': date,
        'RepairType': 1, 'RepairMobileID': mobile,
      });

  Future<void> card(int trackId, {int type = 3}) => db.insert('RepairDetail', {
    'RepairDetailJobID': trackId * 10, 'RepairDetailTrackID': trackId,
    'RepairDetailType': type, 'RepairDetailDateIN': '2026-10-01',
    'RepairDetailTimeIn': '08:15:00', 'RepairDetailDate': '2026-10-01',
    'RepairDetailTimeOut': '10:40:00', 'RepairDetailFault': 'Beeps',
    'RepairDetailManualWoType': 1, 'RepairDetailTech': 'Athi',
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('CREATE TABLE "Repair" ("RepairTrackID" INTEGER, '
        '"RepairTechID" INTEGER, "RepairRequest" INTEGER, "RepairStatus" '
        'INTEGER, "RepairAssetID" INTEGER, "RepairDate" TEXT, "RepairType" '
        'INTEGER, "RepairMobileID" TEXT)');
    await db.execute('CREATE TABLE "RepairDetail" ("RepairDetailJobID" '
        'INTEGER, "RepairDetailTrackID" INTEGER, "RepairDetailType" INTEGER, '
        '"RepairDetailDateIN" TEXT, "RepairDetailTimeIn" TEXT, '
        '"RepairDetailDate" TEXT, "RepairDetailTimeOut" TEXT, '
        '"RepairDetailFault" TEXT, "RepairDetailWork" TEXT, '
        '"RepairDetailNote" TEXT, "RepairDetailClient" TEXT, '
        '"RepairDetailJobCard" TEXT, "RepairDetailHrs" INTEGER, '
        '"RepairDetailNop" INTEGER, "RepairDetailManualWoType" INTEGER, '
        '"RepairDetailTech" TEXT)');
    await db.execute('CREATE TABLE "Asset" ("AssetID" INTEGER, '
        '"AssetEquipmentType" TEXT, "AssetSerialNo" TEXT, "AssetHospital" '
        'TEXT)');
    await db.execute('CREATE TABLE "ComboStatus" ("StatusID" INTEGER, '
        '"StatusDescription" TEXT)');
    await db.insert('Asset', {'AssetID': 100, 'AssetEquipmentType': 'Pump',
        'AssetSerialNo': 'SN1', 'AssetHospital': 'Groote Schuur'});
    await db.insert('ComboStatus', {'StatusID': 9,
        'StatusDescription': 'WO Completed'});
    ds = PowerSyncWorkOrderDataSource((sql, args) => db.rawQuery(sql, args));
  });

  tearDown(() async => db.close());

  group('open repair on a machine', () {
    test('status 9 is closed', () async {
      await repair(1, status: 9);
      expect(await ds.openRepairOn(100), isNull);
    });
    test('a blank status is open', () async {
      await repair(1, status: null);
      expect(await ds.openRepairOn(100), 1);
    });
    test('a PM work order does not count', () async {
      await repair(1, status: 2, request: 2);
      expect(await ds.openRepairOn(100), isNull);
    });
    // Any technician's, booked in or captured — the server refuses either.
    test('somebody else\'s counts, lowest number first', () async {
      await repair(7, status: 2, tech: 99);
      await repair(5, status: 1, tech: 98);
      expect(await ds.openRepairOn(100), 5);
    });
  });

  group('captured by the technician', () {
    test('only captures, only theirs', () async {
      await repair(1, mobile: 'wo-1');
      await card(1);
      await repair(2); // booked in
      await card(2, type: 1);
      await repair(3, tech: 99); // someone else's capture
      await card(3);

      final list = await ds.capturedBy(31);

      expect(list.complete, isTrue);
      expect([for (final w in list.items) w.trackId], [1]);
      final w = list.items.single;
      expect(w.mobileId, 'wo-1');
      expect(w.status, 'WO Completed');
      expect(w.workType, WorkType.repair);
      expect(w.asset?.hospital, 'Groote Schuur');
    });

    // If the cards cannot be read, nothing synced can be shown: without them a
    // booked-in work order is indistinguishable from a capture.
    test('cards timing out shows nothing synced and says so', () async {
      await repair(1);
      await card(1);
      final slow = PowerSyncWorkOrderDataSource(
        (sql, args) async {
          if (sql.contains('"RepairDetail"')) {
            await Future<void>.delayed(const Duration(milliseconds: 200));
          }
          return db.rawQuery(sql, args);
        },
        timeout: const Duration(milliseconds: 20),
      );

      final list = await slow.capturedBy(31);

      expect(list.complete, isFalse);
      expect(list.items, isEmpty);
    });
  });

  test('record reads the job card', () async {
    await repair(1, mobile: 'wo-1');
    await card(1);

    final r = (await ds.record(1))!;

    expect(r.trackId, 1);
    expect(r.started, DateTime(2026, 10, 1, 8, 15));
    expect(r.finished, DateTime(2026, 10, 1, 10, 40));
    expect(r.fault, 'Beeps');
    expect(r.tech, 'Athi');
    expect(r.workType, WorkType.repair);
  });
}
```

- [ ] **Step 2: Write the failing merge test**

`test/features/work_orders/worklist_merge_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/features/work_orders/domain/work_order_summary.dart';

WorkOrderSummary synced(int id, String? mobile) =>
    WorkOrderSummary(trackId: id, mobileId: mobile, status: 'WO Completed');

WorkOrderSummary queued(String mobile) => WorkOrderSummary(
  mobileId: mobile,
  status: 'Waiting to sync',
  queueState: WorkOrderQueueState.waiting,
);

void main() {
  test('queued first, then synced', () {
    final m = mergeWorklist(
      queued: [queued('wo-9')],
      synced: [synced(1, 'wo-1')],
    );
    expect([for (final w in m) w.mobileId], ['wo-9', 'wo-1']);
  });

  // Applied but the queue row not yet gone, or archived and synced in the
  // same moment: the synced row wins and the job shows once.
  test('a job that has synced is not also shown as queued', () {
    final m = mergeWorklist(
      queued: [queued('wo-1')],
      synced: [synced(1, 'wo-1')],
    );
    expect(m, hasLength(1));
    expect(m.single.trackId, 1);
  });
}
```

- [ ] **Step 3: Run both to verify they fail**

Run: `flutter test test/features/work_orders/`
Expected: FAIL — files do not exist.

- [ ] **Step 4: Implement `work_order_summary.dart`**

```dart
import 'work_type.dart';

/// Enough of a machine to name it in a list.
class AssetBrief {
  const AssetBrief({required this.id, this.equipment, this.serial, this.hospital});

  final int id;
  final String? equipment;
  final String? serial;
  final String? hospital;
}

enum WorkOrderQueueState { waiting, setAside }

/// One row of the Worklist — a synced captured work order, or a job still on
/// the phone.
class WorkOrderSummary {
  const WorkOrderSummary({
    this.trackId,
    this.mobileId,
    this.dateIn,
    this.assetId,
    this.asset,
    this.workType,
    required this.status,
    this.queueState,
    this.message,
  });

  /// The server's number. Null until the server has it.
  final int? trackId;
  final String? mobileId;
  final DateTime? dateIn;
  final int? assetId;
  final AssetBrief? asset;
  final WorkType? workType;
  final String status;

  /// Null for a synced work order.
  final WorkOrderQueueState? queueState;

  /// The server's refusal, for a job set aside.
  final String? message;

  WorkOrderSummary withAsset(AssetBrief? a) => WorkOrderSummary(
    trackId: trackId,
    mobileId: mobileId,
    dateIn: dateIn,
    assetId: assetId,
    asset: a,
    workType: workType,
    status: status,
    queueState: queueState,
    message: message,
  );
}

/// Jobs on the phone first — they are the newest and the ones that may need
/// the technician — then the synced ones. A queued job whose mobile id has
/// already come back through sync is dropped: the synced row is the truth.
List<WorkOrderSummary> mergeWorklist({
  required List<WorkOrderSummary> queued,
  required List<WorkOrderSummary> synced,
}) {
  final arrived = {for (final s in synced) ?s.mobileId};
  return [
    for (final q in queued)
      if (!arrived.contains(q.mobileId)) q,
    ...synced,
  ];
}
```

- [ ] **Step 5: Implement `work_order_record.dart`**

```dart
import 'work_type.dart';

/// A synced work order, as the detail screen shows it.
class WorkOrderRecord {
  const WorkOrderRecord({
    required this.trackId,
    this.mobileId,
    this.assetId,
    this.workType,
    required this.status,
    this.started,
    this.finished,
    this.equipHrs,
    this.nop,
    this.fault = '',
    this.work = '',
    this.note = '',
    this.clientName = '',
    this.jobCardNo = '',
    this.tech = '',
  });

  final int trackId;
  final String? mobileId;
  final int? assetId;
  final WorkType? workType;
  final String status;
  final DateTime? started;
  final DateTime? finished;
  final int? equipHrs;
  final int? nop;
  final String fault;
  final String work;
  final String note;
  final String clientName;
  final String jobCardNo;
  final String tech;
}
```

- [ ] **Step 6: Implement the data source**

`lib/features/work_orders/data/powersync_work_order_data_source.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:powersync/powersync.dart';

import '../../../sync/powersync_types.dart';
import '../domain/work_order_record.dart';
import '../domain/work_order_summary.dart';
import '../domain/work_type.dart';

typedef SqlRead =
    Future<List<Map<String, Object?>>> Function(String sql, List<Object?> args);

/// What the Worklist could read from the synced tables.
class SyncedWorklist {
  const SyncedWorklist(this.items, {required this.complete});

  final List<WorkOrderSummary> items;

  /// False when the job cards could not be read in time. The synced part is
  /// then empty rather than unfiltered — without the cards a booked-in work
  /// order cannot be told from a capture.
  final bool complete;
}

/// Reads work orders from PowerSync's local database.
///
/// **No joins.** A PowerSync table is a view over JSON with no index on an
/// arbitrary column, so a join scans the whole store per row — joining
/// certificates to assets made that list spin for ever. Each table is read on
/// its own and the pieces are put together here.
///
/// Takes a [SqlRead] rather than the database so the SQL can be tested against
/// plain SQLite tables of the same names.
class PowerSyncWorkOrderDataSource {
  PowerSyncWorkOrderDataSource(
    this._read, {
    this.timeout = const Duration(seconds: 5),
  });

  factory PowerSyncWorkOrderDataSource.of(PowerSyncDatabase db) =>
      PowerSyncWorkOrderDataSource((sql, args) => db.getAll(sql, args));

  final SqlRead _read;

  /// Applied to every read after the first. The first is the list itself and
  /// is allowed to take as long as it takes.
  final Duration timeout;

  /// The lowest-numbered open repair work order on [assetId], from anyone.
  ///
  /// The server's own test (`workorder_write.go:348`): a repair work order
  /// whose status is not 9. A blank status is open. A warning only — it is as
  /// current as the last sync, and the server decides.
  Future<int?> openRepairOn(int assetId) async {
    final rows = await _read(
      'SELECT "RepairTrackID" FROM "Repair" '
      'WHERE "RepairAssetID" = ? AND "RepairRequest" = 1 '
      'AND coalesce("RepairStatus", 0) <> 9 '
      'ORDER BY "RepairTrackID" LIMIT 1',
      [assetId],
    );
    return rows.isEmpty ? null : psInt(rows.first['RepairTrackID']);
  }

  /// The technician's captured work orders, newest first.
  Future<SyncedWorklist> capturedBy(int technicianId) async {
    final repairs = await _read(
      'SELECT "RepairTrackID", "RepairAssetID", "RepairDate", "RepairType", '
      '"RepairStatus", "RepairMobileID" FROM "Repair" '
      'WHERE "RepairTechID" = ? AND "RepairRequest" = 1 '
      'ORDER BY "RepairDate" DESC, "RepairTrackID" DESC LIMIT 500',
      [technicianId],
    );
    if (repairs.isEmpty) return const SyncedWorklist([], complete: true);

    final ids = [for (final r in repairs) ?psInt(r['RepairTrackID'])];

    final Set<int> captured;
    try {
      final cards = await _read(
        'SELECT "RepairDetailTrackID" FROM "RepairDetail" '
        'WHERE "RepairDetailType" = 3 '
        'AND "RepairDetailTrackID" IN (${_marks(ids.length)})',
        ids,
      ).timeout(timeout);
      captured = {for (final c in cards) ?psInt(c['RepairDetailTrackID'])};
    } catch (e) {
      debugPrint('[work orders] job cards unreadable: $e');
      return const SyncedWorklist([], complete: false);
    }

    final kept = [
      for (final r in repairs)
        if (captured.contains(psInt(r['RepairTrackID']))) r,
    ];
    final statuses = await _statusNames({
      for (final r in kept) psInt(r['RepairStatus']) ?? 0,
    });
    final assets = await assetsByIds({
      for (final r in kept) ?psInt(r['RepairAssetID']),
    });

    return SyncedWorklist([
      for (final r in kept)
        WorkOrderSummary(
          trackId: psInt(r['RepairTrackID']),
          mobileId: r['RepairMobileID'] as String?,
          dateIn: psDate(r['RepairDate']),
          assetId: psInt(r['RepairAssetID']),
          asset: assets[psInt(r['RepairAssetID'])],
          workType: WorkType.fromCode(psInt(r['RepairType'])),
          status: statuses[psInt(r['RepairStatus']) ?? 0] ??
              'Status ${psInt(r['RepairStatus']) ?? 0}',
        ),
    ], complete: true);
  }

  /// Machines by id. Missing or slow comes back empty — a list without the
  /// hospital is worth more than a list that never arrives.
  Future<Map<int, AssetBrief>> assetsByIds(Set<int> ids) async {
    if (ids.isEmpty) return const {};
    try {
      final rows = await _read(
        'SELECT "AssetID", "AssetEquipmentType", "AssetSerialNo", '
        '"AssetHospital" FROM "Asset" WHERE "AssetID" IN (${_marks(ids.length)})',
        ids.toList(),
      ).timeout(timeout);
      return {
        for (final a in rows)
          if (psInt(a['AssetID']) case final id?)
            id: AssetBrief(
              id: id,
              equipment: a['AssetEquipmentType'] as String?,
              serial: a['AssetSerialNo'] as String?,
              hospital: a['AssetHospital'] as String?,
            ),
      };
    } catch (e) {
      debugPrint('[work orders] assets unreadable: $e');
      return const {};
    }
  }

  /// One work order and its job card.
  Future<WorkOrderRecord?> record(int trackId) async {
    final repairs = await _read(
      'SELECT "RepairTrackID", "RepairAssetID", "RepairStatus", '
      '"RepairMobileID" FROM "Repair" WHERE "RepairTrackID" = ? LIMIT 1',
      [trackId],
    );
    if (repairs.isEmpty) return null;
    final r = repairs.first;

    final cards = await _read(
      'SELECT * FROM "RepairDetail" WHERE "RepairDetailTrackID" = ? '
      'ORDER BY "RepairDetailJobID" DESC LIMIT 1',
      [trackId],
    ).timeout(timeout);
    final c = cards.isEmpty ? const <String, Object?>{} : cards.first;

    final status = psInt(r['RepairStatus']) ?? 0;
    final names = await _statusNames({status});

    return WorkOrderRecord(
      trackId: trackId,
      mobileId: r['RepairMobileID'] as String?,
      assetId: psInt(r['RepairAssetID']),
      workType: WorkType.fromCode(psInt(c['RepairDetailManualWoType'])),
      status: names[status] ?? 'Status $status',
      started: _at(c['RepairDetailDateIN'], c['RepairDetailTimeIn']),
      finished: _at(c['RepairDetailDate'], c['RepairDetailTimeOut']),
      equipHrs: psInt(c['RepairDetailHrs']),
      nop: psInt(c['RepairDetailNop']),
      fault: c['RepairDetailFault'] as String? ?? '',
      work: c['RepairDetailWork'] as String? ?? '',
      note: c['RepairDetailNote'] as String? ?? '',
      clientName: c['RepairDetailClient'] as String? ?? '',
      jobCardNo: c['RepairDetailJobCard'] as String? ?? '',
      tech: c['RepairDetailTech'] as String? ?? '',
    );
  }

  Future<Map<int, String>> _statusNames(Set<int> ids) async {
    if (ids.isEmpty) return const {};
    try {
      final rows = await _read(
        'SELECT "StatusID", "StatusDescription" FROM "ComboStatus" '
        'WHERE "StatusID" IN (${_marks(ids.length)})',
        ids.toList(),
      ).timeout(timeout);
      return {
        for (final s in rows)
          if (psInt(s['StatusID']) case final id?)
            id: (s['StatusDescription'] as String? ?? '').trim(),
      };
    } catch (_) {
      return const {};
    }
  }

  static String _marks(int n) => List.filled(n, '?').join(',');

  /// A date column and a time column, as one moment.
  static DateTime? _at(Object? date, Object? time) {
    final d = psDate(date);
    if (d == null) return null;
    final parts = (time is String ? time : '').split(':');
    return DateTime(
      d.year,
      d.month,
      d.day,
      parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0,
      parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }
}
```

- [ ] **Step 7: Run the tests**

Run: `flutter test test/features/work_orders/` then `flutter analyze`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/features/work_orders test/features/work_orders
git commit -m "feat(work-orders): read captured work orders from PowerSync without joins"
```

---

### Task 9: Providers

**Files:**
- Create: `lib/features/work_orders/presentation/providers/work_order_providers.dart` (+ generated `.g.dart`)
- Modify: `lib/sync/upload/upload_archive.dart` — add `latestFor`
- Test: `test/features/work_orders/worklist_provider_test.dart`

**Interfaces:**
- Consumes: `PowerSyncWorkOrderDataSource`, `mergeWorklist` (Task 8); `uploadQueueProvider`, `uploadArchiveProvider` (`lib/sync/upload/upload_providers.dart`); `syncDatabaseProvider` (`lib/sync/powersync_providers.dart`); `authProvider` / `AuthAuthenticated(user)` with `user.id`, `user.name`.
- Produces:
  - `workOrderSourceProvider` → `Future<PowerSyncWorkOrderDataSource>`
  - `class Worklist { List<WorkOrderSummary> items; bool syncedComplete; }`, `worklistProvider` → `Future<Worklist>`
  - `openRepairOnAssetProvider(int assetId)` → `Future<int?>`
  - `workOrderRecordProvider(int trackId)` → `Future<WorkOrderRecord?>`
  - `queuedWorkOrderProvider(String mobileId)` → `Future<UploadQueueEntry?>`
  - `phoneSignaturesProvider(String mobileId)` → `Future<WorkOrderUpload?>` — the queue's payload, else the archive's.
  - `UploadArchive.latestFor(String mobileId)` → `Future<QueuedUpload?>`

- [ ] **Step 1: Write the failing test**

`test/features/work_orders/worklist_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stat_trac_technical/features/auth/domain/entities/user.dart';
import 'package:stat_trac_technical/features/auth/presentation/providers/auth_providers.dart';
import 'package:stat_trac_technical/features/auth/presentation/providers/auth_state.dart';
import 'package:stat_trac_technical/features/work_orders/data/powersync_work_order_data_source.dart';
import 'package:stat_trac_technical/features/work_orders/domain/work_order_summary.dart';
import 'package:stat_trac_technical/features/work_orders/presentation/providers/work_order_providers.dart';
import 'package:stat_trac_technical/sync/upload/upload_providers.dart';
import 'package:stat_trac_technical/sync/upload/upload_queue.dart';
import 'package:stat_trac_technical/sync/upload/work_order_upload.dart';

class _Source extends Mock implements PowerSyncWorkOrderDataSource {}

class _SignedIn extends AuthNotifier {
  @override
  AuthState build() => const AuthAuthenticated(User(
    id: 31, name: 'Athi', email: '', role: UserRole.technician,
    technicianCode: '',
  ));
}

void main() {
  sqfliteFfiInit();

  late Database db;
  late UploadQueue queue;
  late _Source source;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await UploadQueue.createTable(db);
    queue = UploadQueue(db);
    source = _Source();
    when(() => source.assetsByIds(any())).thenAnswer((_) async => const {});
  });

  tearDown(() async => db.close());

  ProviderContainer container() {
    final c = ProviderContainer(overrides: [
      authProvider.overrideWith(_SignedIn.new),
      uploadQueueProvider.overrideWith((ref) async => queue),
      workOrderSourceProvider.overrideWith((ref) async => source),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('queued and synced together, the technician\'s own', () async {
    await queue.enqueue(WorkOrderUpload(
      mobileId: 'wo-9',
      capture: const {'asset_id': 100, 'work_type': 1, 'date_in': '2026-10-01',
          'time_in': '08:00'},
      techPng: 'A', clientPng: 'B', clientName: 'X',
    ));
    when(() => source.capturedBy(31)).thenAnswer((_) async =>
        const SyncedWorklist([
          WorkOrderSummary(trackId: 1, mobileId: 'wo-1', status: 'WO Completed'),
        ], complete: true));

    final list = await container().read(worklistProvider.future);

    expect([for (final w in list.items) w.mobileId], ['wo-9', 'wo-1']);
    expect(list.items.first.queueState, WorkOrderQueueState.waiting);
    expect(list.syncedComplete, isTrue);
  });

  test('a set-aside job carries the server\'s message', () async {
    await queue.enqueue(WorkOrderUpload(
      mobileId: 'wo-9',
      capture: const {'asset_id': 100, 'work_type': 1},
      techPng: 'A', clientPng: 'B', clientName: 'X',
    ));
    await queue.markRejected('wo-9', reason: 'open_work_order',
        message: 'Work order 1801 is still open on this machine');
    when(() => source.capturedBy(31)).thenAnswer(
        (_) async => const SyncedWorklist([], complete: true));

    final w = (await container().read(worklistProvider.future)).items.single;

    expect(w.queueState, WorkOrderQueueState.setAside);
    expect(w.message, 'Work order 1801 is still open on this machine');
  });

  test('certificates in the queue are not work orders', () async {
    when(() => source.capturedBy(31)).thenAnswer(
        (_) async => const SyncedWorklist([], complete: false));

    final list = await container().read(worklistProvider.future);

    expect(list.items, isEmpty);
    expect(list.syncedComplete, isFalse);
  });
}
```

Add `setUpAll(() => registerFallbackValue(<int>{}));` at the top of `main()` for `any()` on the `Set<int>`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/work_orders/worklist_provider_test.dart`
Expected: FAIL — providers do not exist.

- [ ] **Step 3: Add `UploadArchive.latestFor`**

In `upload_archive.dart`:

```dart
  /// The last archived payload sent under [mobileId], if it is still kept.
  Future<QueuedUpload?> latestFor(String mobileId) async {
    final rows = await _db.query(
      table,
      columns: ['payload'],
      where: 'mobile_id = ?',
      whereArgs: [mobileId],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return fromQueuedJson(
      jsonDecode(rows.first['payload']! as String) as Map<String, Object?>,
    );
  }
```

- [ ] **Step 4: Implement the providers**

`lib/features/work_orders/presentation/providers/work_order_providers.dart`:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../sync/powersync_providers.dart';
import '../../../../sync/upload/upload_providers.dart';
import '../../../../sync/upload/upload_queue.dart';
import '../../../../sync/upload/work_order_upload.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/auth_state.dart';
import '../../data/powersync_work_order_data_source.dart';
import '../../domain/work_order_job.dart';
import '../../domain/work_order_record.dart';
import '../../domain/work_order_summary.dart';

part 'work_order_providers.g.dart';

@riverpod
Future<PowerSyncWorkOrderDataSource> workOrderSource(Ref ref) async =>
    PowerSyncWorkOrderDataSource.of(await ref.watch(syncDatabaseProvider.future));

class Worklist {
  const Worklist(this.items, {required this.syncedComplete});

  final List<WorkOrderSummary> items;

  /// False when the synced part could not be read — the screen says so.
  final bool syncedComplete;
}

/// The signed-in technician's captured work orders: still on the phone first,
/// then synced.
@riverpod
Future<Worklist> worklist(Ref ref) async {
  final auth = ref.watch(authProvider);
  if (auth is! AuthAuthenticated) return const Worklist([], syncedComplete: true);

  final queueFuture = ref.watch(uploadQueueProvider.future);
  final source = await ref.watch(workOrderSourceProvider.future);
  final queue = await queueFuture;

  final entries = [
    for (final e in await queue.all())
      if (e.upload is WorkOrderUpload) e,
  ];
  final jobs = [
    for (final e in entries)
      WorkOrderJob.fromWire((e.upload as WorkOrderUpload).capture),
  ];
  final assets = await source.assetsByIds({for (final j in jobs) j.assetId});

  final queued = [
    for (var i = 0; i < entries.length; i++)
      WorkOrderSummary(
        mobileId: entries[i].upload.mobileId,
        dateIn: jobs[i].started,
        assetId: jobs[i].assetId,
        asset: assets[jobs[i].assetId],
        workType: jobs[i].workType,
        status: entries[i].status == UploadStatus.pending
            ? 'Waiting to sync'
            : 'Set aside',
        queueState: entries[i].status == UploadStatus.pending
            ? WorkOrderQueueState.waiting
            : WorkOrderQueueState.setAside,
        message: entries[i].lastError,
      ),
  ];

  final synced = await source.capturedBy(auth.user.id);
  return Worklist(
    mergeWorklist(queued: queued, synced: synced.items),
    syncedComplete: synced.complete,
  );
}

@riverpod
Future<int?> openRepairOnAsset(Ref ref, int assetId) async =>
    (await ref.watch(workOrderSourceProvider.future)).openRepairOn(assetId);

@riverpod
Future<WorkOrderRecord?> workOrderRecord(Ref ref, int trackId) async =>
    (await ref.watch(workOrderSourceProvider.future)).record(trackId);

@riverpod
Future<UploadQueueEntry?> queuedWorkOrder(Ref ref, String mobileId) async {
  final queue = await ref.watch(uploadQueueProvider.future);
  for (final e in await queue.all()) {
    if (e.upload is WorkOrderUpload && e.upload.mobileId == mobileId) return e;
  }
  return null;
}

/// The signatures this phone captured for a job — from the queue while it
/// waits, from the archive after it went. Null when this phone never had them
/// (signed elsewhere) or the archive has rolled past it.
@riverpod
Future<WorkOrderUpload?> phoneSignatures(Ref ref, String mobileId) async {
  final queued = await ref.watch(queuedWorkOrderProvider(mobileId).future);
  if (queued?.upload case final WorkOrderUpload w) return w;
  final archive = await ref.watch(uploadArchiveProvider.future);
  final sent = await archive.latestFor(mobileId);
  return sent is WorkOrderUpload ? sent : null;
}
```

- [ ] **Step 5: Generate and run**

Run:
```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/features/work_orders/
flutter analyze
```
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/work_orders lib/sync/upload/upload_archive.dart test/features/work_orders
git commit -m "feat(work-orders): worklist, record and signature providers"
```

---

### Task 10: Create Work Order — machine, job card, signatures

**Files:**
- Modify: `lib/features/certification/presentation/widgets/cert_signature_step.dart`, `signature_step_validation.dart`
- Create: `lib/features/work_orders/presentation/widgets/work_order_form.dart`, `lib/features/work_orders/presentation/screens/create_work_order_screen.dart`
- Test: `test/features/work_orders/work_order_form_test.dart`, `test/features/work_orders/create_work_order_screen_test.dart`

**Interfaces:**
- Consumes: `WorkOrderJob`, `WorkType` (Task 3); `WorkOrderUpload` (Task 4); `openRepairOnAssetProvider`, `workOrderSourceProvider`, `worklistProvider` (Task 9); `uploadQueueProvider`, `uploadWorkerProvider`; `showAssetPicker(context, PowerSyncAssetDataSource)`; `PowerSyncAssetDataSource(PowerSyncDatabase)` with `getAssetDetail(int)` → `AssetDetail?` having `hours`.
- Produces:
  - `CertSignatureStep({..., String submitLabel = 'Issue Certificate', String clientLabel = 'Facility', String? initialClientName})`
  - `signatureStepError({..., String clientLabel = 'Facility'})`
  - `WorkOrderForm({required WorkOrderJob job, required ValueChanged<WorkOrderJob> onChanged, required String technicianName, WorkOrderFieldError? serverError})`
  - `CreateWorkOrderScreen({WorkOrderUpload? resend, String? resendField, String? resendMessage})`

- [ ] **Step 1: Let the signature step speak about a client**

In `signature_step_validation.dart` add `String clientLabel = 'Facility',` to the parameters and use it: `'$clientLabel signature is required'` and `'Add the ${clientLabel.toLowerCase()} contact name before saving — the signature cannot be sent without it'`.

In `cert_signature_step.dart`:
- constructor gains `this.submitLabel = 'Issue Certificate', this.clientLabel = 'Facility', this.initialClientName,` with fields `final String submitLabel; final String clientLabel; final String? initialClientName;`
- in the state add:

```dart
  @override
  void initState() {
    super.initState();
    _clientNameController.text = widget.initialClientName ?? '';
  }
```

- pass `clientLabel: widget.clientLabel` to `signatureStepError`;
- `label: Text(widget.submitLabel)`;
- `'${widget.clientLabel} Contact'`, `labelText: '${widget.clientLabel} Contact Name'`, `hintText: 'Required when the ${widget.clientLabel.toLowerCase()} signs'`, `title: '${widget.clientLabel} Signature'`.

Run `flutter test test/features/certification/` — Expected: PASS unchanged (defaults keep the certificate wording).

- [ ] **Step 2: Write the failing form test**

`test/features/work_orders/work_order_form_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/core/theme/app_theme.dart';
import 'package:stat_trac_technical/features/work_orders/domain/work_order_job.dart';
import 'package:stat_trac_technical/features/work_orders/presentation/widgets/work_order_form.dart';

void main() {
  Future<List<WorkOrderJob>> pump(WidgetTester tester, {
    WorkOrderFieldError? serverError,
  }) async {
    tester.view.physicalSize = const Size(1080, 2316);
    tester.view.devicePixelRatio = 1080 / 384;
    addTearDown(tester.view.reset);
    final changes = <WorkOrderJob>[];
    await tester.pumpWidget(MaterialApp(
      theme: appTheme,
      home: Scaffold(
        body: WorkOrderForm(
          job: WorkOrderJob(
            assetId: 100,
            started: DateTime(2026, 10, 1, 8),
            finished: DateTime(2026, 10, 1, 10),
          ),
          technicianName: 'Athi',
          serverError: serverError,
          onChanged: changes.add,
        ),
      ),
    ));
    return changes;
  }

  testWidgets('PM is not a choice and nothing is chosen', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('wo-work-type')));
    await tester.pumpAndSettle();
    expect(find.text('PM Service'), findsNothing);
    expect(find.text('Installation'), findsWidgets);
  });

  testWidgets('the technician is shown and cannot be edited', (tester) async {
    await pump(tester);
    expect(find.text('Athi'), findsOneWidget);
    expect(
      find.ancestor(of: find.text('Athi'), matching: find.byType(TextField)),
      findsNothing,
    );
  });

  testWidgets('typing a fault reports a new job', (tester) async {
    final changes = await pump(tester);
    await tester.enterText(find.byKey(const Key('wo-fault')), 'Beeps');
    expect(changes.last.fault, 'Beeps');
  });

  testWidgets('a server refusal shows under its box', (tester) async {
    await pump(tester,
        serverError: const WorkOrderFieldError('jobfault', 'Too long'));
    expect(find.text('Too long'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/work_orders/work_order_form_test.dart`
Expected: FAIL — `work_order_form.dart` does not exist.

- [ ] **Step 4: Implement the form**

`lib/features/work_orders/presentation/widgets/work_order_form.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../domain/work_order_job.dart';
import '../../domain/work_type.dart';

/// Step 2 — the desktop's Work Order tab, the fields agreed 2026-10-01.
///
/// Every edit reports a whole new [WorkOrderJob]; the screen owns the value
/// and decides when it is valid. The technician is shown and never editable:
/// the server writes the person it authenticated.
class WorkOrderForm extends StatefulWidget {
  const WorkOrderForm({
    super.key,
    required this.job,
    required this.onChanged,
    required this.technicianName,
    this.serverError,
  });

  final WorkOrderJob job;
  final ValueChanged<WorkOrderJob> onChanged;
  final String technicianName;

  /// The server's refusal, shown under the box it names.
  final WorkOrderFieldError? serverError;

  @override
  State<WorkOrderForm> createState() => _WorkOrderFormState();
}

class _WorkOrderFormState extends State<WorkOrderForm> {
  late final _equipHrs = TextEditingController(text: _num(widget.job.equipHrs));
  late final _nop = TextEditingController(text: _num(widget.job.nop));
  late final _fault = TextEditingController(text: widget.job.fault);
  late final _work = TextEditingController(text: widget.job.work);
  late final _note = TextEditingController(text: widget.job.note);
  late final _client = TextEditingController(text: widget.job.clientName);
  late final _jobCard = TextEditingController(text: widget.job.jobCardNo);

  static String _num(int? n) => n == null ? '' : '$n';

  @override
  void dispose() {
    for (final c in [_equipHrs, _nop, _fault, _work, _note, _client, _jobCard]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Built fresh from the boxes rather than copied, so a cleared number box
  /// becomes null rather than keeping its old value.
  void _emit({WorkType? workType, DateTime? started, DateTime? finished}) {
    final j = widget.job;
    widget.onChanged(WorkOrderJob(
      assetId: j.assetId,
      workType: workType ?? j.workType,
      started: started ?? j.started,
      finished: finished ?? j.finished,
      equipHrs: int.tryParse(_equipHrs.text),
      nop: int.tryParse(_nop.text),
      fault: _fault.text,
      work: _work.text,
      note: _note.text,
      clientName: _client.text,
      jobCardNo: _jobCard.text,
    ));
  }

  String? _errorFor(String field) {
    final e = widget.serverError ?? widget.job.validate();
    return e != null && e.field == field ? e.message : null;
  }

  Future<DateTime?> _pick(DateTime? current) async {
    final base = current ?? DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(base.year - 1),
      lastDate: DateTime(base.year + 1),
    );
    if (day == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return null;
    return DateTime(day.year, day.month, day.day, time.hour, time.minute);
  }

  Widget _when(String label, String field, DateTime? value,
      ValueChanged<DateTime> set) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, errorText: _errorFor(field)),
      child: InkWell(
        onTap: () async {
          final picked = await _pick(value);
          if (picked != null) set(picked);
        },
        child: Text(
          value == null ? 'Choose' : DateFormat('dd MMM yyyy  HH:mm').format(value),
        ),
      ),
    );
  }

  Widget _text(String key, String label, TextEditingController c, String field,
      {int? max, int lines = 1, bool digits = false}) {
    return TextField(
      key: Key(key),
      controller: c,
      maxLength: max,
      minLines: lines,
      maxLines: lines == 1 ? 1 : lines + 2,
      keyboardType: digits ? TextInputType.number : TextInputType.text,
      inputFormatters: digits ? [FilteringTextInputFormatter.digitsOnly] : null,
      textCapitalization:
          digits ? TextCapitalization.none : TextCapitalization.sentences,
      decoration: InputDecoration(labelText: label, errorText: _errorFor(field)),
      onChanged: (_) => _emit(),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<WorkType>(
          key: const Key('wo-work-type'),
          initialValue: widget.job.workType,
          decoration: InputDecoration(
            labelText: 'Type of work',
            errorText: _errorFor('jobworktype'),
          ),
          items: [
            for (final w in WorkType.values)
              DropdownMenuItem(value: w, child: Text(w.label)),
          ],
          onChanged: (w) => _emit(workType: w),
        ),
        gap,
        _when('Date in / time in', 'datein', widget.job.started,
            (d) => _emit(started: d)),
        gap,
        _when('Date completed / time out', 'dateout', widget.job.finished,
            (d) => _emit(finished: d)),
        gap,
        InputDecorator(
          decoration: const InputDecoration(labelText: 'Technician'),
          child: Text(widget.technicianName),
        ),
        gap,
        _text('wo-hours', 'Equipment hours', _equipHrs, 'equiphrs',
            digits: true),
        gap,
        _text('wo-nop', 'N.O.P', _nop, 'nop', digits: true),
        gap,
        _text('wo-fault', 'Fault', _fault, 'jobfault',
            max: WorkOrderJob.maxFault, lines: 2),
        _text('wo-work', 'Work done', _work, 'jobwork',
            max: WorkOrderJob.maxWork, lines: 3),
        _text('wo-note', 'Notes', _note, 'jobnote',
            max: WorkOrderJob.maxNote, lines: 2),
        _text('wo-client', 'Client name', _client, 'client',
            max: WorkOrderJob.maxClient),
        _text('wo-jobcard', 'Job card no', _jobCard, 'jobcardno',
            max: WorkOrderJob.maxJobCardNo),
      ],
    );
  }
}
```

If `DropdownButtonFormField` in the installed Flutter does not accept `initialValue`, use `value:` instead (check `flutter --version`; `initialValue` replaced `value` in Flutter 3.33).

- [ ] **Step 5: Run the form test**

Run: `flutter test test/features/work_orders/work_order_form_test.dart`
Expected: PASS.

- [ ] **Step 6: Write the failing screen test**

`test/features/work_orders/create_work_order_screen_test.dart` — exercises the resend path, which needs no asset picker or signature drawing:

```dart
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
        home: CreateWorkOrderScreen(resend: original,
            resendField: 'jobfault', resendMessage: 'Add the fault'),
      ),
    ));
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
```

- [ ] **Step 7: Run test to verify it fails**

Run: `flutter test test/features/work_orders/create_work_order_screen_test.dart`
Expected: FAIL — screen does not exist.

- [ ] **Step 8: Implement the screen**

`lib/features/work_orders/presentation/screens/create_work_order_screen.dart`:

```dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../sync/powersync_providers.dart';
import '../../../../sync/upload/upload_providers.dart';
import '../../../../sync/upload/work_order_upload.dart';
import '../../../assets/data/powersync_asset_data_source.dart';
import '../../../assets/domain/entities/asset.dart';
import '../../../assets/presentation/widgets/asset_picker_dialog.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/auth_state.dart';
import '../../../certification/presentation/widgets/cert_signature_step.dart';
import '../../domain/work_order_job.dart';
import '../providers/work_order_providers.dart';
import '../widgets/work_order_form.dart';

/// Capture on site, in three steps: the machine, the Work Order tab, both
/// signatures. Nothing is written until Save, and Save writes only to the
/// outbox — the server raises and completes the work order when it arrives.
///
/// With [resend] it reopens a job the server set aside: same mobile id, same
/// machine, same signatures, starting at the form with the server's complaint
/// under the box it named.
class CreateWorkOrderScreen extends ConsumerStatefulWidget {
  const CreateWorkOrderScreen({
    super.key,
    this.resend,
    this.resendField,
    this.resendMessage,
  });

  final WorkOrderUpload? resend;
  final String? resendField;
  final String? resendMessage;

  @override
  ConsumerState<CreateWorkOrderScreen> createState() =>
      _CreateWorkOrderScreenState();
}

class _CreateWorkOrderScreenState extends ConsumerState<CreateWorkOrderScreen> {
  late final String _mobileId = widget.resend?.mobileId ?? const Uuid().v4();
  int _step = 0;
  Asset? _asset;
  WorkOrderJob? _job;
  WorkOrderFieldError? _serverError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final resend = widget.resend;
    if (resend != null) {
      _job = WorkOrderJob.fromWire(resend.capture);
      _step = 1;
      if (widget.resendField != null && widget.resendMessage != null) {
        _serverError =
            WorkOrderFieldError(widget.resendField!, widget.resendMessage!);
      }
    }
  }

  String get _techName {
    final auth = ref.read(authProvider);
    return auth is AuthAuthenticated ? auth.user.name : '';
  }

  Future<void> _pickMachine() async {
    final ds = PowerSyncAssetDataSource(
      await ref.read(syncDatabaseProvider.future),
    );
    if (!mounted) return;
    final asset = await showAssetPicker(context, ds);
    if (asset == null || asset.assetId == null) return;
    final detail = await ds.getAssetDetail(asset.assetId!);
    final now = DateTime.now();
    setState(() {
      _asset = asset;
      _job = WorkOrderJob(
        assetId: asset.assetId!,
        started: now,
        finished: now,
        equipHrs: detail?.hours,
      );
    });
  }

  Future<void> _save({required String techPng, required String clientPng,
      required String clientName}) async {
    final job = _job!;
    if (_saving) return;
    setState(() => _saving = true);
    final upload = WorkOrderUpload(
      mobileId: _mobileId,
      // The name signed against is the name on the card.
      capture: job.copyWith(clientName: clientName).toWire(),
      techPng: techPng,
      clientPng: clientPng,
      clientName: clientName,
    );
    final queue = await ref.read(uploadQueueProvider.future);
    // Replaces a set-aside row under the same id rather than adding one.
    await queue.enqueue(upload);
    ref.invalidate(worklistProvider);
    try {
      await (await ref.read(uploadWorkerProvider.future)).drain();
    } catch (e) {
      debugPrint('[upload] send after work order save failed: $e');
    }
    ref.invalidate(worklistProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved — waiting to sync')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.resend == null ? 'New Work Order' : 'Fix and resend'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                'Step ${_step + 1} of 3 — '
                '${const ['Machine', 'Work order', 'Signatures'][_step]}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Expanded(child: switch (_step) {
              0 => _machineStep(),
              1 => _formStep(),
              _ => _signStep(),
            }),
          ],
        ),
      ),
    );
  }

  Widget _machineStep() {
    final asset = _asset;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        OutlinedButton.icon(
          onPressed: _pickMachine,
          icon: const Icon(Icons.precision_manufacturing_outlined),
          label: Text(asset == null ? 'Choose machine' : 'Change machine'),
        ),
        if (asset != null) ...[
          const SizedBox(height: 12),
          Text(asset.displayName, style: Theme.of(context).textTheme.titleMedium),
          Text([asset.serialNumber, asset.hospital].whereType<String>().join(' · ')),
          const SizedBox(height: 12),
          _OpenRepairWarning(assetId: asset.assetId!),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => setState(() => _step = 1),
            child: const Text('Next'),
          ),
        ],
      ],
    );
  }

  Widget _formStep() {
    final job = _job!;
    final valid = job.validate() == null;
    return Column(
      children: [
        Expanded(
          child: WorkOrderForm(
            job: job,
            technicianName: _techName,
            serverError: _serverError,
            onChanged: (j) => setState(() {
              _job = j;
              // The server's complaint stands until the box it named changes.
              if (_serverError != null &&
                  _changed(_serverError!.field, job, j)) {
                _serverError = null;
              }
            }),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: valid ? () => setState(() => _step = 2) : null,
            child: const Text('Next'),
          ),
        ),
      ],
    );
  }

  Widget _signStep() {
    final resend = widget.resend;
    if (resend != null) {
      // A set-aside job was signed when it was captured. The client may be long
      // gone; the signatures stand.
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.verified_outlined, color: brandTeal),
              title: const Text('Signatures kept'),
              subtitle: Text('Signed by the technician and ${resend.clientName}'),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving
                ? null
                : () => _save(
                    techPng: resend.techPng,
                    clientPng: resend.clientPng,
                    clientName: resend.clientName,
                  ),
            child: const Text('Save work order'),
          ),
        ],
      );
    }
    return CertSignatureStep(
      requiresCustomerSig: true,
      clientLabel: 'Client',
      submitLabel: 'Save work order',
      initialClientName: _job!.clientName,
      onSigned: (s) => _save(
        techPng: base64Encode(s.techSignatureBytes),
        clientPng: base64Encode(s.clientSignatureBytes!),
        clientName: s.clientName!,
      ),
    );
  }

  static bool _changed(String field, WorkOrderJob a, WorkOrderJob b) =>
      switch (field) {
        'jobworktype' => a.workType != b.workType,
        'datein' || 'timein' => a.started != b.started,
        'dateout' || 'timeout' => a.finished != b.finished,
        'equiphrs' => a.equipHrs != b.equipHrs,
        'jobfault' => a.fault != b.fault,
        'jobwork' => a.work != b.work,
        'jobnote' => a.note != b.note,
        'client' => a.clientName != b.clientName,
        'jobcardno' => a.jobCardNo != b.jobCardNo,
        _ => true,
      };
}

/// Amber, and a warning only: the phone's copy is as old as its last sync.
class _OpenRepairWarning extends ConsumerWidget {
  const _OpenRepairWarning({required this.assetId});
  final int assetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(openRepairOnAssetProvider(assetId)).value;
    if (open == null) return const SizedBox.shrink();
    return Card(
      color: const Color(0xFFFFF8E1),
      child: ListTile(
        leading: const Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100)),
        title: Text('Work order $open is still open on this machine '
            '(as of last sync).'),
        subtitle: const Text('The server will refuse a second one.'),
      ),
    );
  }
}
```

The resend test starts at step 1 with `_asset == null` — `_formStep` does not read `_asset`, so this is fine. If `CertSignatureStep`'s `onSigned` gives `clientSignatureBytes == null`, its own validation (requiresCustomerSig) has already refused, so the `!` is safe.

- [ ] **Step 9: Run the tests**

Run: `flutter test test/features/work_orders/ test/features/certification/` then `flutter analyze`
Expected: PASS.

- [ ] **Step 10: Commit**

```bash
git add lib/features/work_orders lib/features/certification/presentation/widgets test/features/work_orders
git commit -m "feat(work-orders): capture on site — machine, job card, both signatures, queued"
```

---

### Task 11: Worklist and detail

**Files:**
- Create: `lib/features/work_orders/presentation/screens/work_order_list_screen.dart`, `lib/features/work_orders/presentation/screens/work_order_detail_screen.dart`
- Test: `test/features/work_orders/work_order_list_screen_test.dart`

**Interfaces:**
- Consumes: `worklistProvider`, `workOrderRecordProvider`, `queuedWorkOrderProvider`, `phoneSignaturesProvider` (Task 9); `CreateWorkOrderScreen(resend:, resendField:, resendMessage:)` (Task 10); `UploadQueue.discard` (Task 5).
- Produces: `WorkOrderListScreen()`, `WorkOrderDetailScreen({int? trackId, String? mobileId})`.

- [ ] **Step 1: Write the failing test**

`test/features/work_orders/work_order_list_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/core/theme/app_theme.dart';
import 'package:stat_trac_technical/features/work_orders/domain/work_order_summary.dart';
import 'package:stat_trac_technical/features/work_orders/presentation/providers/work_order_providers.dart';
import 'package:stat_trac_technical/features/work_orders/presentation/screens/work_order_list_screen.dart';

void main() {
  Future<void> pump(WidgetTester tester, Worklist list) async {
    tester.view.physicalSize = const Size(1080, 2316);
    tester.view.devicePixelRatio = 1080 / 384;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [worklistProvider.overrideWith((ref) async => list)],
      child: MaterialApp(theme: appTheme, home: const WorkOrderListScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('a pending job has no number yet', (tester) async {
    await pump(tester, const Worklist([
      WorkOrderSummary(mobileId: 'wo-9', status: 'Waiting to sync',
          queueState: WorkOrderQueueState.waiting),
      WorkOrderSummary(trackId: 1801, mobileId: 'wo-1', status: 'WO Completed'),
    ], syncedComplete: true));

    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('WO 1801'), findsOneWidget);
    expect(find.text('Waiting to sync'), findsOneWidget);
  });

  testWidgets('cards unreadable: says so instead of spinning', (tester) async {
    await pump(tester, const Worklist([], syncedComplete: false));
    expect(find.text('Synced work orders still loading — pull to retry'),
        findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('nothing at all', (tester) async {
    await pump(tester, const Worklist([], syncedComplete: true));
    expect(find.text('No work orders yet'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/work_orders/work_order_list_screen_test.dart`
Expected: FAIL — screen does not exist.

- [ ] **Step 3: Implement the list**

`lib/features/work_orders/presentation/screens/work_order_list_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/work_order_summary.dart';
import '../providers/work_order_providers.dart';
import 'work_order_detail_screen.dart';

/// The signed-in technician's captured work orders.
class WorkOrderListScreen extends ConsumerWidget {
  const WorkOrderListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(worklistProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Worklist')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(worklistProvider.future),
        child: list.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: const [
            Padding(
              padding: EdgeInsets.all(24),
              child: Text('Work orders could not be read — pull to retry'),
            ),
          ]),
          data: (w) => ListView(
            children: [
              if (!w.syncedComplete)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Synced work orders still loading — pull to retry'),
                ),
              if (w.items.isEmpty && w.syncedComplete)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No work orders yet')),
                ),
              for (final item in w.items) _Row(item: item),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item});
  final WorkOrderSummary item;

  @override
  Widget build(BuildContext context) {
    final asset = item.asset;
    final setAside = item.queueState == WorkOrderQueueState.setAside;
    final colour = switch (item.queueState) {
      WorkOrderQueueState.waiting => const Color(0xFFE65100),
      WorkOrderQueueState.setAside => brandError,
      null => const Color(0xFF2E7D32),
    };
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text(item.trackId == null ? 'Pending' : 'WO ${item.trackId}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text([
              if (item.dateIn != null) DateFormat('dd MMM yyyy').format(item.dateIn!),
              ?item.workType?.label,
            ].join(' · ')),
            if (asset != null)
              Text([asset.equipment, asset.serial, asset.hospital]
                  .whereType<String>()
                  .join(' · ')),
            if (setAside && item.message != null)
              Text(item.message!, style: const TextStyle(color: brandError)),
          ],
        ),
        trailing: Text(item.status, style: TextStyle(color: colour)),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => WorkOrderDetailScreen(
            trackId: item.trackId,
            mobileId: item.mobileId,
          ),
        )),
      ),
    );
  }
}
```

- [ ] **Step 4: Implement the detail screen**

`lib/features/work_orders/presentation/screens/work_order_detail_screen.dart`:

```dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../sync/upload/upload_providers.dart';
import '../../../../sync/upload/upload_queue.dart';
import '../../../../sync/upload/work_order_upload.dart';
import '../../domain/work_order_job.dart';
import '../providers/work_order_providers.dart';
import 'create_work_order_screen.dart';

/// One work order, read-only. A synced one by [trackId]; one still on the
/// phone by [mobileId].
class WorkOrderDetailScreen extends ConsumerWidget {
  const WorkOrderDetailScreen({super.key, this.trackId, this.mobileId});

  final int? trackId;
  final String? mobileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = trackId;
    return Scaffold(
      appBar: AppBar(title: Text(id == null ? 'Work order — pending' : 'WO $id')),
      body: id != null ? _Synced(trackId: id, mobileId: mobileId)
          : _Queued(mobileId: mobileId!),
    );
  }
}

class _Synced extends ConsumerWidget {
  const _Synced({required this.trackId, this.mobileId});
  final int trackId;
  final String? mobileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(workOrderRecordProvider(trackId)).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(child: Text('Could not read this work order')),
      data: (r) => r == null
          ? const Center(child: Text('Not on this phone yet'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Field('Status', r.status),
                _Field('Type of work', r.workType?.label ?? ''),
                _Field('Date in', _at(r.started)),
                _Field('Date completed', _at(r.finished)),
                _Field('Technician', r.tech),
                _Field('Equipment hours', r.equipHrs?.toString() ?? ''),
                _Field('N.O.P', r.nop?.toString() ?? ''),
                _Field('Fault', r.fault),
                _Field('Work done', r.work),
                _Field('Notes', r.note),
                _Field('Client name', r.clientName),
                _Field('Job card no', r.jobCardNo),
                const SizedBox(height: 16),
                _Signatures(mobileId: r.mobileId ?? mobileId),
              ],
            ),
    );
  }
}

class _Queued extends ConsumerWidget {
  const _Queued({required this.mobileId});
  final String mobileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(queuedWorkOrderProvider(mobileId)).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(child: Text('Could not read this job')),
      data: (entry) {
        if (entry == null) {
          return const Center(child: Text('Sent — it will appear once synced'));
        }
        final upload = entry.upload as WorkOrderUpload;
        final job = WorkOrderJob.fromWire(upload.capture);
        final setAside = entry.status != UploadStatus.pending;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (setAside)
              Card(
                color: const Color(0xFFFFEBEE),
                child: ListTile(
                  leading: const Icon(Icons.block, color: brandError),
                  title: const Text('Set aside by the server'),
                  subtitle: Text(entry.lastError ?? ''),
                ),
              )
            else
              _Field('Status', entry.lastError ?? 'Waiting to sync'),
            _Field('Type of work', job.workType?.label ?? ''),
            _Field('Date in', _at(job.started)),
            _Field('Date completed', _at(job.finished)),
            _Field('Equipment hours', job.equipHrs?.toString() ?? ''),
            _Field('N.O.P', job.nop?.toString() ?? ''),
            _Field('Fault', job.fault),
            _Field('Work done', job.work),
            _Field('Notes', job.note),
            _Field('Client name', job.clientName),
            _Field('Job card no', job.jobCardNo),
            const SizedBox(height: 16),
            _Signatures(mobileId: mobileId),
            if (setAside) ...[
              const SizedBox(height: 24),
              if (entry.reason == 'invalid') ...[
                FilledButton(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => CreateWorkOrderScreen(
                        resend: upload,
                        resendField: entry.field,
                        resendMessage: entry.lastError,
                      ),
                    ),
                  ),
                  child: const Text('Fix and resend'),
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton(
                onPressed: () => _discard(context, ref),
                child: const Text('Discard'),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _discard(BuildContext context, WidgetRef ref) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Discard this work order?'),
        content: const Text('It never reached the server. Discarding deletes '
            'it from this phone for good.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false),
              child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(c, true),
              child: const Text('Discard')),
        ],
      ),
    );
    if (sure != true) return;
    await (await ref.read(uploadQueueProvider.future)).discard(mobileId);
    ref.invalidate(worklistProvider);
    if (context.mounted) Navigator.of(context).pop();
  }
}

/// Signatures are shown only when this phone holds them. `bytea` does not
/// come down through sync, so anything signed elsewhere cannot be drawn here.
class _Signatures extends ConsumerWidget {
  const _Signatures({required this.mobileId});
  final String? mobileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = mobileId;
    final held = id == null ? null : ref.watch(phoneSignaturesProvider(id)).value;
    if (held == null) {
      return const Text('Signed on another device or at the office');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Technician', style: Theme.of(context).textTheme.titleSmall),
        Image.memory(base64Decode(held.techPng), height: 100),
        const SizedBox(height: 12),
        Text('Client — ${held.clientName}',
            style: Theme.of(context).textTheme.titleSmall),
        Image.memory(base64Decode(held.clientPng), height: 100),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value.isEmpty ? '—' : value,
            style: Theme.of(context).textTheme.bodyLarge),
      ],
    ),
  );
}

String _at(DateTime? d) =>
    d == null ? '' : DateFormat('dd MMM yyyy  HH:mm').format(d);
```

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/work_orders/` then `flutter analyze`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/work_orders test/features/work_orders
git commit -m "feat(work-orders): worklist and detail, with fix-and-resend and discard"
```

---

### Task 12: Switch the tiles on; captured this month; notes

**Files:**
- Modify: `lib/features/dashboard/presentation/screens/dashboard_screen.dart`, `lib/features/dashboard/presentation/providers/dashboard_providers.dart`, `test/features/dashboard/dashboard_module_grid_test.dart`, `CLAUDE.md`
- Test: `test/features/dashboard/dashboard_module_grid_test.dart`

**Interfaces:**
- Consumes: `WorkOrderListScreen`, `CreateWorkOrderScreen` (Tasks 10–11); `PowerSyncWorkOrderDataSource.capturedBy` (Task 8).
- Changes: `DashboardStats` gains `capturedThisMonth` (`int`).

- [ ] **Step 1: Change the grid test first**

In `dashboard_module_grid_test.dart`, rename the first test to `'work order and certificate actions can be pressed; PM cannot'`, replace its comment with `// PM work orders belong to the PM module, which the phone does not do yet.`, and its expectations with:

```dart
    expect(pressable('View', 0), isTrue, reason: 'Worklist');
    expect(pressable('View', 1), isTrue, reason: 'Work Order');
    expect(pressable('View', 2), isFalse, reason: 'PM Work Order');
    expect(pressable('View', 3), isTrue, reason: 'Certificate');
    expect(pressable('Create', 0), isTrue, reason: 'Work Order');
    expect(pressable('Create', 1), isFalse, reason: 'PM Work Order');
    expect(pressable('Create', 2), isTrue, reason: 'Certificate');
    expect(find.text('Coming soon'), findsOneWidget);
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dashboard/dashboard_module_grid_test.dart`
Expected: FAIL — Worklist/Work Order still disabled.

- [ ] **Step 3: Switch them on**

In `dashboard_screen.dart`:
- add imports `../../../work_orders/presentation/screens/create_work_order_screen.dart` and `../../../work_orders/presentation/screens/work_order_list_screen.dart`;
- Worklist tile: delete `// Off until …` and `enabled: false,`; its View action gets `destination: (_) => const WorkOrderListScreen(),`
- Work Order tile: delete the two lines likewise; Create gets `destination: (_) => const CreateWorkOrderScreen(),`, View gets `destination: (_) => const WorkOrderListScreen(),`
- PM Work Order tile: change its comment to `// The PM module is not on the phone yet.` and keep `enabled: false`.

- [ ] **Step 4: Captured this month**

`dashboard_providers.dart` — `DashboardStats` gains `required this.capturedThisMonth` / `final int capturedThisMonth;`, and `dashboardStats` becomes:

```dart
@riverpod
Future<DashboardStats> dashboardStats(Ref ref) async {
  final auth = ref.watch(authProvider);
  final queue = UploadQueue(await DatabaseHelper.instance.database);

  var captured = 0;
  if (auth is AuthAuthenticated) {
    try {
      final source = PowerSyncWorkOrderDataSource.of(
        await ref.watch(syncDatabaseProvider.future),
      );
      final now = DateTime.now();
      final list = await source.capturedBy(auth.user.id);
      captured = list.items
          .where((w) => w.dateIn != null &&
              w.dateIn!.year == now.year && w.dateIn!.month == now.month)
          .length;
    } catch (e) {
      // A count is not worth a broken dashboard.
      debugPrint('[dashboard] captured this month unavailable: $e');
    }
  }

  return DashboardStats(
    pendingWorkOrders: await queue.workOrderCount(),
    pendingCerts: await queue.certificateCount(),
    capturedThisMonth: captured,
  );
}
```

with imports for `auth_providers.dart`, `auth_state.dart`, `../../../../sync/powersync_providers.dart`, `../../../work_orders/data/powersync_work_order_data_source.dart`, and `package:flutter/foundation.dart`. (A data class from the work-orders feature, not its provider — the providers rule stands.)

In `dashboard_screen.dart`, `_PendingTasksRow`'s middle card becomes `label: 'Captured this month', count: captured` (rename the `pmCount` parameter to `capturedCount`) and `_HomeBody` passes `capturedCount: s.capturedThisMonth` (and `0` in the loading/error branches).

- [ ] **Step 5: Regenerate and run everything**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```
Expected: analyze clean; all tests PASS.

- [ ] **Step 6: Update CLAUDE.md**

- In **What Has Been Built**, replace the whole "Work Orders — domain + data + list + detail + create screens" subsection and the "WO creation business rule" paragraph with:

```markdown
### Work Orders — capture on site (2026-10-01)
- **Capture only.** Book-in is desktop-only. The phone shows only the Work Order tab (job card) — no WO Request, no WO Progress.
- Create: machine → job card → both signatures (required) → `upload_queue` as a `WorkOrderUpload` (`lib/sync/upload/work_order_upload.dart`): one batch, `capture` + `sign` tech + `sign` client on `Repair`.
- Sent only when the server's `enforces` lists `capture_action` and `job_sign_action`; otherwise it waits as "server not ready". Go side: `docs/go-requirements-work-order-capture.md`.
- Worklist: the technician's captured work orders (`RepairTechID`, `RepairDetailType = 3`) from PowerSync, no joins, plus jobs still queued. Set-aside jobs are never deleted except by Discard.
- Spec: `docs/superpowers/specs/2026-10-01-work-orders-capture-design.md`.
```

- In **Database**, set "Current DB version: 19" and add the table row `| 019 → v19 | 19 | DROP work_orders, work_order_status_history, work_order_photos, work_order_signatures; upload_queue + field TEXT |`.
- In **Dashboard**, replace the donut / KPI bullets with: `Top row: Pending Work Orders (queued), Captured this month, Certs to Sync. Donut and KPI tiles removed 2026-10-01.`
- Remove the **Known TODOs → Work orders** bullets (they describe the deleted code).

- [ ] **Step 7: Commit**

```bash
git add lib test CLAUDE.md
git commit -m "feat(dashboard): work order tiles on; captured this month"
```

---

## After the plan

Hand over for the phone check (the user does it, on `demo` as Athi, once the Go session has deployed `capture_action` / `job_sign_action`):

1. Capture with signal → a WO number, in the Worklist, on the desktop as captured, completed, both signatures.
2. Capture with data off → *Waiting to sync* → sends itself on signal.
3. Capture on a machine with a booked-in WO open → the warning, then set aside with the server's reason.

Before Go is deployed, a capture shows *"Waiting — the server is not ready for work orders yet."* — that is correct, not a bug.
