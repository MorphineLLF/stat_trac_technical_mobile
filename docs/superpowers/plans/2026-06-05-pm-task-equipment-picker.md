# PM Task Selection & Test Equipment Picker Improvements — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sync `AssetPmTask` from the Horse API, show equipment type + "Next Cal" dates (expired = red + blocked) in the test equipment picker, and add a PM task description selector to the Certificate Details wizard step.

**Architecture:** New migration 012 adds `asset_pm_tasks`, and alters `test_certificates`, `test_equipment_assets`, and `test_cert_equipment`. A new `GET /assets/pm-tasks` Horse API endpoint feeds a full-replace sync step. `CertDetailsStep` gains a `selectedAsset` param and a PM task card driven by a scoped Riverpod provider.

**Tech Stack:** Flutter/Dart, Riverpod 3 (`riverpod_annotation ^4`), sqflite, Dio, Delphi Horse API, PostgreSQL 12.

---

## File Map

| File | Action |
|---|---|
| `lib/database/migrations/migration_012_pm_tasks.dart` | CREATE |
| `lib/database/database_helper.dart` | MODIFY — register 012, bump version to 12 |
| `lib/features/certification/domain/entities/asset_pm_task.dart` | CREATE |
| `lib/features/certification/data/models/asset_pm_task_model.dart` | CREATE |
| `lib/features/certification/domain/entities/test_equipment_asset.dart` | MODIFY — add `equipmentType`, `DateTime? calDate`, `isCalExpired` |
| `lib/features/certification/data/models/test_equipment_asset_model.dart` | MODIFY — map new fields, parse calDate |
| `lib/features/certification/domain/entities/test_equipment_selection.dart` | MODIFY — add `equipmentType`, `DateTime? calDate`, `isCalExpired`, update `subtitleText` |
| `lib/features/certification/domain/entities/test_certificate.dart` | MODIFY — add `pmTaskDescription` |
| `lib/features/certification/data/models/test_certificate_model.dart` | MODIFY — toMap/fromMap for `pm_task_description` |
| `lib/features/certification/data/models/certificate_summary.dart` | MODIFY — add `pmTaskDescription` |
| `lib/features/certification/data/datasources/cert_local_data_source.dart` | MODIFY — new PM task methods; fix equipment calDate + equipment_type serialization; add pmTaskDescription to certSummarySelect |
| `lib/features/certification/data/datasources/cert_remote_data_source.dart` | MODIFY — add `fetchAssetPmTasks` |
| `lib/features/certification/domain/repositories/certificate_repository.dart` | MODIFY — add `syncAssetPmTasks` |
| `lib/features/certification/data/repositories/certificate_repository_impl.dart` | MODIFY — implement `syncAssetPmTasks`; add `pmTaskDescription` to push payload; update `issueCertificate` |
| `lib/features/certification/presentation/providers/certificate_providers.dart` | MODIFY — add `assetPmTasksProvider` |
| `lib/features/certification/presentation/providers/certificate_providers.g.dart` | REGENERATE via build_runner |
| `lib/features/certification/presentation/widgets/cert_details_step.dart` | MODIFY — add `selectedAsset` param, PM task card, updated `onChanged`, expired UI in picker |
| `lib/features/certification/presentation/screens/create_certificate_screen.dart` | MODIFY — pass `_selectedAsset`, store `_pmTaskDescription`, update `_saveCertificate` |
| `lib/features/certification/presentation/screens/certificate_detail_screen.dart` | MODIFY — show `pmTaskDescription` in header card |
| `lib/sync/sync_notifier.dart` | MODIFY — add `sync_pm_tasks` step |
| `C:\Delphi\StatTracTechAPI\src\Assets.Routes.pas` | MODIFY — add `GET /assets/pm-tasks` |
| `C:\Delphi\StatTracTechAPI\src\Certificates.Routes.pas` | MODIFY — accept `pm_task_description` in POST body |

---

## Task 1: Migration 012

**Files:**
- Create: `lib/database/migrations/migration_012_pm_tasks.dart`
- Modify: `lib/database/database_helper.dart`

- [ ] **Step 1: Create migration file**

```dart
// lib/database/migrations/migration_012_pm_tasks.dart
import 'package:sqflite/sqflite.dart';

Future<void> migration012PmTasks(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS asset_pm_tasks (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      pm_task_id   INTEGER NOT NULL UNIQUE,
      asset_id     INTEGER NOT NULL,
      description  TEXT NOT NULL,
      schedule_date TEXT,
      active       INTEGER NOT NULL DEFAULT 1
    )
  ''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_apt_asset ON asset_pm_tasks (asset_id)',
  );

  try {
    await db.execute(
      'ALTER TABLE test_certificates ADD COLUMN pm_task_description TEXT',
    );
  } catch (_) {}

  try {
    await db.execute(
      'ALTER TABLE test_equipment_assets ADD COLUMN equipment_type TEXT',
    );
  } catch (_) {}

  try {
    await db.execute(
      'ALTER TABLE test_cert_equipment ADD COLUMN equipment_type TEXT',
    );
  } catch (_) {}
}
```

- [ ] **Step 2: Register in database_helper.dart**

Open `lib/database/database_helper.dart`. Add the import and register:

```dart
import 'migrations/migration_012_pm_tasks.dart';
```

Change `_dbVersion` from `11` to `12`.

Add to `_onCreate` after `migration011CertDetails(db)`:
```dart
await migration012PmTasks(db);
```

Add to `_onUpgrade` after the `oldVersion < 11` line:
```dart
if (oldVersion < 12) await migration012PmTasks(db);
```

- [ ] **Step 3: Analyze**

```
flutter analyze lib/database/
```
Expected: no issues.

- [ ] **Step 4: Commit**

```
git add lib/database/migrations/migration_012_pm_tasks.dart lib/database/database_helper.dart
git commit -m "feat(db): migration 012 — asset_pm_tasks, pm_task_description, equipment_type columns"
```

---

## Task 2: AssetPmTask Domain Entity + Model

**Files:**
- Create: `lib/features/certification/domain/entities/asset_pm_task.dart`
- Create: `lib/features/certification/data/models/asset_pm_task_model.dart`

- [ ] **Step 1: Create entity**

```dart
// lib/features/certification/domain/entities/asset_pm_task.dart
import 'package:flutter/foundation.dart';

@immutable
class AssetPmTask {
  const AssetPmTask({
    required this.pmTaskId,
    required this.assetId,
    required this.description,
    this.scheduleDate,
    required this.active,
  });

  final int pmTaskId;
  final int assetId;
  final String description;
  final DateTime? scheduleDate;
  final bool active;
}
```

- [ ] **Step 2: Create model**

```dart
// lib/features/certification/data/models/asset_pm_task_model.dart
import '../../domain/entities/asset_pm_task.dart';

class AssetPmTaskModel extends AssetPmTask {
  const AssetPmTaskModel({
    required super.pmTaskId,
    required super.assetId,
    required super.description,
    super.scheduleDate,
    required super.active,
  });

  factory AssetPmTaskModel.fromJson(Map<String, dynamic> j) =>
      AssetPmTaskModel(
        pmTaskId: j['pm_task_id'] as int,
        assetId: j['asset_id'] as int,
        description: j['description'] as String? ?? '',
        scheduleDate: j['schedule_date'] != null
            ? DateTime.tryParse(j['schedule_date'] as String)
            : null,
        active: (j['active'] as int? ?? 1) == 1,
      );

  factory AssetPmTaskModel.fromMap(Map<String, dynamic> m) =>
      AssetPmTaskModel(
        pmTaskId: m['pm_task_id'] as int,
        assetId: m['asset_id'] as int,
        description: m['description'] as String,
        scheduleDate: m['schedule_date'] != null
            ? DateTime.tryParse(m['schedule_date'] as String)
            : null,
        active: (m['active'] as int? ?? 1) == 1,
      );

  Map<String, dynamic> toMap() => {
        'pm_task_id': pmTaskId,
        'asset_id': assetId,
        'description': description,
        'schedule_date': scheduleDate?.toIso8601String().substring(0, 10),
        'active': active ? 1 : 0,
      };
}
```

- [ ] **Step 3: Analyze**

```
flutter analyze lib/features/certification/domain/entities/asset_pm_task.dart lib/features/certification/data/models/asset_pm_task_model.dart
```
Expected: no issues.

- [ ] **Step 4: Commit**

```
git add lib/features/certification/domain/entities/asset_pm_task.dart lib/features/certification/data/models/asset_pm_task_model.dart
git commit -m "feat(cert): add AssetPmTask entity and model"
```

---

## Task 3: Update TestEquipmentAsset Entity + Model

**Files:**
- Modify: `lib/features/certification/domain/entities/test_equipment_asset.dart`
- Modify: `lib/features/certification/data/models/test_equipment_asset_model.dart`

- [ ] **Step 1: Update entity**

Replace entire `lib/features/certification/domain/entities/test_equipment_asset.dart`:

```dart
import 'package:flutter/foundation.dart';

@immutable
class TestEquipmentAsset {
  const TestEquipmentAsset({
    required this.id,
    required this.assetId,
    this.equipmentType,
    this.manufacturer,
    this.model,
    this.serialNo,
    this.calDate,
    required this.syncedAt,
  });

  final int id;
  final int assetId;
  final String? equipmentType;
  final String? manufacturer;
  final String? model;
  final String? serialNo;
  final DateTime? calDate;
  final DateTime syncedAt;

  String get displayName =>
      [manufacturer, model].where((s) => s != null && s.isNotEmpty).join(' ');

  bool get isCalExpired =>
      calDate != null && calDate!.isBefore(DateTime.now());
}
```

- [ ] **Step 2: Update model**

Replace entire `lib/features/certification/data/models/test_equipment_asset_model.dart`:

```dart
import '../../domain/entities/test_equipment_asset.dart';

class TestEquipmentAssetModel extends TestEquipmentAsset {
  const TestEquipmentAssetModel({
    required super.id,
    required super.assetId,
    super.equipmentType,
    super.manufacturer,
    super.model,
    super.serialNo,
    super.calDate,
    required super.syncedAt,
  });

  factory TestEquipmentAssetModel.fromJson(Map<String, dynamic> j) =>
      TestEquipmentAssetModel(
        id: 0,
        assetId: j['asset_id'] as int,
        equipmentType: j['equipment_type'] as String?,
        manufacturer: j['manufacturer'] as String?,
        model: j['model'] as String?,
        serialNo: j['serial_no'] as String?,
        calDate: j['cal_date'] != null
            ? DateTime.tryParse(j['cal_date'] as String)
            : null,
        syncedAt: DateTime.now(),
      );

  factory TestEquipmentAssetModel.fromMap(Map<String, dynamic> m) =>
      TestEquipmentAssetModel(
        id: m['id'] as int,
        assetId: m['asset_id'] as int,
        equipmentType: m['equipment_type'] as String?,
        manufacturer: m['manufacturer'] as String?,
        model: m['model'] as String?,
        serialNo: m['serial_no'] as String?,
        calDate: m['cal_date'] != null
            ? DateTime.tryParse(m['cal_date'] as String)
            : null,
        syncedAt: DateTime.parse(m['synced_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        if (id != 0) 'id': id,
        'asset_id': assetId,
        'equipment_type': equipmentType,
        'manufacturer': manufacturer,
        'model': model,
        'serial_no': serialNo,
        'cal_date': calDate?.toIso8601String().substring(0, 10),
        'synced_at': syncedAt.toIso8601String(),
      };
}
```

- [ ] **Step 3: Analyze**

```
flutter analyze lib/features/certification/domain/entities/test_equipment_asset.dart lib/features/certification/data/models/test_equipment_asset_model.dart
```
Expected: no issues.

- [ ] **Step 4: Commit**

```
git add lib/features/certification/domain/entities/test_equipment_asset.dart lib/features/certification/data/models/test_equipment_asset_model.dart
git commit -m "feat(cert): add equipmentType and DateTime calDate to TestEquipmentAsset"
```

---

## Task 4: Update TestEquipmentSelection Entity

**Files:**
- Modify: `lib/features/certification/domain/entities/test_equipment_selection.dart`

- [ ] **Step 1: Replace entire file**

```dart
// lib/features/certification/domain/entities/test_equipment_selection.dart
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'test_equipment_asset.dart';

@immutable
class TestEquipmentSelection {
  const TestEquipmentSelection({
    required this.assetId,
    this.equipmentType,
    this.manufacturer,
    this.model,
    this.serialNo,
    this.calDate,
  });

  factory TestEquipmentSelection.fromAsset(TestEquipmentAsset a) =>
      TestEquipmentSelection(
        assetId: a.assetId,
        equipmentType: a.equipmentType,
        manufacturer: a.manufacturer,
        model: a.model,
        serialNo: a.serialNo,
        calDate: a.calDate,
      );

  final int assetId;
  final String? equipmentType;
  final String? manufacturer;
  final String? model;
  final String? serialNo;
  final DateTime? calDate;

  bool get isCalExpired =>
      calDate != null && calDate!.isBefore(DateTime.now());

  String get displayName =>
      [manufacturer, model].where((s) => s != null && s.isNotEmpty).join(' ');

  String get subtitleText {
    final parts = <String>[];
    if (serialNo != null && serialNo!.isNotEmpty) parts.add('S/N: $serialNo');
    if (calDate != null) {
      parts.add('Next Cal: ${DateFormat('dd MMM yyyy').format(calDate!)}');
    }
    return parts.join(' · ');
  }
}
```

- [ ] **Step 2: Analyze**

```
flutter analyze lib/features/certification/domain/entities/test_equipment_selection.dart
```
Expected: no issues.

- [ ] **Step 3: Commit**

```
git add lib/features/certification/domain/entities/test_equipment_selection.dart
git commit -m "feat(cert): add equipmentType, DateTime calDate, isCalExpired, Next Cal label to TestEquipmentSelection"
```

---

## Task 5: Update TestCertificate Entity + Model

**Files:**
- Modify: `lib/features/certification/domain/entities/test_certificate.dart`
- Modify: `lib/features/certification/data/models/test_certificate_model.dart`

- [ ] **Step 1: Add `pmTaskDescription` to entity**

In `lib/features/certification/domain/entities/test_certificate.dart`, add `this.pmTaskDescription` to the constructor and field list:

```dart
// Add to constructor named params (after certName):
this.pmTaskDescription,

// Add field (after certName):
final String? pmTaskDescription;
```

The full updated constructor signature:
```dart
const TestCertificate({
  required this.id,
  required this.certType,
  required this.syncStatus,
  required this.createdAt,
  this.serverId,
  this.assetId,
  this.testDate,
  this.templateNameId,
  this.technician,
  this.technicianId,
  this.nextService,
  this.woNumber,
  this.jobcardNo,
  this.docNo,
  this.serviceInterval,
  this.serviceType,
  this.techSignature,
  this.clientSignature,
  this.clientName,
  this.notes,
  this.patientSafe,
  this.certName,
  this.pmTaskDescription,
});
```

- [ ] **Step 2: Update TestCertificateModel**

In `lib/features/certification/data/models/test_certificate_model.dart`:

Add `super.pmTaskDescription` to the `TestCertificateModel` constructor params (after `super.certName`).

In `fromMap`, add after `certName: m['cert_name'] as String?,`:
```dart
pmTaskDescription: m['pm_task_description'] as String?,
```

In `toMap()`, add after `'cert_name': certName,`:
```dart
'pm_task_description': pmTaskDescription,
```

- [ ] **Step 3: Analyze**

```
flutter analyze lib/features/certification/domain/entities/test_certificate.dart lib/features/certification/data/models/test_certificate_model.dart
```
Expected: no issues.

- [ ] **Step 4: Commit**

```
git add lib/features/certification/domain/entities/test_certificate.dart lib/features/certification/data/models/test_certificate_model.dart
git commit -m "feat(cert): add pmTaskDescription to TestCertificate"
```

---

## Task 6: Update CertLocalDataSource — PM Task Methods + Equipment Serialization

**Files:**
- Modify: `lib/features/certification/data/datasources/cert_local_data_source.dart`
- Modify: `lib/features/certification/data/models/certificate_summary.dart`

- [ ] **Step 1: Add import to cert_local_data_source.dart**

Add at top (after existing imports):
```dart
import '../../domain/entities/asset_pm_task.dart';
import '../models/asset_pm_task_model.dart';
```

- [ ] **Step 2: Add abstract methods to `CertLocalDataSource` interface**

Add after `getEquipmentForCert`:
```dart
/// Full-replace upsert of PM tasks from server sync.
Future<void> upsertAssetPmTasks(List<AssetPmTaskModel> tasks);

/// Returns active PM tasks for [assetId], ordered by description.
Future<List<AssetPmTask>> getAssetPmTasks(int assetId);
```

- [ ] **Step 3: Fix `saveEquipmentSelections` to include equipment_type and DateTime calDate**

Replace the `saveEquipmentSelections` implementation in `CertLocalDataSourceImpl`:

```dart
@override
Future<void> saveEquipmentSelections(
    int certId, List<TestEquipmentSelection> equipment) async {
  if (equipment.isEmpty) return;
  final db = await _db.database;
  final batch = db.batch();
  for (var i = 0; i < equipment.length; i++) {
    final e = equipment[i];
    batch.insert(
      'test_cert_equipment',
      {
        'certificate_id': certId,
        'slot_no': i + 1,
        'asset_id': e.assetId,
        'equipment_type': e.equipmentType,
        'manufacturer': e.manufacturer,
        'model': e.model,
        'serial_no': e.serialNo,
        'cal_date': e.calDate?.toIso8601String().substring(0, 10),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  await batch.commit(noResult: true);
}
```

- [ ] **Step 4: Fix `getEquipmentForCert` to restore equipment_type and DateTime calDate**

Replace the `getEquipmentForCert` implementation:

```dart
@override
Future<List<TestEquipmentSelection>> getEquipmentForCert(int certId) async {
  final db = await _db.database;
  final rows = await db.query(
    'test_cert_equipment',
    where: 'certificate_id = ?',
    whereArgs: [certId],
    orderBy: 'slot_no ASC',
  );
  return rows
      .map((r) => TestEquipmentSelection(
            assetId: r['asset_id'] as int,
            equipmentType: r['equipment_type'] as String?,
            manufacturer: r['manufacturer'] as String?,
            model: r['model'] as String?,
            serialNo: r['serial_no'] as String?,
            calDate: r['cal_date'] != null
                ? DateTime.tryParse(r['cal_date'] as String)
                : null,
          ))
      .toList();
}
```

- [ ] **Step 5: Add `upsertAssetPmTasks` and `getAssetPmTasks` implementations**

Add at the end of `CertLocalDataSourceImpl` (before the closing `}`):

```dart
@override
Future<void> upsertAssetPmTasks(List<AssetPmTaskModel> tasks) async {
  final db = await _db.database;
  await db.transaction((txn) async {
    await txn.delete('asset_pm_tasks');
    if (tasks.isEmpty) return;
    final batch = txn.batch();
    for (final t in tasks) {
      batch.insert('asset_pm_tasks', t.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  });
}

@override
Future<List<AssetPmTask>> getAssetPmTasks(int assetId) async {
  final db = await _db.database;
  final rows = await db.query(
    'asset_pm_tasks',
    where: 'asset_id = ? AND active = 1',
    whereArgs: [assetId],
    orderBy: 'description ASC',
  );
  return rows.map(AssetPmTaskModel.fromMap).toList();
}
```

- [ ] **Step 6: Add `pm_task_description` to `_certSummarySelect` and `CertificateSummary`**

In `cert_local_data_source.dart`, update `_certSummarySelect` to add `tc.pm_task_description`:

```dart
static const _certSummarySelect = '''
  SELECT
    tc.id,
    tc.server_id AS certificate_no,
    tc.cert_type,
    tc.sync_status,
    tc.created_at,
    tc.patient_safe,
    tc.template_name_id,
    tc.pm_task_description,
    COALESCE(
      tn1.test_template_cert_name,
      tn2.test_template_cert_name,
      tc.cert_name
    ) AS cert_name,
    COALESCE(tn1.test_template_name, tn2.test_template_name) AS template_name,
    a.equipment_type
  FROM test_certificates tc
  LEFT JOIN test_template_names tn1 ON tn1.id = tc.template_name_id
  LEFT JOIN test_template_names tn2 ON tn2.id = tc.cert_type
  LEFT JOIN assets a ON a.asset_id = tc.asset_id
''';
```

In `lib/features/certification/data/models/certificate_summary.dart`, add `pmTaskDescription`:

```dart
// Add to constructor:
this.pmTaskDescription,

// Add field after templateNameId:
final String? pmTaskDescription;
```

Update `fromMap`:
```dart
pmTaskDescription: m['pm_task_description'] as String?,
```

- [ ] **Step 7: Analyze**

```
flutter analyze lib/features/certification/data/datasources/cert_local_data_source.dart lib/features/certification/data/models/certificate_summary.dart
```
Expected: no issues.

- [ ] **Step 8: Commit**

```
git add lib/features/certification/data/datasources/cert_local_data_source.dart lib/features/certification/data/models/certificate_summary.dart lib/features/certification/data/models/asset_pm_task_model.dart lib/features/certification/domain/entities/asset_pm_task.dart
git commit -m "feat(cert): PM task local data source methods; fix equipment_type + DateTime calDate serialization"
```

---

## Task 7: Update CertRemoteDataSource + CertificateRepository

**Files:**
- Modify: `lib/features/certification/data/datasources/cert_remote_data_source.dart`
- Modify: `lib/features/certification/domain/repositories/certificate_repository.dart`
- Modify: `lib/features/certification/data/repositories/certificate_repository_impl.dart`

- [ ] **Step 1: Add import to cert_remote_data_source.dart**

Add after existing imports:
```dart
import '../models/asset_pm_task_model.dart';
```

- [ ] **Step 2: Add `fetchAssetPmTasks` to the abstract interface**

Add to `CertRemoteDataSource` interface (after `fetchTestEquipmentAssets`):
```dart
/// GET /assets/pm-tasks — full list of active PM tasks.
Future<List<AssetPmTaskModel>> fetchAssetPmTasks();
```

- [ ] **Step 3: Implement `fetchAssetPmTasks` in `CertRemoteDataSourceImpl`**

Add after `fetchTestEquipmentAssets` implementation:
```dart
@override
Future<List<AssetPmTaskModel>> fetchAssetPmTasks() async {
  final response = await _dio.get('/assets/pm-tasks');
  final data = ((response.data['data'] as List?) ?? [])
      .cast<Map<String, dynamic>>();
  return data.map(AssetPmTaskModel.fromJson).toList();
}
```

- [ ] **Step 4: Add `syncAssetPmTasks` to repository interface**

In `lib/features/certification/domain/repositories/certificate_repository.dart`, add after `syncTestEquipmentAssets`:
```dart
/// Fetches PM task list from the server and full-replaces locally.
/// Returns the number of tasks synced.
Future<int> syncAssetPmTasks();
```

- [ ] **Step 5: Implement `syncAssetPmTasks` in repository impl**

In `lib/features/certification/data/repositories/certificate_repository_impl.dart`, add after `syncTestEquipmentAssets`:
```dart
@override
Future<int> syncAssetPmTasks() async {
  final tasks = await remote.fetchAssetPmTasks();
  await local.upsertAssetPmTasks(tasks);
  return tasks.length;
}
```

- [ ] **Step 6: Add `pmTaskDescription` to push payload**

In `_pushSingleCertificate`, add `'pm_task_description': cert.pmTaskDescription,` to the payload map (after `'notes': cert.notes,`).

Also update the `cal_date` field in `test_equipment` map (calDate is now DateTime?):
```dart
'cal_date': e.calDate?.toIso8601String().substring(0, 10),
```

- [ ] **Step 7: Update `issueCertificate` to pass pmTaskDescription**

In `issueCertificate`, update the `TestCertificateModel(...)` constructor call — add after `certName: cert.certName,`:
```dart
pmTaskDescription: cert.pmTaskDescription,
```

- [ ] **Step 8: Analyze**

```
flutter analyze lib/features/certification/data/datasources/cert_remote_data_source.dart lib/features/certification/domain/repositories/certificate_repository.dart lib/features/certification/data/repositories/certificate_repository_impl.dart
```
Expected: no issues.

- [ ] **Step 9: Commit**

```
git add lib/features/certification/data/datasources/cert_remote_data_source.dart lib/features/certification/domain/repositories/certificate_repository.dart lib/features/certification/data/repositories/certificate_repository_impl.dart
git commit -m "feat(cert): fetchAssetPmTasks remote; syncAssetPmTasks repo; pmTaskDescription in push payload"
```

---

## Task 8: Sync Pipeline — PM Tasks Step

**Files:**
- Modify: `lib/sync/sync_notifier.dart`

- [ ] **Step 1: Add PM tasks sync step**

In `sync_notifier.dart`, add a new step after the `sync_test_equipment` block (around line 162) and before the `SyncInProgress(progress: 0.80 ...)` line.

Replace the line:
```dart
state = const SyncInProgress(progress: 0.80, message: 'Uploading certificates...');
```

With:
```dart
// PM task sync (~75%)
state = const SyncInProgress(progress: 0.75, message: 'Syncing PM tasks…');
try {
  final pmCount =
      await ref.read(certificateRepositoryProvider).syncAssetPmTasks();
  await syncRemote.postSyncLog(
    operation: 'sync_pm_tasks',
    entity: 'asset_pm_tasks',
    rowCount: pmCount,
    status: 'success',
    message: 'Synced $pmCount PM tasks',
  );
  await errorLog.markResolved('sync_pm_tasks');
} on Exception catch (e, st) {
  await errorLog.logError(
    operation: 'sync_pm_tasks',
    entityTable: 'asset_pm_tasks',
    errorMessage: e.toString(),
    stackTrace: st.toString(),
  );
  await syncRemote.postSyncLog(
    operation: 'sync_pm_tasks',
    entity: 'asset_pm_tasks',
    rowCount: 0,
    status: 'error',
    message: e.toString(),
  );
}

state = const SyncInProgress(progress: 0.80, message: 'Uploading certificates...');
```

- [ ] **Step 2: Analyze**

```
flutter analyze lib/sync/sync_notifier.dart
```
Expected: no issues.

- [ ] **Step 3: Commit**

```
git add lib/sync/sync_notifier.dart
git commit -m "feat(sync): add sync_pm_tasks step to pipeline"
```

---

## Task 9: Riverpod Provider + build_runner

**Files:**
- Modify: `lib/features/certification/presentation/providers/certificate_providers.dart`
- Regenerate: `lib/features/certification/presentation/providers/certificate_providers.g.dart`

- [ ] **Step 1: Add `assetPmTasksProvider`**

In `certificate_providers.dart`, add after `testEquipmentAssetsProvider`:

```dart
@riverpod
Future<List<AssetPmTask>> assetPmTasks(Ref ref, int assetId) =>
    ref.watch(certLocalDataSourceProvider).getAssetPmTasks(assetId);
```

Add the import at the top:
```dart
import '../../domain/entities/asset_pm_task.dart';
```

- [ ] **Step 2: Run build_runner**

```
dart run build_runner build --delete-conflicting-outputs
```
Expected: `certificate_providers.g.dart` regenerated. The SDK version warning (`3.11.0 > analyzer 3.9.0`) is harmless — ignore it.

- [ ] **Step 3: Analyze**

```
flutter analyze lib/features/certification/presentation/providers/
```
Expected: no issues.

- [ ] **Step 4: Commit**

```
git add lib/features/certification/presentation/providers/certificate_providers.dart lib/features/certification/presentation/providers/certificate_providers.g.dart
git commit -m "feat(cert): add assetPmTasksProvider"
```

---

## Task 10: CertDetailsStep — PM Task Card + Signature Changes

**Files:**
- Modify: `lib/features/certification/presentation/widgets/cert_details_step.dart`

- [ ] **Step 1: Add import for Asset entity**

Add at top of `cert_details_step.dart`:
```dart
import '../../../assets/domain/entities/asset.dart';
import '../../domain/entities/asset_pm_task.dart';
import '../providers/certificate_providers.dart';
```

- [ ] **Step 2: Update `CertDetailsStep` widget signature**

Add `selectedAsset` param and update `onChanged` signature:

```dart
class CertDetailsStep extends ConsumerStatefulWidget {
  const CertDetailsStep({
    super.key,
    required this.template,
    required this.selectedAsset,
    required this.initialDate,
    required this.initialEquipment,
    required this.onChanged,
    required this.onNext,
  });

  final TestTemplateName template;
  final Asset? selectedAsset;
  final DateTime initialDate;
  final List<TestEquipmentSelection?> initialEquipment;
  final void Function(
    DateTime testDate,
    List<TestEquipmentSelection?> equipment,
    String? pmTaskDescription,
  ) onChanged;
  final VoidCallback onNext;
```

- [ ] **Step 3: Update state class**

In `_CertDetailsStepState`, add `String? _pmTaskDescription;` alongside the other state fields.

Update `_notify()`:
```dart
void _notify() => widget.onChanged(_testDate, _equipment, _pmTaskDescription);
```

Update `_isValid` getter — it must also be satisfied when PM tasks are required. This is handled reactively in the `build` method (see Step 4), so `_isValid` only checks equipment:
```dart
bool get _isValid =>
    widget.template.testEquipQty == 0 ||
    (_equipment.length == widget.template.testEquipQty &&
        _equipment.every((e) => e != null));
```

- [ ] **Step 4: Add PM task card to `build`**

In `_CertDetailsStepState.build`, add the PM task card after the equipment card and before `const SizedBox(height: 24)`. The `FilledButton`'s `onPressed` must also check that a PM task is selected when tasks exist.

Replace the bottom section of `build` (from `const SizedBox(height: 24)` to end of column children) with:

```dart
const SizedBox(height: 12),
if (widget.selectedAsset?.assetId != null)
  _PmTaskCard(
    assetId: widget.selectedAsset!.assetId!,
    selected: _pmTaskDescription,
    onSelected: (desc) {
      setState(() => _pmTaskDescription = desc);
      _notify();
    },
  ),
const SizedBox(height: 24),
// Next button — built reactively to handle async PM task validity.
if (widget.selectedAsset?.assetId != null)
  _PmTaskNextButton(
    assetId: widget.selectedAsset!.assetId!,
    equipValid: _isValid,
    pmTaskDescription: _pmTaskDescription,
    onNext: widget.onNext,
  )
else
  FilledButton(
    onPressed: _isValid ? widget.onNext : null,
    child: Text(_isValid
        ? 'Next'
        : 'Select all test equipment to continue'),
  ),
```

- [ ] **Step 5: Add `_PmTaskCard` widget**

Add this new private widget at the bottom of the file (before `showTestEquipmentPicker`):

```dart
// ── PM task card ──────────────────────────────────────────────────────────────

class _PmTaskCard extends ConsumerWidget {
  const _PmTaskCard({
    required this.assetId,
    required this.selected,
    required this.onSelected,
  });

  final int assetId;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(assetPmTasksProvider(assetId));

    return tasksAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (tasks) {
        if (tasks.isEmpty) return const SizedBox.shrink();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PM Task',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: brandGrey)),
                const SizedBox(height: 8),
                if (tasks.length == 1)
                  _LockedPmTask(description: tasks.first.description)
                else
                  _PmTaskChips(
                    tasks: tasks,
                    selected: selected,
                    onSelected: onSelected,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LockedPmTask extends StatelessWidget {
  const _LockedPmTask({required this.description});
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F5),
        border: Border.all(color: const Color(0xFFDDE3EA)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 16, color: brandGrey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(description,
                style: const TextStyle(color: brandGrey)),
          ),
        ],
      ),
    );
  }
}

class _PmTaskChips extends StatelessWidget {
  const _PmTaskChips({
    required this.tasks,
    required this.selected,
    required this.onSelected,
  });

  final List<AssetPmTask> tasks;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: tasks.map((t) {
        final isSelected = selected == t.description;
        return ChoiceChip(
          label: Text(t.description),
          selected: isSelected,
          selectedColor: brandTeal.withAlpha(30),
          side: BorderSide(
            color: isSelected ? brandTeal : const Color(0xFFDDE3EA),
          ),
          labelStyle: TextStyle(
            color: isSelected ? brandTeal : null,
            fontWeight:
                isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
          onSelected: (_) => onSelected(t.description),
        );
      }).toList(),
    );
  }
}
```

- [ ] **Step 6: Add `_PmTaskNextButton` widget**

Add this widget at the bottom of the file:

```dart
// ── PM task-aware Next button ─────────────────────────────────────────────────

class _PmTaskNextButton extends ConsumerWidget {
  const _PmTaskNextButton({
    required this.assetId,
    required this.equipValid,
    required this.pmTaskDescription,
    required this.onNext,
  });

  final int assetId;
  final bool equipValid;
  final String? pmTaskDescription;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(assetPmTasksProvider(assetId));
    final hasTasks = tasksAsync.asData?.value.isNotEmpty ?? false;
    final pmValid = !hasTasks || pmTaskDescription != null;
    final canProceed = equipValid && pmValid;

    String label;
    if (!equipValid) {
      label = 'Select all test equipment to continue';
    } else if (!pmValid) {
      label = 'Select a PM task to continue';
    } else {
      label = 'Next';
    }

    return FilledButton(
      onPressed: canProceed ? onNext : null,
      child: Text(label),
    );
  }
}
```

- [ ] **Step 7: Auto-select single PM task**

In `_CertDetailsStepState`, add a listener that auto-selects when only one task exists. Add this inside `build`, right before the `return Padding(...)`:

```dart
// Auto-select single PM task when provider resolves.
if (widget.selectedAsset?.assetId != null) {
  ref.listen(assetPmTasksProvider(widget.selectedAsset!.assetId!),
      (_, next) {
    next.whenData((tasks) {
      if (tasks.length == 1 && _pmTaskDescription == null) {
        setState(() => _pmTaskDescription = tasks.first.description);
        _notify();
      }
    });
  });
}
```

- [ ] **Step 8: Analyze**

```
flutter analyze lib/features/certification/presentation/widgets/cert_details_step.dart
```
Expected: no issues.

- [ ] **Step 9: Commit**

```
git add lib/features/certification/presentation/widgets/cert_details_step.dart
git commit -m "feat(cert): add PM task selector to CertDetailsStep"
```

---

## Task 11: Wire CertDetailsStep in create_certificate_screen.dart

**Files:**
- Modify: `lib/features/certification/presentation/screens/create_certificate_screen.dart`

- [ ] **Step 1: Add `_pmTaskDescription` state field**

In `_CreateCertificateScreenState`, add alongside other fields:
```dart
String? _pmTaskDescription;
```

- [ ] **Step 2: Update `CertDetailsStep` call**

In the `// Step 3: certificate details` section, update the `CertDetailsStep(...)` widget call:

```dart
CertDetailsStep(
  template: _selectedTemplate!,
  selectedAsset: _selectedAsset,
  initialDate: _testDate,
  initialEquipment: _equipment,
  onChanged: (date, equip, pmTask) => setState(() {
    _testDate = date;
    _equipment = equip;
    _pmTaskDescription = pmTask;
  }),
  onNext: () => _goToStep(4),
)
```

- [ ] **Step 3: Pass `pmTaskDescription` to `TestCertificate` in `_saveCertificate`**

In `_saveCertificate`, add `pmTaskDescription: _pmTaskDescription,` to the `TestCertificate(...)` constructor call (after `certName: _selectedTemplate?.certName,`).

- [ ] **Step 4: Analyze**

```
flutter analyze lib/features/certification/presentation/screens/create_certificate_screen.dart
```
Expected: no issues.

- [ ] **Step 5: Commit**

```
git add lib/features/certification/presentation/screens/create_certificate_screen.dart
git commit -m "feat(cert): wire selectedAsset and pmTaskDescription through create_certificate_screen"
```

---

## Task 12: Test Equipment Picker — Expired UI

**Files:**
- Modify: `lib/features/certification/presentation/widgets/cert_details_step.dart`

- [ ] **Step 1: Update `_TestEquipmentPickerSheet` list tile**

In the `ListView.builder` itemBuilder inside `_TestEquipmentPickerSheet`, replace the existing `ListTile` with:

```dart
itemBuilder: (_, i) {
  final a = available[i];
  final expired = a.isCalExpired;
  final calText = a.calDate != null
      ? 'Next Cal: ${DateFormat('dd MMM yyyy').format(a.calDate!)}'
      : null;

  return ListTile(
    enabled: !expired,
    leading: Icon(
      Icons.biotech_outlined,
      color: expired ? const Color(0xFFC62828) : brandTeal,
    ),
    title: Text(
      a.equipmentType ?? a.displayName,
      style: TextStyle(
        color: expired ? const Color(0xFFC62828) : null,
        fontWeight: FontWeight.w500,
      ),
    ),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (a.displayName.isNotEmpty &&
            a.equipmentType != null)
          Text(a.displayName,
              style: TextStyle(
                  fontSize: 11,
                  color: expired
                      ? const Color(0xFFC62828)
                      : brandGrey)),
        if (a.serialNo != null)
          Text('S/N: ${a.serialNo}',
              style: TextStyle(
                  fontSize: 11,
                  color: expired
                      ? const Color(0xFFC62828)
                      : brandGrey)),
        if (calText != null)
          Text(calText,
              style: TextStyle(
                  fontSize: 11,
                  color: expired
                      ? const Color(0xFFC62828)
                      : brandGrey)),
      ],
    ),
    isThreeLine: true,
    trailing: expired
        ? Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFC62828).withAlpha(20),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFC62828)),
            ),
            child: const Text(
              'EXPIRED',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFFC62828),
              ),
            ),
          )
        : const Icon(Icons.chevron_right, size: 18),
    onTap: expired
        ? null
        : () => Navigator.of(context).pop(
              TestEquipmentSelection.fromAsset(a),
            ),
  );
},
```

Add `import 'package:intl/intl.dart';` if not already present at top of the file.

- [ ] **Step 2: Analyze**

```
flutter analyze lib/features/certification/presentation/widgets/cert_details_step.dart
```
Expected: no issues.

- [ ] **Step 3: Commit**

```
git add lib/features/certification/presentation/widgets/cert_details_step.dart
git commit -m "feat(cert): show equipment type, Next Cal label, red expired badge in test equipment picker"
```

---

## Task 13: Certificate Detail Screen — Show PM Task

**Files:**
- Modify: `lib/features/certification/presentation/screens/certificate_detail_screen.dart`

- [ ] **Step 1: Add PM task row to `_HeaderCard`**

In `_HeaderCard.build`, after the `equipmentType` block (lines ~344–351), add:

```dart
if (summary.pmTaskDescription != null) ...[
  const SizedBox(height: 4),
  Row(
    children: [
      Text('PM Task: ',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: brandGrey)),
      Text(summary.pmTaskDescription!,
          style: Theme.of(context).textTheme.bodySmall),
    ],
  ),
],
```

- [ ] **Step 2: Analyze**

```
flutter analyze lib/features/certification/presentation/screens/certificate_detail_screen.dart
```
Expected: no issues.

- [ ] **Step 3: Commit**

```
git add lib/features/certification/presentation/screens/certificate_detail_screen.dart
git commit -m "feat(cert): show PM task description in certificate detail header"
```

---

## Task 14: Full Flutter analyze + format

- [ ] **Step 1: Analyze entire project**

```
flutter analyze
```
Expected: no issues (warnings about deprecated APIs in dependencies are OK; errors in `lib/` are not).

- [ ] **Step 2: Format**

```
dart format lib/
```

- [ ] **Step 3: Commit if any formatting changes**

```
git add -u
git commit -m "style: dart format"
```

---

## Task 15: Horse API — GET /assets/pm-tasks

**Files:**
- Modify: `C:\Delphi\StatTracTechAPI\src\Assets.Routes.pas`

- [ ] **Step 1: Add procedure `RegisterPmTasksRoute`**

Open `Assets.Routes.pas` in RAD Studio. Add the following procedure before the `initialization` section (or alongside the existing asset routes registration):

```pascal
procedure RegisterPmTasksRoute(const App: THorse);
begin
  App.Get('/assets/pm-tasks',
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      Con: TUniConnection;
      Qry: TUniQuery;
      Data: TJSONArray;
      Item: TJSONObject;
      DateStr: string;
    begin
      Con := GetDBConnection;
      try
        Qry := TUniQuery.Create(nil);
        try
          Qry.Connection := Con;
          Qry.SQL.Text :=
            'SELECT "PmTaskID", "PmAssetID", "PmTaskDescription", ' +
            '"PmTaskScheduleDate", "PmTaskActive" ' +
            'FROM "AssetPmTask" ' +
            'WHERE "PmTaskActive" = 1 ' +
            'ORDER BY "PmAssetID", "PmTaskDescription"';
          Qry.Open;
          Data := TJSONArray.Create;
          while not Qry.Eof do
          begin
            Item := TJSONObject.Create;
            Item.AddPair('pm_task_id',
              TJSONNumber.Create(Qry.FieldByName('PmTaskID').AsInteger));
            Item.AddPair('asset_id',
              TJSONNumber.Create(Qry.FieldByName('PmAssetID').AsInteger));
            Item.AddPair('description',
              Qry.FieldByName('PmTaskDescription').AsString);
            if Qry.FieldByName('PmTaskScheduleDate').IsNull then
              Item.AddPair('schedule_date', TJSONNull.Create)
            else
            begin
              DateStr := FormatDateTime('yyyy-mm-dd',
                Qry.FieldByName('PmTaskScheduleDate').AsDateTime);
              Item.AddPair('schedule_date', DateStr);
            end;
            Item.AddPair('active',
              TJSONNumber.Create(Qry.FieldByName('PmTaskActive').AsInteger));
            Data.AddElement(Item);
            Qry.Next;
          end;
          Res.Send(TJSONObject.Create.AddPair('data', Data).ToJSON).Status(200);
        finally
          Qry.Free;
          Con.Free;
        end;
      except
        on E: Exception do
          Res.Send('{"error":"' + E.Message + '"}').Status(500);
      end;
    end
  );
end;
```

- [ ] **Step 2: Call `RegisterPmTasksRoute` in the initialization/registration section**

Find where other routes are registered (e.g. `RegisterAssetRoutes(App)`) and add:
```pascal
RegisterPmTasksRoute(App);
```

- [ ] **Step 3: Compile and run**

Press F9 in RAD Studio. Confirm no compile errors.

- [ ] **Step 4: Test endpoint**

```
curl -H "Authorization: Bearer <token>" http://localhost:9000/assets/pm-tasks
```
Expected: `{"data":[{"pm_task_id":7375,"asset_id":9333,"description":"Annual Service",...},...]}`

---

## Task 16: Horse API — Accept pm_task_description in POST /certificates

**Files:**
- Modify: `C:\Delphi\StatTracTechAPI\src\Certificates.Routes.pas`

**Prerequisite:** Run this in pgAdmin first:
```sql
ALTER TABLE "TestCertificate" ADD COLUMN "TestPmTaskDescription" VARCHAR(100);
```

- [ ] **Step 1: Read pm_task_description from request body**

In the POST `/certificates` handler, after reading other fields from the JSON body (e.g. `notes`, `patient_safe`), add:

```pascal
var
  PmTaskDesc: string;
...
PmTaskDesc := '';
if Body.TryGetValue<string>('pm_task_description', PmTaskDesc) then
  ; // PmTaskDesc now holds the value (empty string if null/missing)
```

- [ ] **Step 2: Insert into TestCertificate**

In the INSERT SQL for the new certificate, add `"TestPmTaskDescription"` to the column list and `:PmTaskDesc` to the VALUES. For example:

```pascal
Qry.SQL.Text :=
  'INSERT INTO "TestCertificate" (' +
  '"TestAssetID","TestCertType","TestTemplateNameID","TestTechID",' +
  '"TestDate","TestDocNo","TestPatientSafe","TestCertNote",' +
  '"TestPmTaskDescription"' +
  ') VALUES (' +
  ':AssetID,:CertType,:TemplateNameID,:TechID,' +
  ':TestDate,:DocNo,:PatientSafe,:Notes,' +
  ':PmTaskDesc' +
  ') RETURNING "TestCertificateID"';
...
Qry.ParamByName('PmTaskDesc').AsString := PmTaskDesc;
```

- [ ] **Step 3: Compile and run**

Press F9 in RAD Studio. Confirm no compile errors.

- [ ] **Step 4: Test**

Post a test certificate with `"pm_task_description": "Annual Service"` and verify the value appears in the `"TestCertificate"` table in pgAdmin.

---

## Done

All Flutter tasks are complete when `flutter analyze` reports no issues and `flutter test` passes. All Horse API tasks are complete when the endpoints respond correctly. The PM task selector, expired equipment blocking, and "Next Cal" display will be visible on next app run after a sync.
