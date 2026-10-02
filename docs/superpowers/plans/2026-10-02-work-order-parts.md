# Work Order Parts Used Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A technician capturing a work order records the parts used: picked from the synced register or typed, with a quantity, no prices. The parts go up with the capture and show on the detail screen.

**Architecture:** `WorkOrderJob` gains `parts` (domain + wire). The job card form gets a "Parts used" section with a picker sheet over the PowerSync `Part` table. The outbox gate holds a job that carries parts until the server's `enforces` lists `capture_parts`. The detail screen lists parts from the queued payload or from synced `RepairPart`.

**Tech Stack:** Flutter, Riverpod 3 (`@riverpod` codegen), PowerSync (SQLite views), sqflite_common_ffi for tests, flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-01-work-order-parts-design.md` · Go side (live on `demo`): `docs/go-requirements-work-order-parts.md`, Go code `E:/Stat_Trac_Go/internal/stats/syncupload_repair.go` (`syncCapturePart`, `applyCapturePart`).

## Global Constraints

- **No prices anywhere on the phone.** No cost or total field is shown, stored or sent.
- Parts only from the register: `coalesce("PartType", 1) = 1`.
- A line needs a part id, or an item code or a description; `qty > 0`, decimals allowed. Code ≤ 50, description ≤ 100 characters (Go: `maxUsedPartNo = 50`, `maxUsedPartDesc = 100`).
- Wire field names exactly: `parts`, `part_id`, `part_no`, `description`, `qty`. A refusal names `parts[<index>].<name>`.
- `parts` absent from the wire when there are no lines.
- `lib/sync/powersync_schema.dart` is **copied verbatim** from `E:/Stat_Trac_Go/docs/flutter-sync-schema.dart`, never hand-edited.
- **Never join PowerSync tables.** Read each table on its own, with a timeout, degrading to the missing piece.
- Every `FilledButton` is full width: never inside a `Row`. A `SnackBar` from a bottom sheet hides behind it, so messages inside a sheet stay inside the sheet.
- Widget tests pump the real `appTheme` at 384 dp wide.
- Out of scope: prices, stock, Spares, the Inventory screen, editing parts after Save, barcode scanning of parts.
- All work lands on `master`.

## Review Focus

1. **A part removed from the register after the phone synced.** The server keeps what the phone sent as a typed line. So a picked line also sends its number and description, not only `part_id`. Pinned in Task 2.
2. **Quantity typed with a comma** ("1,5", a South African keyboard). This must read as 1.5 and never be refused or silently lost. Pinned in Task 5.
3. **A server refusal naming `parts[1].qty` on Fix and resend.** The message shows on that row, and changing the parts clears it. Pinned in Tasks 5 and 6.
4. **A slow or missing `RepairPart` read on a synced work order.** The detail screen shows "Parts not loaded" and the rest of the screen still loads. Pinned in Task 4.
5. **An old server without `capture_parts`.** A job with parts waits ("server not ready") and is never parked. A job without parts still goes. Pinned in Task 3.

---

### Task 1: Bring `Part` and `RepairPart` into the PowerSync schema

**Files:**
- Modify: `lib/sync/powersync_schema.dart` (replace the body with the Go copy; keep the 15-line header, updated)
- Test: `test/sync/powersync_schema_test.dart`

**Interfaces:**
- Produces: PowerSync tables `Part` (`PartID` int, `PartType` int, `PartNumber` text, `PartDescription` text) and `RepairPart` (`RepairPartSerialID`, `RepairPartTrackID`, `RepairPartNo`, `RepairPartDescription`, `RepairPartQty` text/numeric, `RepairPartType`, `RepairPartID`, …).

- [ ] **Step 1: Write the failing test.** Add to `test/sync/powersync_schema_test.dart` inside `group('powersync schema', ...)`:

```dart
    // Parts used on a captured work order (2026-10-02). No price column may
    // reach a device — the user's rule.
    test('declares the parts register and parts used, without prices', () {
      expect(_columnNames('Part'), [
        'PartID',
        'PartType',
        'PartNumber',
        'PartDescription',
      ]);
      expect(
        _columnNames('RepairPart'),
        containsAll([
          'RepairPartTrackID',
          'RepairPartNo',
          'RepairPartDescription',
          'RepairPartQty',
          'RepairPartID',
        ]),
      );
      for (final t in ['Part', 'RepairPart']) {
        expect(
          _columnNames(t).where(
            (c) => c.contains('Cost') || c.contains('Price') || c.contains('Total'),
          ),
          isEmpty,
          reason: '$t carries a price',
        );
      }
    });
```

- [ ] **Step 2: Run it.** `flutter test test/sync/powersync_schema_test.dart` → expected FAIL: `Bad state: No element` (there is no `Part` table yet).

- [ ] **Step 3: Copy the schema.** Bash, from the repo root:

```bash
{ sed -n 1,15p lib/sync/powersync_schema.dart \
    | sed 's#^//   source: .*#//   source: E:\\Stat_Trac_Go\\docs\\flutter-sync-schema.dart#; s#^//   copied: .*#//   copied: 2026-10-02#'; \
  cat E:/Stat_Trac_Go/docs/flutter-sync-schema.dart; } > /tmp/schema.dart && mv /tmp/schema.dart lib/sync/powersync_schema.dart
dart format lib/sync/powersync_schema.dart
```

Check that only `Part` and `RepairPart` were added, with nothing else lost:

```bash
git diff --stat lib/sync/powersync_schema.dart
git diff -w lib/sync/powersync_schema.dart | grep "^[-+] *Column\|^[-+] *Table" | sort | uniq -c
```

Expected: `+` lines only, for `Table('RepairPart'`, `Table('Part'` and their columns. (`TestTechSigned` and `TestClientSigned` may show as reformatted, not removed.)

- [ ] **Step 4: Run tests.** `flutter test test/sync/` → PASS. `flutter analyze` → No issues found.

- [ ] **Step 5: Commit.**

```bash
git add lib/sync/powersync_schema.dart test/sync/powersync_schema_test.dart
git commit -m "feat(sync): Part and RepairPart in the schema, copied from Go"
```

---

### Task 2: `PartUsed` and `WorkOrderJob.parts`

**Files:**
- Create: `lib/features/work_orders/domain/part_used.dart`
- Modify: `lib/features/work_orders/domain/work_order_job.dart`
- Test: `test/features/work_orders/part_used_test.dart`

**Interfaces:**
- Produces:
  - `class PartUsed { const PartUsed({this.partId, this.partNo = '', this.description = '', required this.qty}); final int? partId; final String partNo; final String description; final double qty; bool get picked; String get label; String get qtyText; Map<String, Object?> toWire(); factory PartUsed.fromWire(Map<String, Object?>); static const maxPartNo = 50; static const maxDescription = 100; static double? parseQty(String text); }`
  - `WorkOrderJob.parts` (`List<PartUsed>`, default `const []`), included in `validate()`, `toWire()`, `fromWire()`, `copyWith({List<PartUsed>? parts})`.
  - Validation errors use field `parts[<i>].description` or `parts[<i>].qty`.

- [ ] **Step 1: Write the failing test.** `test/features/work_orders/part_used_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/features/work_orders/domain/part_used.dart';
import 'package:stat_trac_technical/features/work_orders/domain/work_order_job.dart';
import 'package:stat_trac_technical/features/work_orders/domain/work_type.dart';

WorkOrderJob _job(List<PartUsed> parts) => WorkOrderJob(
  assetId: 100,
  workType: WorkType.values.first,
  started: DateTime(2026, 10, 2, 8),
  finished: DateTime(2026, 10, 2, 9),
  parts: parts,
);

void main() {
  group('wire', () {
    test('no lines, no parts key', () {
      expect(_job(const []).toWire().containsKey('parts'), isFalse);
    });

    // A part dropped from the register after the phone synced is kept by the
    // server as what the phone sent — so a picked line carries its name too.
    test('a picked line sends its id, number, description and qty', () {
      final w = _job(const [
        PartUsed(partId: 412, partNo: 'FUSE-5A', description: 'Fuse 5A', qty: 2),
      ]).toWire();
      expect(w['parts'], [
        {'part_id': 412, 'part_no': 'FUSE-5A', 'description': 'Fuse 5A', 'qty': 2.0},
      ]);
    });

    test('a typed line sends no part id', () {
      final w = _job(const [
        PartUsed(partNo: '', description: 'Cable tie', qty: 1.5),
      ]).toWire();
      expect(w['parts'], [
        {'part_no': '', 'description': 'Cable tie', 'qty': 1.5},
      ]);
    });

    test('back from the wire for Fix and resend', () {
      final job = _job(const [
        PartUsed(partId: 412, partNo: 'FUSE-5A', description: 'Fuse 5A', qty: 2),
        PartUsed(description: 'Cable tie', qty: 1.5),
      ]);
      final back = WorkOrderJob.fromWire(job.toWire());
      expect(back.parts.length, 2);
      expect(back.parts[0].partId, 412);
      expect(back.parts[1].picked, isFalse);
      expect(back.parts[1].qty, 1.5);
    });
  });

  group('validate', () {
    test('a line needs a code or a description', () {
      final e = _job(const [PartUsed(qty: 1)]).validate();
      expect(e?.field, 'parts[0].description');
    });

    test('a quantity of nought is refused, naming the line', () {
      final e = _job(const [
        PartUsed(description: 'a', qty: 1),
        PartUsed(description: 'b', qty: 0),
      ]).validate();
      expect(e?.field, 'parts[1].qty');
    });

    test('a code over 50 or a description over 100 is refused', () {
      expect(
        _job([PartUsed(partNo: 'x' * 51, qty: 1)]).validate()?.field,
        'parts[0].part_no',
      );
      expect(
        _job([PartUsed(description: 'x' * 101, qty: 1)]).validate()?.field,
        'parts[0].description',
      );
    });

    test('good lines pass', () {
      expect(_job(const [PartUsed(partNo: 'A1', qty: 0.5)]).validate(), isNull);
    });
  });

  group('quantity text', () {
    // A South African keyboard types a comma.
    test('reads a comma as a decimal point', () {
      expect(PartUsed.parseQty('1,5'), 1.5);
      expect(PartUsed.parseQty(' 2 '), 2);
      expect(PartUsed.parseQty(''), isNull);
      expect(PartUsed.parseQty('abc'), isNull);
    });

    test('shows whole numbers without .0', () {
      expect(const PartUsed(description: 'a', qty: 2).qtyText, '2');
      expect(const PartUsed(description: 'a', qty: 1.5).qtyText, '1.5');
    });
  });
}
```

- [ ] **Step 2: Run it.** `flutter test test/features/work_orders/part_used_test.dart` → expected FAIL: `part_used.dart` does not exist.

- [ ] **Step 3: Create `lib/features/work_orders/domain/part_used.dart`.**

```dart
/// One part used on a job card — the desktop's Work Order tab "Parts" grid
/// (`RepairPart`), not Spares.
///
/// **No price, ever.** The phone never sees one: a picked line is priced from
/// the register by the server, a typed line at nought for the office.
class PartUsed {
  const PartUsed({
    this.partId,
    this.partNo = '',
    this.description = '',
    required this.qty,
  });

  /// The register's `PartID` when picked; null when typed.
  final int? partId;
  final String partNo;
  final String description;
  final double qty;

  /// The server's limits (`maxUsedPartNo`, `maxUsedPartDesc`).
  static const maxPartNo = 50;
  static const maxDescription = 100;

  bool get picked => partId != null;

  /// "FUSE-5A — Fuse 5A", or whichever half there is.
  String get label => [
    partNo.trim(),
    description.trim(),
  ].where((s) => s.isNotEmpty).join(' — ');

  String get qtyText =>
      qty == qty.truncateToDouble() ? qty.toInt().toString() : qty.toString();

  /// A quantity as typed. A comma is a decimal point — South African keyboards.
  static double? parseQty(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  /// A picked line sends its number and description as well as its id: if the
  /// part has left the register since this phone synced, the server keeps what
  /// was sent as a typed line rather than losing it.
  Map<String, Object?> toWire() => {
    'part_id': ?partId,
    'part_no': partNo.trim(),
    'description': description.trim(),
    'qty': qty,
  };

  factory PartUsed.fromWire(Map<String, Object?> w) => PartUsed(
    partId: (w['part_id'] as num?)?.toInt(),
    partNo: w['part_no'] as String? ?? '',
    description: w['description'] as String? ?? '',
    qty: (w['qty'] as num?)?.toDouble() ?? 0,
  );
}
```

- [ ] **Step 4: Extend `WorkOrderJob`** in `lib/features/work_orders/domain/work_order_job.dart`:

1. Add `import 'part_used.dart';` and `export 'part_used.dart';` under `import 'work_type.dart';`.
2. Constructor: add `this.parts = const [],` after `this.jobCardNo = '',`.
3. Field, after `final String jobCardNo;`:

```dart
  /// Parts used, in the order the technician added them.
  final List<PartUsed> parts;
```

4. In `validate()`, just before the final `return null;`:

```dart
    for (var i = 0; i < parts.length; i++) {
      final p = parts[i];
      if (p.partNo.trim().runes.length > PartUsed.maxPartNo) {
        return WorkOrderFieldError(
          'parts[$i].part_no',
          'The item code is longer than ${PartUsed.maxPartNo} characters',
        );
      }
      if (p.description.trim().runes.length > PartUsed.maxDescription) {
        return WorkOrderFieldError(
          'parts[$i].description',
          'The description is longer than ${PartUsed.maxDescription} characters',
        );
      }
      if (!p.picked && p.partNo.trim().isEmpty && p.description.trim().isEmpty) {
        return WorkOrderFieldError(
          'parts[$i].description',
          'A part needs an item code or a description',
        );
      }
      if (p.qty <= 0) {
        return WorkOrderFieldError(
          'parts[$i].qty',
          'A part needs a quantity above nought',
        );
      }
    }
```

5. In `toWire()`, after `'job_card_no': jobCardNo.trim(),`:

```dart
    if (parts.isNotEmpty) 'parts': [for (final p in parts) p.toWire()],
```

6. In `fromWire`, after `jobCardNo: ...,`:

```dart
    parts: [
      for (final p in (w['parts'] as List?) ?? const [])
        PartUsed.fromWire(Map<String, Object?>.from(p as Map)),
    ],
```

7. `copyWith`: add parameter `List<PartUsed>? parts,` and argument `parts: parts ?? this.parts,`.

- [ ] **Step 5: Carry parts through the form's rebuild.** In `lib/features/work_orders/presentation/widgets/work_order_form.dart`, `_emit` builds a fresh `WorkOrderJob`. Add `parts: j.parts,` after `jobCardNo: _jobCard.text,`, so typing a fault never drops the parts.

- [ ] **Step 6: Run tests.** `flutter test test/features/work_orders/` → PASS. `flutter analyze` → No issues found.

- [ ] **Step 7: Commit.**

```bash
git add lib/features/work_orders/domain test/features/work_orders/part_used_test.dart lib/features/work_orders/presentation/widgets/work_order_form.dart
git commit -m "feat(work-orders): parts used on the job, wire and checks"
```

---

### Task 3: Hold a job with parts for a server without `capture_parts`

**Files:**
- Modify: `lib/sync/upload/sync_upload_result.dart` (`SyncUploadGuarantee`)
- Modify: `lib/sync/upload/work_order_upload.dart`
- Modify: `lib/sync/upload/upload_worker.dart:130-133, 167, 290`
- Test: `test/sync/upload/upload_worker_work_order_test.dart`

**Interfaces:**
- Produces: `SyncUploadGuarantee.captureParts = 'capture_parts'`; `WorkOrderUpload.carriesParts` (`bool`); `UploadWorker._takes(QueuedUpload, List<String>?)`.

- [ ] **Step 1: Write the failing tests.** Append inside `main()` of `test/sync/upload/upload_worker_work_order_test.dart`:

```dart
  group('parts', () {
    WorkOrderUpload withParts(String id) => WorkOrderUpload(
      mobileId: id,
      capture: const {
        'asset_id': 1234,
        'work_type': 1,
        'parts': [
          {'part_id': 412, 'part_no': 'F', 'description': 'Fuse', 'qty': 1.0},
        ],
      },
      techPng: 'AAAA',
      clientPng: 'BBBB',
      clientName: 'Sister Dlamini',
    );

    test('carriesParts reads the capture', () {
      expect(withParts('a').carriesParts, isTrue);
      expect(_wo('b').carriesParts, isFalse);
    });

    // The server announced it takes work orders but not their parts. The job
    // with parts waits; the one without goes.
    test('a job with parts waits for capture_parts; one without goes', () async {
      await queue.enqueue(_wo('wo-1'));
      await queue.enqueue(withParts('wo-2'));
      answers(
        const UploadApplied(
          applied: 0,
          assigned: {'wo-1': 1801},
          issued: [],
          enforces: _ready,
        ),
      );

      final r = await worker.drain();

      expect(r.appliedWorkOrders, 1);
      expect(r.waitingForServer, 1);
      final left = (await queue.all()).single;
      expect(left.upload.mobileId, 'wo-2');
      expect(left.status, UploadStatus.pending);
      expect(left.lastError, UploadWorker.serverNotReady);
      expect(sends(), 1);
    });

    test('with capture_parts announced, a job with parts goes', () async {
      await queue.enqueue(withParts('wo-2'));
      answers(
        const UploadApplied(
          applied: 0,
          assigned: {'wo-2': 1802},
          issued: [],
          enforces: [..._ready, 'capture_parts'],
        ),
      );

      final r = await worker.drain();

      expect(r.appliedWorkOrders, 1);
      expect(await queue.count(), 0);
    });

    // A server that does not know "parts" refuses the batch as a 400 — that is
    // not ready yet, never parked.
    test('a 400 for parts from an older server keeps the job pending', () async {
      await queue.enqueue(withParts('wo-2'));
      answers(
        const UploadClientError('unknown field "parts"', enforces: _ready),
      );

      final r = await worker.drain();

      expect((await queue.all()).single.status, UploadStatus.pending);
      expect(r.waitingForServer, 1);
      expect(r.failed, 0);
    });
  });
```

- [ ] **Step 2: Run them.** `flutter test test/sync/upload/upload_worker_work_order_test.dart` → expected FAIL: `The getter 'carriesParts' isn't defined`.

- [ ] **Step 3: Implement.**

`lib/sync/upload/sync_upload_result.dart`, after `jobSignAction`:

```dart

  /// `capture` on `Repair` accepts `parts` and writes them in its transaction.
  static const captureParts = 'capture_parts';
```

`lib/sync/upload/work_order_upload.dart`, after `final String clientName;`:

```dart

  /// Whether the job carries parts used — sent only to a server that announces
  /// `capture_parts`.
  bool get carriesParts => (capture['parts'] as List?)?.isNotEmpty ?? false;
```

`lib/sync/upload/upload_worker.dart`: replace `_takesWorkOrders` with:

```dart
  /// Whether this server can take [upload]. A job with parts needs
  /// `capture_parts` too; a job without is unaffected.
  static bool _takes(WorkOrderUpload upload, List<String>? enforces) =>
      enforces == null ||
      (enforces.contains(SyncUploadGuarantee.captureAction) &&
          enforces.contains(SyncUploadGuarantee.jobSignAction) &&
          (!upload.carriesParts ||
              enforces.contains(SyncUploadGuarantee.captureParts)));
```

and change its two call sites:
- in the loop: `if (!_takesWorkOrders(_lastEnforces) && probed) {` → `if (!_takes(upload, _lastEnforces) && probed) {`
- in `UploadClientError`: `if (upload is WorkOrderUpload && !_takesWorkOrders(result.enforces)) {` → `if (upload is WorkOrderUpload && !_takes(upload, result.enforces)) {`

- [ ] **Step 4: Run tests.** `flutter test test/sync/upload/` → PASS. `flutter analyze` → No issues found.

- [ ] **Step 5: Commit.**

```bash
git add lib/sync/upload test/sync/upload/upload_worker_work_order_test.dart
git commit -m "feat(upload): a job with parts waits for capture_parts"
```

---

### Task 4: Read the register and the parts on a synced work order

**Files:**
- Create: `lib/features/work_orders/domain/register_part.dart`
- Modify: `lib/features/work_orders/data/powersync_work_order_data_source.dart`
- Modify: `lib/features/work_orders/presentation/providers/work_order_providers.dart` (+ `.g.dart` via build_runner)
- Test: `test/features/work_orders/powersync_parts_test.dart`

**Interfaces:**
- Consumes: `PartUsed` (Task 2).
- Produces:
  - `class RegisterPart { const RegisterPart({required this.id, this.number = '', this.description = ''}); final int id; final String number; final String description; }`
  - `Future<List<RegisterPart>> PowerSyncWorkOrderDataSource.searchParts(String query, {int limit = 50})`
  - `Future<List<PartUsed>?> PowerSyncWorkOrderDataSource.partsOn(int trackId)` (null = could not read)
  - `repairPartsProvider(int trackId)` → `Future<List<PartUsed>?>`; `partSearchProvider` → `Future<List<RegisterPart>> Function(String)`.

- [ ] **Step 1: Write the failing test.** `test/features/work_orders/powersync_parts_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stat_trac_technical/features/work_orders/data/powersync_work_order_data_source.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late PowerSyncWorkOrderDataSource ds;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute(
      'CREATE TABLE "Part" ("PartID" INTEGER, "PartType" INTEGER, '
      '"PartNumber" TEXT, "PartDescription" TEXT)',
    );
    await db.execute(
      'CREATE TABLE "RepairPart" ("RepairPartSerialID" INTEGER, '
      '"RepairPartTrackID" INTEGER, "RepairPartNo" TEXT, '
      '"RepairPartDescription" TEXT, "RepairPartQty" TEXT, '
      '"RepairPartType" INTEGER, "RepairPartID" INTEGER)',
    );
    for (final (id, type, no, desc) in [
      (1, 1, 'FUSE-5A', 'Fuse 5A'),
      (2, 1, 'BATT-12', 'Battery 12V'),
      (3, 2, 'LABOUR', 'Labour'),
      (4, null, 'CABLE', 'Mains cable'),
    ]) {
      await db.insert('Part', {
        'PartID': id,
        'PartType': type,
        'PartNumber': no,
        'PartDescription': desc,
      });
    }
    ds = PowerSyncWorkOrderDataSource((sql, args) => db.rawQuery(sql, args));
  });

  tearDown(() => db.close());

  group('searchParts', () {
    test('parts only, sorted by number', () async {
      final all = await ds.searchParts('');
      expect([for (final p in all) p.number], ['BATT-12', 'CABLE', 'FUSE-5A']);
    });

    test('by number or description, any case', () async {
      expect((await ds.searchParts('fuse')).single.id, 1);
      expect((await ds.searchParts('mains')).single.id, 4);
      expect(await ds.searchParts('labour'), isEmpty);
    });
  });

  group('partsOn', () {
    test('the lines on one work order, quantity read from numeric text',
        () async {
      await db.insert('RepairPart', {
        'RepairPartSerialID': 10,
        'RepairPartTrackID': 7144,
        'RepairPartNo': 'FUSE-5A',
        'RepairPartDescription': 'Fuse 5A',
        'RepairPartQty': '2.00',
        'RepairPartType': 1,
        'RepairPartID': 1,
      });
      await db.insert('RepairPart', {
        'RepairPartSerialID': 11,
        'RepairPartTrackID': 9999,
        'RepairPartNo': 'X',
        'RepairPartQty': '1',
      });

      final lines = (await ds.partsOn(7144))!;
      expect(lines.single.label, 'FUSE-5A — Fuse 5A');
      expect(lines.single.qty, 2);
    });

    // A slow or missing table: the detail screen says "parts not loaded"
    // rather than losing the whole work order.
    test('unreadable is null, not an exception', () async {
      final broken = PowerSyncWorkOrderDataSource(
        (sql, args) async => throw StateError('no such table'),
      );
      expect(await broken.partsOn(7144), isNull);
    });
  });
}
```

- [ ] **Step 2: Run it.** `flutter test test/features/work_orders/powersync_parts_test.dart` → expected FAIL: `The method 'searchParts' isn't defined`.

- [ ] **Step 3: Create `lib/features/work_orders/domain/register_part.dart`.**

```dart
/// A part from the synced register — parts only, no stock, no price.
class RegisterPart {
  const RegisterPart({
    required this.id,
    this.number = '',
    this.description = '',
  });

  final int id;
  final String number;
  final String description;
}
```

- [ ] **Step 4: Add the two reads** to `PowerSyncWorkOrderDataSource`, before `_statusNames`. Add `import '../domain/part_used.dart';` and `import '../domain/register_part.dart';` at the top.

```dart
  /// The parts register, parts only (`PartType` 1 or blank), matched on number
  /// or description, sorted by number. No stock and no price reach a device.
  Future<List<RegisterPart>> searchParts(String query, {int limit = 50}) async {
    final like = '%${query.trim()}%';
    final rows = await _read(
      'SELECT "PartID", "PartNumber", "PartDescription" FROM "Part" '
      'WHERE coalesce("PartType", 1) = 1 '
      'AND ("PartNumber" LIKE ? OR "PartDescription" LIKE ?) '
      'ORDER BY "PartNumber" LIMIT ?',
      [like, like, limit],
    ).timeout(timeout);
    return [
      for (final r in rows)
        if (psInt(r['PartID']) case final id?)
          RegisterPart(
            id: id,
            number: (r['PartNumber'] as String? ?? '').trim(),
            description: (r['PartDescription'] as String? ?? '').trim(),
          ),
    ];
  }

  /// The parts used on a synced work order. Null when they could not be read
  /// in time — the screen says so rather than showing none.
  Future<List<PartUsed>?> partsOn(int trackId) async {
    try {
      final rows = await _read(
        'SELECT "RepairPartID", "RepairPartNo", "RepairPartDescription", '
        '"RepairPartQty" FROM "RepairPart" WHERE "RepairPartTrackID" = ? '
        'ORDER BY "RepairPartSerialID"',
        [trackId],
      ).timeout(timeout);
      return [
        for (final r in rows)
          PartUsed(
            partId: psInt(r['RepairPartID']),
            partNo: (r['RepairPartNo'] as String? ?? '').trim(),
            description: (r['RepairPartDescription'] as String? ?? '').trim(),
            qty: psNum(r['RepairPartQty']) ?? 0,
          ),
      ];
    } catch (e) {
      debugPrint('[work orders] parts unreadable: $e');
      return null;
    }
  }
```

- [ ] **Step 5: Providers.** In `work_order_providers.dart`, add `import '../../domain/part_used.dart';` and `import '../../domain/register_part.dart';`, then after `workOrderRecord`:

```dart
@riverpod
Future<List<PartUsed>?> repairParts(Ref ref, int trackId) async =>
    (await ref.watch(workOrderSourceProvider.future)).partsOn(trackId);

/// The register search the parts picker calls as the technician types.
@riverpod
Future<Future<List<RegisterPart>> Function(String)> partSearch(Ref ref) async {
  final source = await ref.watch(workOrderSourceProvider.future);
  return source.searchParts;
}
```

Run: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 6: Run tests.** `flutter test test/features/work_orders/` → PASS. `flutter analyze` → No issues found.

- [ ] **Step 7: Commit.**

```bash
git add lib/features/work_orders test/features/work_orders/powersync_parts_test.dart
git commit -m "feat(work-orders): read the parts register and a work order's parts"
```

---

### Task 5: The "Parts used" section and the picker

**Files:**
- Create: `lib/features/work_orders/presentation/widgets/parts_used_section.dart`
- Create: `lib/features/work_orders/presentation/widgets/part_picker_sheet.dart`
- Modify: `lib/features/work_orders/presentation/widgets/work_order_form.dart`
- Test: `test/features/work_orders/parts_used_section_test.dart`

**Interfaces:**
- Consumes: `PartUsed`, `RegisterPart`, `WorkOrderFieldError` (Tasks 2 and 4).
- Produces:
  - `PartsUsedSection({required List<PartUsed> parts, required ValueChanged<List<PartUsed>> onChanged, required Future<List<RegisterPart>> Function(String) search, WorkOrderFieldError? error})`
  - `Future<PartUsed?> showPartPicker(BuildContext context, {required Future<List<RegisterPart>> Function(String) search})`
  - `WorkOrderForm` gains `required Future<List<RegisterPart>> Function(String) searchParts`.

- [ ] **Step 1: Write the failing test.** `test/features/work_orders/parts_used_section_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/core/theme/app_theme.dart';
import 'package:stat_trac_technical/features/work_orders/domain/part_used.dart';
import 'package:stat_trac_technical/features/work_orders/domain/register_part.dart';
import 'package:stat_trac_technical/features/work_orders/domain/work_order_job.dart';
import 'package:stat_trac_technical/features/work_orders/presentation/widgets/parts_used_section.dart';

Future<List<RegisterPart>> _search(String q) async => [
  for (final p in const [
    RegisterPart(id: 1, number: 'FUSE-5A', description: 'Fuse 5A'),
    RegisterPart(id: 2, number: 'BATT-12', description: 'Battery 12V'),
  ])
    if ('${p.number} ${p.description}'.toLowerCase().contains(q.toLowerCase()))
      p,
];

Future<List<List<PartUsed>>> _pump(
  WidgetTester t, {
  List<PartUsed> parts = const [],
  WorkOrderFieldError? error,
}) async {
  t.view.physicalSize = const Size(1080, 2316);
  t.view.devicePixelRatio = 1080 / 384;
  addTearDown(t.view.reset);
  final changes = <List<PartUsed>>[];
  await t.pumpWidget(
    MaterialApp(
      theme: appTheme,
      home: Scaffold(
        body: StatefulBuilder(
          builder: (c, set) => ListView(
            children: [
              PartsUsedSection(
                parts: changes.isEmpty ? parts : changes.last,
                search: _search,
                error: error,
                onChanged: (p) => set(() => changes.add(p)),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return changes;
}

void main() {
  testWidgets('pick from the register, then a quantity', (t) async {
    final changes = await _pump(t);
    await t.tap(find.text('Add part'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('part-search')), 'fuse');
    await t.pumpAndSettle();
    await t.tap(find.text('FUSE-5A'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('part-qty')), '2');
    await t.pump();
    await t.tap(find.text('Add'));
    await t.pumpAndSettle();

    final p = changes.last.single;
    expect(p.partId, 1);
    expect(p.qty, 2);
    expect(find.text('FUSE-5A — Fuse 5A'), findsOneWidget);
    expect(find.text('× 2'), findsOneWidget);
  });

  testWidgets('type it instead, with a comma quantity', (t) async {
    final changes = await _pump(t);
    await t.tap(find.text('Add part'));
    await t.pumpAndSettle();
    await t.tap(find.text('Type it instead'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('part-desc')), 'Cable tie');
    await t.enterText(find.byKey(const Key('part-qty')), '1,5');
    await t.pump();
    await t.tap(find.text('Add'));
    await t.pumpAndSettle();

    final p = changes.last.single;
    expect(p.picked, isFalse);
    expect(p.description, 'Cable tie');
    expect(p.qty, 1.5);
  });

  testWidgets('a quantity of nought cannot be added', (t) async {
    await _pump(t);
    await t.tap(find.text('Add part'));
    await t.pumpAndSettle();
    await t.tap(find.text('FUSE-5A'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('part-qty')), '0');
    await t.pump();
    expect(
      t.widget<TextButton>(find.widgetWithText(TextButton, 'Add')).onPressed,
      isNull,
    );
  });

  testWidgets('remove a line', (t) async {
    final changes = await _pump(
      t,
      parts: const [PartUsed(description: 'Cable tie', qty: 1)],
    );
    await t.tap(find.byTooltip('Remove'));
    await t.pumpAndSettle();
    expect(changes.last, isEmpty);
  });

  testWidgets("a refusal shows on its line", (t) async {
    await _pump(
      t,
      parts: const [
        PartUsed(description: 'a', qty: 1),
        PartUsed(description: 'b', qty: 1),
      ],
      error: const WorkOrderFieldError('parts[1].qty', 'Too many'),
    );
    expect(find.text('Too many'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it.** `flutter test test/features/work_orders/parts_used_section_test.dart` → expected FAIL: `parts_used_section.dart` does not exist.

- [ ] **Step 3: Create `lib/features/work_orders/presentation/widgets/part_picker_sheet.dart`.**

```dart
import 'package:flutter/material.dart';

import '../../domain/part_used.dart';
import '../../domain/register_part.dart';

/// Picks a part from the register, or takes one typed, then asks the quantity.
/// Null when the technician backs out. Everything it has to say stays inside
/// the sheet — a SnackBar from a sheet renders behind it.
Future<PartUsed?> showPartPicker(
  BuildContext context, {
  required Future<List<RegisterPart>> Function(String) search,
}) => showModalBottomSheet<PartUsed>(
  context: context,
  isScrollControlled: true,
  builder: (_) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: _PartPicker(search: search),
  ),
);

class _PartPicker extends StatefulWidget {
  const _PartPicker({required this.search});
  final Future<List<RegisterPart>> Function(String) search;

  @override
  State<_PartPicker> createState() => _PartPickerState();
}

class _PartPickerState extends State<_PartPicker> {
  /// Null while choosing. A register part, or a typed line, once chosen.
  RegisterPart? _picked;
  bool _typing = false;
  String _query = '';
  late Future<List<RegisterPart>> _results = widget.search('');

  final _code = TextEditingController();
  final _desc = TextEditingController();
  final _qty = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    _desc.dispose();
    _qty.dispose();
    super.dispose();
  }

  double? get _qtyValue {
    final q = PartUsed.parseQty(_qty.text);
    return q != null && q > 0 ? q : null;
  }

  bool get _named =>
      _picked != null ||
      _code.text.trim().isNotEmpty ||
      _desc.text.trim().isNotEmpty;

  void _add() => Navigator.of(context).pop(
    _picked != null
        ? PartUsed(
            partId: _picked!.id,
            partNo: _picked!.number,
            description: _picked!.description,
            qty: _qtyValue!,
          )
        : PartUsed(partNo: _code.text, description: _desc.text, qty: _qtyValue!),
  );

  @override
  Widget build(BuildContext context) {
    final choosing = _picked == null && !_typing;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: choosing ? _chooser() : _details(),
      ),
    );
  }

  Widget _chooser() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Add part', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      TextField(
        key: const Key('part-search'),
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Search number or description',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (q) => setState(() {
          _query = q;
          _results = widget.search(q);
        }),
      ),
      Expanded(
        child: FutureBuilder<List<RegisterPart>>(
          future: _results,
          builder: (_, snap) {
            if (snap.hasError) {
              return const Center(child: Text('Could not read the parts list'));
            }
            final parts = snap.data;
            if (parts == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (parts.isEmpty) {
              return Center(
                child: Text(
                  _query.isEmpty ? 'No parts on this phone yet' : 'No match',
                ),
              );
            }
            return ListView(
              children: [
                for (final p in parts)
                  ListTile(
                    title: Text(p.number),
                    subtitle: Text(p.description),
                    onTap: () => setState(() => _picked = p),
                  ),
              ],
            );
          },
        ),
      ),
      TextButton(
        onPressed: () => setState(() => _typing = true),
        child: const Text('Type it instead'),
      ),
    ],
  );

  Widget _details() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_picked != null)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_picked!.number),
          subtitle: Text(_picked!.description),
        )
      else ...[
        TextField(
          key: const Key('part-code'),
          controller: _code,
          maxLength: PartUsed.maxPartNo,
          decoration: const InputDecoration(labelText: 'Item code'),
          onChanged: (_) => setState(() {}),
        ),
        TextField(
          key: const Key('part-desc'),
          controller: _desc,
          maxLength: PartUsed.maxDescription,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Description'),
          onChanged: (_) => setState(() {}),
        ),
        if (!_named)
          const Text('An item code or a description is needed'),
      ],
      const SizedBox(height: 12),
      TextField(
        key: const Key('part-qty'),
        controller: _qty,
        autofocus: _picked != null,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Quantity'),
        onChanged: (_) => setState(() {}),
      ),
      const Spacer(),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: _named && _qtyValue != null ? _add : null,
            child: const Text('Add'),
          ),
        ],
      ),
    ],
  );
}
```

- [ ] **Step 4: Create `lib/features/work_orders/presentation/widgets/parts_used_section.dart`.**

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/part_used.dart';
import '../../domain/register_part.dart';
import '../../domain/work_order_job.dart';
import 'part_picker_sheet.dart';

/// "Parts used" on the job card: the lines, Add part, and a remove per line.
/// No prices. A refusal naming `parts[<i>]...` shows under that line.
class PartsUsedSection extends StatelessWidget {
  const PartsUsedSection({
    super.key,
    required this.parts,
    required this.onChanged,
    required this.search,
    this.error,
  });

  final List<PartUsed> parts;
  final ValueChanged<List<PartUsed>> onChanged;
  final Future<List<RegisterPart>> Function(String) search;
  final WorkOrderFieldError? error;

  String? _errorOn(int i) {
    final e = error;
    return e != null && e.field.startsWith('parts[$i].') ? e.message : null;
  }

  Future<void> _add(BuildContext context) async {
    final part = await showPartPicker(context, search: search);
    if (part != null) onChanged([...parts, part]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Parts used', style: Theme.of(context).textTheme.titleSmall),
        for (var i = 0; i < parts.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(parts[i].label),
            subtitle: _errorOn(i) == null
                ? null
                : Text(
                    _errorOn(i)!,
                    style: const TextStyle(color: brandError),
                  ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('× ${parts[i].qtyText}'),
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.close),
                  onPressed: () =>
                      onChanged([...parts]..removeAt(i)),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _add(context),
            icon: const Icon(Icons.add),
            label: const Text('Add part'),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Put it in the form.** In `work_order_form.dart`:

1. Imports: `import '../../domain/register_part.dart';` and `import 'parts_used_section.dart';`.
2. Constructor: add `required this.searchParts,` and the field `final Future<List<RegisterPart>> Function(String) searchParts;`.
3. `_emit` gains a `List<PartUsed>? parts` parameter. Its signature becomes `void _emit({WorkType? workType, DateTime? started, DateTime? finished, List<PartUsed>? parts})`, and the line added in Task 2 becomes `parts: parts ?? j.parts,`.
4. After the `wo-jobcard` `_text(...)` in `build`, add:

```dart
        gap,
        PartsUsedSection(
          parts: widget.job.parts,
          search: widget.searchParts,
          error: widget.serverError ?? widget.job.validate(),
          onChanged: (p) => _emit(parts: p),
        ),
```

5. In `test/features/work_orders/work_order_form_test.dart`, pass `searchParts: (_) async => const [],` to `WorkOrderForm(...)` and add the import `package:stat_trac_technical/features/work_orders/domain/register_part.dart` only if the analyzer asks for it.

- [ ] **Step 6: Give the screen the search.** In `create_work_order_screen.dart` `_formStep()`, pass:

```dart
            searchParts: (q) async =>
                (await ref.read(partSearchProvider.future))(q),
```

to `WorkOrderForm(...)`. In `_changed`, add a branch before `_ => true,`:

```dart
        _ when field.startsWith('parts[') => a.parts != b.parts,
```

Any change to the parts list (a new list instance) then clears a parts refusal.

- [ ] **Step 7: Run tests.** `flutter test test/features/work_orders/` → PASS. `flutter analyze` → No issues found. `dart format lib test`.

- [ ] **Step 8: Commit.**

```bash
git add lib/features/work_orders test/features/work_orders
git commit -m "feat(work-orders): Parts used on the job card — pick or type, quantity, remove"
```

---

### Task 6: Parts on the work order detail screen

**Files:**
- Modify: `lib/features/work_orders/presentation/screens/work_order_detail_screen.dart`
- Test: `test/features/work_orders/work_order_detail_screen_test.dart`

**Interfaces:**
- Consumes: `WorkOrderJob.parts` (Task 2), `repairPartsProvider` (Task 4).
- Produces: private `_PartsList({required List<PartUsed>? parts})`. Null shows "Parts not loaded".

- [ ] **Step 1: Write the failing test.** In `work_order_detail_screen_test.dart`, give `_job()` a parts line by adding to its `capture` map:

```dart
    'parts': [
      {'part_no': 'FUSE-5A', 'description': 'Fuse 5A', 'qty': 2.0},
    ],
```

and add:

```dart
  testWidgets('a queued job lists its parts', (t) async {
    final q = await _queue(t, 'invalid');
    await _open(t, q);
    await t.scrollUntilVisible(find.text('FUSE-5A — Fuse 5A'), 200);
    expect(find.text('× 2'), findsOneWidget);
  });
```

- [ ] **Step 2: Run it.** `flutter test test/features/work_orders/work_order_detail_screen_test.dart` → expected FAIL: the new test finds no `FUSE-5A — Fuse 5A`.

- [ ] **Step 3: Implement.** In `work_order_detail_screen.dart`:

Add the widget at the end of the file:

```dart
/// The parts used. Null means they could not be read — said, not shown as none.
class _PartsList extends StatelessWidget {
  const _PartsList({required this.parts});
  final List<PartUsed>? parts;

  @override
  Widget build(BuildContext context) {
    final p = parts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Parts used', style: Theme.of(context).textTheme.titleSmall),
        if (p == null)
          const Text('Parts not loaded')
        else if (p.isEmpty)
          const Text('None')
        else
          for (final line in p)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(line.label),
              trailing: Text('× ${line.qtyText}'),
            ),
      ],
    );
  }
}
```

In `_Queued`, after `_Field('Job card no', job.jobCardNo),` add:

```dart
                const SizedBox(height: 12),
                _PartsList(parts: job.parts),
```

In `_Synced`, after `_Field('Job card no', r.jobCardNo),` add:

```dart
                    const SizedBox(height: 12),
                    _PartsList(
                      parts: ref.watch(repairPartsProvider(trackId)).when(
                        data: (p) => p,
                        loading: () => const [],
                        error: (_, _) => null,
                      ),
                    ),
```

`WorkOrderJob` re-exports `part_used.dart` (Task 2), so `PartUsed` is already in scope through the existing `work_order_job.dart` import.

- [ ] **Step 4: Run tests.** `flutter test test/features/work_orders/` → PASS. `flutter analyze` → No issues found. `flutter test` (full) → PASS.

- [ ] **Step 5: Commit.**

```bash
git add lib/features/work_orders test/features/work_orders
git commit -m "feat(work-orders): parts used on the detail screen"
```

---

### Task 7: Record and hand over

- [ ] **Step 1:** `CLAUDE.md`:
  - Under "Work Orders — capture on site", add: "**Parts used (2026-10-02)** — job card section, pick from `Part` (parts only) or type; quantity > 0, decimals; no prices. Sent in `capture.parts`, held until `enforces` lists `capture_parts`. Detail screen lists parts from the queue or synced `RepairPart`."
  - In the plan table, add `2026-10-02-work-order-parts.md` — ✅ Built.
- [ ] **Step 2:** `docs/STATE-2026-10-02.md`: move "Parts used" from "Next session" to "Done today".
- [ ] **Step 3: Commit.**

```bash
git add CLAUDE.md docs/STATE-2026-10-02.md
git commit -m "docs: parts used built"
```

- [ ] **Step 4:** Run the app on the emulator (`flutter run -d emulator-5554`) and hand over to the user. Do not tap through it yourself.
