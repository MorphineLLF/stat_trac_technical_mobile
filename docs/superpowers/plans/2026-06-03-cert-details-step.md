# Certificate Details Step Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Insert a new "Certificate Details" wizard step between template selection and the test grid, handling editable test date and test equipment selection (with `TestAnalyser` server-side persistence).

**Architecture:** Migration v11 adds `test_equipment_assets` and `test_cert_equipment` tables plus three columns to `test_template_names`. A new Horse API endpoint `GET /assets/test-equipment` returns slim records from `Asset JOIN AssetPmTask`. The new `CertDetailsStep` widget shows a conditional date picker and N equipment slots; selections persist locally before sync. `POST /certificates` is extended to insert `TestAnalyser` rows per equipment item in the same transaction.

**Tech Stack:** Flutter/Dart, Riverpod 3 (code-generated), sqflite, Delphi Horse API, PostgreSQL 12.

---

## File Map

| Action | Path |
|---|---|
| Create | `lib/database/migrations/migration_011_cert_details.dart` |
| Modify | `lib/database/database_helper.dart` |
| Modify | `lib/features/certification/domain/entities/test_template_name.dart` |
| Modify | `lib/features/certification/data/models/test_template_name_model.dart` |
| Create | `lib/features/certification/domain/entities/test_equipment_asset.dart` |
| Create | `lib/features/certification/data/models/test_equipment_asset_model.dart` |
| Create | `lib/features/certification/domain/entities/test_equipment_selection.dart` |
| Modify | `lib/features/certification/data/datasources/cert_local_data_source.dart` |
| Modify | `lib/features/certification/data/datasources/cert_remote_data_source.dart` |
| Modify | `lib/features/certification/domain/repositories/certificate_repository.dart` |
| Modify | `lib/features/certification/data/repositories/certificate_repository_impl.dart` |
| Modify | `lib/features/certification/presentation/providers/certificate_providers.dart` |
| Modify | `lib/sync/sync_notifier.dart` |
| Modify | `lib/features/dashboard/presentation/screens/dashboard_screen.dart` |
| Create | `lib/features/certification/presentation/widgets/cert_details_step.dart` |
| Modify | `lib/features/certification/presentation/screens/create_certificate_screen.dart` |
| Modify | `C:\Delphi\StatTracTechAPI\src\Assets.Routes.pas` |
| Modify | `C:\Delphi\StatTracTechAPI\src\Certificates.Routes.pas` |

---

## Task 1: Migration v11

**Files:**
- Create: `lib/database/migrations/migration_011_cert_details.dart`
- Modify: `lib/database/database_helper.dart`

- [ ] **Create migration file**

```dart
// lib/database/migrations/migration_011_cert_details.dart
import 'package:sqflite/sqflite.dart';

Future<void> migration011CertDetails(Database db) async {
  await db.execute('''
    CREATE TABLE test_equipment_assets (
      id        INTEGER PRIMARY KEY AUTOINCREMENT,
      asset_id  INTEGER NOT NULL UNIQUE,
      manufacturer TEXT,
      model        TEXT,
      serial_no    TEXT,
      cal_date     TEXT,
      synced_at    TEXT NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE test_cert_equipment (
      id             INTEGER PRIMARY KEY AUTOINCREMENT,
      certificate_id INTEGER NOT NULL,
      slot_no        INTEGER NOT NULL,
      asset_id       INTEGER NOT NULL,
      manufacturer   TEXT,
      model          TEXT,
      serial_no      TEXT,
      cal_date       TEXT
    )
  ''');

  await db.execute(
    'ALTER TABLE test_template_names ADD COLUMN test_template_edit_date INTEGER',
  );
  await db.execute(
    'ALTER TABLE test_template_names ADD COLUMN test_template_next_service INTEGER',
  );
  await db.execute(
    'ALTER TABLE test_template_names ADD COLUMN test_template_test_equip_qty INTEGER',
  );
}
```

- [ ] **Register migration in `database_helper.dart`**

Import the new migration at the top of the file (alongside existing migration imports):
```dart
import 'migrations/migration_011_cert_details.dart';
```

In `_onUpgrade`, add after the existing `case 10` block:
```dart
if (oldVersion < 11) await migration011CertDetails(db);
```

Change the `_kVersion` constant from `10` to `11`:
```dart
static const int _kVersion = 11;
```

- [ ] **Run `flutter analyze` — expect no errors**

```bash
flutter analyze
```

- [ ] **Commit**

```bash
git add lib/database/migrations/migration_011_cert_details.dart lib/database/database_helper.dart
git commit -m "feat(db): migration v11 — test_equipment_assets, test_cert_equipment, template flag columns"
```

---

## Task 2: TestTemplateName — three new fields

**Files:**
- Modify: `lib/features/certification/domain/entities/test_template_name.dart`
- Modify: `lib/features/certification/data/models/test_template_name_model.dart`

- [ ] **Add fields to entity**

In `test_template_name.dart`, update the constructor and add three fields:

```dart
const TestTemplateName({
  required this.id,
  required this.certType,
  this.templateName,
  this.certName,
  this.customerSigRequired = false,
  this.editDate = false,         // NEW
  this.nextService = false,      // NEW
  this.testEquipQty = 0,         // NEW
  this.docNo,
  this.note,
  this.lastSyncedAt,
});

final bool editDate;
final bool nextService;
final int testEquipQty;
```

- [ ] **Update model — `fromMap`**

In `TestTemplateNameModel.fromMap`, add after `customerSigRequired`:
```dart
editDate:  (m['test_template_edit_date']     as int? ?? 0) != 0,
nextService: (m['test_template_next_service'] as int? ?? 0) != 0,
testEquipQty: m['test_template_test_equip_qty'] as int? ?? 0,
```

- [ ] **Update model — `fromJson`**

In `TestTemplateNameModel.fromJson`, add after `customerSigRequired`:
```dart
editDate:   (j['edit_date']      as int? ?? 0) != 0,
nextService: (j['next_service']  as int? ?? 0) != 0,
testEquipQty: j['test_equip_qty'] as int? ?? 0,
```

- [ ] **Update model — `toMap`**

In `TestTemplateNameModel.toMap()`, add:
```dart
'test_template_edit_date':     editDate ? 1 : 0,
'test_template_next_service':  nextService ? 1 : 0,
'test_template_test_equip_qty': testEquipQty,
```

- [ ] **Run `flutter analyze` — expect no errors**

- [ ] **Commit**

```bash
git add lib/features/certification/domain/entities/test_template_name.dart \
        lib/features/certification/data/models/test_template_name_model.dart
git commit -m "feat(cert): add editDate, nextService, testEquipQty to TestTemplateName"
```

---

## Task 3: TestEquipmentAsset entity and model

**Files:**
- Create: `lib/features/certification/domain/entities/test_equipment_asset.dart`
- Create: `lib/features/certification/data/models/test_equipment_asset_model.dart`

- [ ] **Create entity**

```dart
// lib/features/certification/domain/entities/test_equipment_asset.dart
import 'package:flutter/foundation.dart';

@immutable
class TestEquipmentAsset {
  const TestEquipmentAsset({
    required this.id,
    required this.assetId,
    this.manufacturer,
    this.model,
    this.serialNo,
    this.calDate,
    required this.syncedAt,
  });

  final int id;
  final int assetId;
  final String? manufacturer;
  final String? model;
  final String? serialNo;
  final String? calDate;
  final DateTime syncedAt;

  String get displayName =>
      [manufacturer, model].where((s) => s != null && s!.isNotEmpty).join(' ');
}
```

- [ ] **Create model**

```dart
// lib/features/certification/data/models/test_equipment_asset_model.dart
import '../../domain/entities/test_equipment_asset.dart';

class TestEquipmentAssetModel extends TestEquipmentAsset {
  const TestEquipmentAssetModel({
    required super.id,
    required super.assetId,
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
        manufacturer: j['manufacturer'] as String?,
        model: j['model'] as String?,
        serialNo: j['serial_no'] as String?,
        calDate: j['cal_date'] as String?,
        syncedAt: DateTime.now(),
      );

  factory TestEquipmentAssetModel.fromMap(Map<String, dynamic> m) =>
      TestEquipmentAssetModel(
        id: m['id'] as int,
        assetId: m['asset_id'] as int,
        manufacturer: m['manufacturer'] as String?,
        model: m['model'] as String?,
        serialNo: m['serial_no'] as String?,
        calDate: m['cal_date'] as String?,
        syncedAt: DateTime.parse(m['synced_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        if (id != 0) 'id': id,
        'asset_id': assetId,
        'manufacturer': manufacturer,
        'model': model,
        'serial_no': serialNo,
        'cal_date': calDate,
        'synced_at': syncedAt.toIso8601String(),
      };
}
```

- [ ] **Run `flutter analyze` — expect no errors**

- [ ] **Commit**

```bash
git add lib/features/certification/domain/entities/test_equipment_asset.dart \
        lib/features/certification/data/models/test_equipment_asset_model.dart
git commit -m "feat(cert): add TestEquipmentAsset entity and model"
```

---

## Task 4: TestEquipmentSelection data class

**Files:**
- Create: `lib/features/certification/domain/entities/test_equipment_selection.dart`

- [ ] **Create file**

```dart
// lib/features/certification/domain/entities/test_equipment_selection.dart
import 'package:flutter/foundation.dart';

import 'test_equipment_asset.dart';

@immutable
class TestEquipmentSelection {
  const TestEquipmentSelection({
    required this.assetId,
    this.manufacturer,
    this.model,
    this.serialNo,
    this.calDate,
  });

  factory TestEquipmentSelection.fromAsset(TestEquipmentAsset a) =>
      TestEquipmentSelection(
        assetId: a.assetId,
        manufacturer: a.manufacturer,
        model: a.model,
        serialNo: a.serialNo,
        calDate: a.calDate,
      );

  final int assetId;
  final String? manufacturer;
  final String? model;
  final String? serialNo;
  final String? calDate;

  String get displayName =>
      [manufacturer, model].where((s) => s != null && s!.isNotEmpty).join(' ');

  String get subtitleText {
    final parts = <String>[];
    if (serialNo != null && serialNo!.isNotEmpty) parts.add('S/N: $serialNo');
    if (calDate != null && calDate!.isNotEmpty) parts.add('Cal: $calDate');
    return parts.join(' · ');
  }
}
```

- [ ] **Run `flutter analyze` — expect no errors**

- [ ] **Commit**

```bash
git add lib/features/certification/domain/entities/test_equipment_selection.dart
git commit -m "feat(cert): add TestEquipmentSelection data class"
```

---

## Task 5: CertLocalDataSource — new methods

**Files:**
- Modify: `lib/features/certification/data/datasources/cert_local_data_source.dart`

- [ ] **Add imports at top of file**

```dart
import '../models/test_equipment_asset_model.dart';
import '../../domain/entities/test_equipment_asset.dart';
import '../../domain/entities/test_equipment_selection.dart';
```

- [ ] **Add to `CertLocalDataSource` interface** (after the existing `hasCertsWithNullCertName` method):

```dart
/// Full-replace upsert of test equipment assets from server sync.
Future<void> upsertTestEquipmentAssets(List<TestEquipmentAssetModel> assets);

/// Returns all test equipment assets ordered by manufacturer.
Future<List<TestEquipmentAsset>> getTestEquipmentAssets();

/// Saves equipment selections to test_cert_equipment for [certId].
Future<void> saveEquipmentSelections(
    int certId, List<TestEquipmentSelection> equipment);

/// Returns equipment selections for [certId] ordered by slot_no.
Future<List<TestEquipmentSelection>> getEquipmentForCert(int certId);
```

- [ ] **Add implementations to `CertLocalDataSourceImpl`** (at the end of the class):

```dart
@override
Future<void> upsertTestEquipmentAssets(
    List<TestEquipmentAssetModel> assets) async {
  final db = await _db.database;
  await db.delete('test_equipment_assets');
  if (assets.isEmpty) return;
  final batch = db.batch();
  for (final a in assets) {
    batch.insert('test_equipment_assets', a.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
  await batch.commit(noResult: true);
}

@override
Future<List<TestEquipmentAsset>> getTestEquipmentAssets() async {
  final db = await _db.database;
  final rows = await db.query(
    'test_equipment_assets',
    orderBy: 'manufacturer ASC',
  );
  return rows.map(TestEquipmentAssetModel.fromMap).toList();
}

@override
Future<void> saveEquipmentSelections(
    int certId, List<TestEquipmentSelection> equipment) async {
  if (equipment.isEmpty) return;
  final db = await _db.database;
  final batch = db.batch();
  for (var i = 0; i < equipment.length; i++) {
    final e = equipment[i];
    batch.insert('test_cert_equipment', {
      'certificate_id': certId,
      'slot_no': i + 1,
      'asset_id': e.assetId,
      'manufacturer': e.manufacturer,
      'model': e.model,
      'serial_no': e.serialNo,
      'cal_date': e.calDate,
    });
  }
  await batch.commit(noResult: true);
}

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
            manufacturer: r['manufacturer'] as String?,
            model: r['model'] as String?,
            serialNo: r['serial_no'] as String?,
            calDate: r['cal_date'] as String?,
          ))
      .toList();
}
```

- [ ] **Run `flutter analyze` — expect no errors**

- [ ] **Commit**

```bash
git add lib/features/certification/data/datasources/cert_local_data_source.dart
git commit -m "feat(cert): add test equipment CRUD to CertLocalDataSource"
```

---

## Task 6: CertRemoteDataSource and new provider

**Files:**
- Modify: `lib/features/certification/data/datasources/cert_remote_data_source.dart`
- Modify: `lib/features/certification/presentation/providers/certificate_providers.dart`

- [ ] **Add import to remote data source**

```dart
import '../models/test_equipment_asset_model.dart';
```

- [ ] **Add to `CertRemoteDataSource` interface**:

```dart
/// GET /assets/test-equipment
Future<List<TestEquipmentAssetModel>> fetchTestEquipmentAssets();
```

- [ ] **Add implementation to `CertRemoteDataSourceImpl`**:

```dart
@override
Future<List<TestEquipmentAssetModel>> fetchTestEquipmentAssets() async {
  final response = await _dio.get('/assets/test-equipment');
  final data = ((response.data['data'] as List?) ?? [])
      .cast<Map<String, dynamic>>();
  return data.map(TestEquipmentAssetModel.fromJson).toList();
}
```

- [ ] **Add provider to `certificate_providers.dart`**

Add import at top:
```dart
import '../../domain/entities/test_equipment_asset.dart';
```

Add provider after `certOutputs`:
```dart
@riverpod
Future<List<TestEquipmentAsset>> testEquipmentAssets(Ref ref) =>
    ref.watch(certLocalDataSourceProvider).getTestEquipmentAssets();
```

- [ ] **Run build_runner to regenerate providers**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: `certificate_providers.g.dart` regenerated with `testEquipmentAssetsProvider`.

- [ ] **Run `flutter analyze` — expect no errors**

- [ ] **Commit**

```bash
git add lib/features/certification/data/datasources/cert_remote_data_source.dart \
        lib/features/certification/presentation/providers/certificate_providers.dart \
        lib/features/certification/presentation/providers/certificate_providers.g.dart
git commit -m "feat(cert): add fetchTestEquipmentAssets remote method and provider"
```

---

## Task 7: CertificateRepository — extend interface and implementation

**Files:**
- Modify: `lib/features/certification/domain/repositories/certificate_repository.dart`
- Modify: `lib/features/certification/data/repositories/certificate_repository_impl.dart`

- [ ] **Add imports to repository impl**

```dart
import '../../domain/entities/test_equipment_selection.dart';
```

- [ ] **Update `CertificateRepository` interface**

Change `issueCertificate` signature and add `syncTestEquipmentAssets`:
```dart
Future<int> issueCertificate({
  required TestCertificate cert,
  required List<TestOutput> outputs,
  List<TestEquipmentSelection> equipment = const [],
});

Future<int> syncTestEquipmentAssets();
```

- [ ] **Update `issueCertificate` in `CertificateRepositoryImpl`**

Change the signature to match:
```dart
@override
Future<int> issueCertificate({
  required TestCertificate cert,
  required List<TestOutput> outputs,
  List<TestEquipmentSelection> equipment = const [],
}) async {
```

At the end of the method, after `await local.saveOutputs(outputModels)`:
```dart
  await local.saveEquipmentSelections(certId, equipment);
  return certId;
```

- [ ] **Add `syncTestEquipmentAssets` to `CertificateRepositoryImpl`**

```dart
@override
Future<int> syncTestEquipmentAssets() async {
  final assets = await remote.fetchTestEquipmentAssets();
  await local.upsertTestEquipmentAssets(assets);
  return assets.length;
}
```

- [ ] **Extend `_pushSingleCertificate` to include equipment**

In `_pushSingleCertificate`, before the `final payload = {` line, fetch equipment:
```dart
final equipment = await local.getEquipmentForCert(cert.id);
```

Add to the payload map (after `'notes': cert.notes`):
```dart
'test_equipment': equipment
    .map((e) => {
          'asset_id': e.assetId,
          'serial_no': e.serialNo,
          'model': e.model,
          'manufacturer': e.manufacturer,
          'cal_date': e.calDate,
        })
    .toList(),
```

- [ ] **Run `flutter analyze` — expect no errors**

- [ ] **Commit**

```bash
git add lib/features/certification/domain/repositories/certificate_repository.dart \
        lib/features/certification/data/repositories/certificate_repository_impl.dart
git commit -m "feat(cert): extend issueCertificate with equipment, add syncTestEquipmentAssets"
```

---

## Task 8: SyncNotifier — test equipment sync step

**Files:**
- Modify: `lib/sync/sync_notifier.dart`
- Modify: `lib/features/dashboard/presentation/screens/dashboard_screen.dart`

- [ ] **Add test equipment sync step to `triggerSync()`**

In `sync_notifier.dart`, locate the template sync block (step 5, ~65%). After it completes and before pushing certificates, insert:

```dart
// Step 5.5 — test equipment assets (~68%)
state = const SyncInProgress(0.68, 'Syncing test equipment…');
try {
  final equipCount = await certRepo.syncTestEquipmentAssets();
  await _syncRemote.postSyncLog(
    operation: 'sync_test_equipment',
    entity: 'test_equipment_assets',
    rowCount: equipCount,
    status: 'success',
    message: 'Synced $equipCount test equipment assets',
  );
  await _errorLog.markResolved('sync_test_equipment');
} catch (e) {
  await _errorLog.logError(SyncErrorEntry(
    operation: 'sync_test_equipment',
    entityTable: 'test_equipment_assets',
    entityId: '0',
    errorMessage: _friendlySyncError(e),
    stackTrace: '',
    occurredAt: DateTime.now(),
    resolved: false,
  ));
  await _syncRemote.postSyncLog(
    operation: 'sync_test_equipment',
    entity: 'test_equipment_assets',
    rowCount: 0,
    status: 'error',
    message: _friendlySyncError(e),
  );
}
```

- [ ] **Add label to `_SyncErrorSheet._labels` in `dashboard_screen.dart`**

```dart
static const _labels = <String, String>{
  'sync_assets':        'Asset sync failed',
  'sync_templates':     'Template sync failed',
  'sync_test_equipment': 'Test equipment sync failed',   // ADD
  'push_certificates':  'Certificate upload failed',
  'pull_certificates':  'Certificate download failed',
};
```

- [ ] **Run `flutter analyze` — expect no errors**

- [ ] **Commit**

```bash
git add lib/sync/sync_notifier.dart \
        lib/features/dashboard/presentation/screens/dashboard_screen.dart
git commit -m "feat(sync): add test equipment asset sync step to pipeline"
```

---

## Task 9: Horse API — GET /assets/test-equipment

**Files:**
- Modify: `C:\Delphi\StatTracTechAPI\src\Assets.Routes.pas`

- [ ] **Add the new route inside `RegisterAssetRoutes`**

Add this block after the existing `GET /assets` route:

```delphi
// ── GET /assets/test-equipment ────────────────────────────────────────────────
// Returns slim test equipment records: Asset JOIN AssetPmTask WHERE AssetTestEquipment=1
THorse
  .AddCallback(HorseJWT(JWT_SECRET))
  .Get('/assets/test-equipment',
    procedure(Req: THorseRequest; Res: THorseResponse)
    var
      LConn: TUniConnection;
      LQuery: TUniQuery;
      LData: TJSONArray;
      LRow: TJSONObject;
      LResponse: TJSONObject;
    begin
      if ExtractDbName(Req).IsEmpty then
      begin
        Res.Status(THTTPStatus.Unauthorized).Send('Missing db claim');
        Exit;
      end;

      LConn := NewDBConnection(ExtractDbName(Req));
      try
        LQuery := TUniQuery.Create(nil);
        try
          LQuery.Connection := LConn;
          LQuery.SQL.Text :=
            'SELECT "AssetID", "AssetManufacturer", "AssetModel", ' +
            '       "AssetSerialNo", "PmTaskScheduleDate" ' +
            'FROM "Asset", "AssetPmTask" ' +
            'WHERE "AssetID" = "PmAssetID" ' +
            '  AND "AssetTestEquipment" = 1 ' +
            'ORDER BY "AssetManufacturer"';
          LQuery.Open;

          LData := TJSONArray.Create;
          while not LQuery.Eof do
          begin
            LRow := TJSONObject.Create;
            LRow.AddPair('asset_id',
              TJSONNumber.Create(LQuery.FieldByName('AssetID').AsInteger));

            if LQuery.FieldByName('AssetManufacturer').IsNull or
               (Trim(LQuery.FieldByName('AssetManufacturer').AsString) = '') then
              LRow.AddPair('manufacturer', TJSONNull.Create)
            else
              LRow.AddPair('manufacturer',
                TJSONString.Create(Trim(LQuery.FieldByName('AssetManufacturer').AsString)));

            if LQuery.FieldByName('AssetModel').IsNull or
               (Trim(LQuery.FieldByName('AssetModel').AsString) = '') then
              LRow.AddPair('model', TJSONNull.Create)
            else
              LRow.AddPair('model',
                TJSONString.Create(Trim(LQuery.FieldByName('AssetModel').AsString)));

            if LQuery.FieldByName('AssetSerialNo').IsNull or
               (Trim(LQuery.FieldByName('AssetSerialNo').AsString) = '') then
              LRow.AddPair('serial_no', TJSONNull.Create)
            else
              LRow.AddPair('serial_no',
                TJSONString.Create(Trim(LQuery.FieldByName('AssetSerialNo').AsString)));

            if LQuery.FieldByName('PmTaskScheduleDate').IsNull then
              LRow.AddPair('cal_date', TJSONNull.Create)
            else
              LRow.AddPair('cal_date',
                TJSONString.Create(
                  FormatDateTime('yyyy-mm-dd',
                    LQuery.FieldByName('PmTaskScheduleDate').AsDateTime)));

            LData.AddElement(LRow);
            LQuery.Next;
          end;
        finally
          LQuery.Free;
        end;
      finally
        LConn.Free;
      end;

      LResponse := TJSONObject.Create;
      LResponse.AddPair('data', LData);
      Res.Send<TJSONObject>(LResponse);
    end);
```

- [ ] **Rebuild Horse API: open `StatTracTechAPI.dproj` in RAD Studio → F9**

- [ ] **Verify with curl**

```bash
curl -s -H "Authorization: Bearer <token>" http://localhost:9000/assets/test-equipment | python -m json.tool
```

Expected: `{ "data": [ { "asset_id": ..., "manufacturer": ..., "model": ..., "serial_no": ..., "cal_date": ... }, ... ] }`

- [ ] **Commit**

```bash
git add "C:/Delphi/StatTracTechAPI/src/Assets.Routes.pas"
git commit -m "feat(api): add GET /assets/test-equipment endpoint"
```

---

## Task 10: Horse API — extend GET /certificates/templates response

**Files:**
- Modify: `C:\Delphi\StatTracTechAPI\src\Certificates.Routes.pas`

- [ ] **Extend the SELECT in `GET /certificates/templates`**

Find the SQL query in the templates route and add the three new columns:

```delphi
LQuery.SQL.Text :=
  'SELECT "TestTemplateNameID", "TestTemplateName", "TestTemplateCertName", ' +
  '       "TestTemplateType", "TestTemplateCustomerSig", ' +
  '       "TestTemplateDocNo", "TestTemplateNote", ' +
  '       "TestTemplateEditDate", "TestTemplateNextService", ' +
  '       "TestTemplateTestEquipQty" ' +
  'FROM "TestTemplateName" ' +
  'WHERE "TestTemplateType" = :ttype ' +
  'ORDER BY "TestTemplateCertName" ASC';
```

- [ ] **Add three new pairs to the response object** (after the existing `note` pair):

```delphi
if LQuery.FieldByName('TestTemplateEditDate').IsNull then
  LRow.AddPair('edit_date', TJSONNumber.Create(0))
else
  LRow.AddPair('edit_date',
    TJSONNumber.Create(LQuery.FieldByName('TestTemplateEditDate').AsInteger));

if LQuery.FieldByName('TestTemplateNextService').IsNull then
  LRow.AddPair('next_service', TJSONNumber.Create(0))
else
  LRow.AddPair('next_service',
    TJSONNumber.Create(LQuery.FieldByName('TestTemplateNextService').AsInteger));

if LQuery.FieldByName('TestTemplateTestEquipQty').IsNull then
  LRow.AddPair('test_equip_qty', TJSONNumber.Create(0))
else
  LRow.AddPair('test_equip_qty',
    TJSONNumber.Create(LQuery.FieldByName('TestTemplateTestEquipQty').AsInteger));
```

- [ ] **Rebuild Horse API: F9 in RAD Studio**

- [ ] **Verify with curl**

```bash
curl -s -H "Authorization: Bearer <token>" "http://localhost:9000/certificates/templates?type=1" | python -m json.tool
```

Expected: each template object now includes `"edit_date": 0`, `"next_service": 0`, `"test_equip_qty": 2` (values vary by template).

- [ ] **Commit**

```bash
git add "C:/Delphi/StatTracTechAPI/src/Certificates.Routes.pas"
git commit -m "feat(api): add editDate, nextService, testEquipQty to templates response"
```

---

## Task 11: Horse API — POST /certificates inserts TestAnalyser rows

**Files:**
- Modify: `C:\Delphi\StatTracTechAPI\src\Certificates.Routes.pas`

- [ ] **Add `OutInt` helper alongside existing helpers in the POST handler**

In the POST `/certificates` handler, add after the existing `OutBool` local function:

```delphi
function OutInt(Obj: TJSONObject; const AKey: string): Integer;
var V: TJSONValue;
begin
  V := Obj.GetValue(AKey);
  if (V = nil) or (V is TJSONNull) then Result := 0
  else Result := (V as TJSONNumber).AsInt;
end;
```

- [ ] **Add TestAnalyser insert loop** after the signature UPDATE block and before the `WriteSyncLog` call:

```delphi
// Insert one TestAnalyser row per test equipment item
var LEquipVal := LBody.GetValue('test_equipment');
if Assigned(LEquipVal) and (LEquipVal is TJSONArray) then
begin
  var LEquipArr := LEquipVal as TJSONArray;
  if LEquipArr.Count > 0 then
  begin
    var LInsertAnalyser := TUniQuery.Create(nil);
    try
      LInsertAnalyser.Connection := LConn;
      LInsertAnalyser.SQL.Text :=
        'INSERT INTO "TestAnalyser" ' +
        '  ("AnalyserAssetID", "AnalyserTestID", "AnalyserCalDate", ' +
        '   "AnalyserSerialNo", "AnalyserModel", "AnalyserManufacturer") ' +
        'VALUES ' +
        '  (:asset_id, :cert_id, :cal_date, :serial_no, :model, :manufacturer)';

      for var LItem in LEquipArr do
      begin
        var LObj := LItem as TJSONObject;
        LInsertAnalyser.ParamByName('asset_id').AsInteger   := OutInt(LObj, 'asset_id');
        LInsertAnalyser.ParamByName('cert_id').AsInteger    := LNewCertId;
        LInsertAnalyser.ParamByName('serial_no').AsString   := OutStr(LObj, 'serial_no');
        LInsertAnalyser.ParamByName('model').AsString       := OutStr(LObj, 'model');
        LInsertAnalyser.ParamByName('manufacturer').AsString := OutStr(LObj, 'manufacturer');

        var LCalStr := OutStr(LObj, 'cal_date');
        if (Length(LCalStr) >= 10) then
        begin
          var LY := StrToIntDef(Copy(LCalStr, 1, 4), 0);
          var LM := StrToIntDef(Copy(LCalStr, 6, 2), 0);
          var LD := StrToIntDef(Copy(LCalStr, 9, 2), 0);
          if (LY > 0) and (LM > 0) and (LD > 0) then
            LInsertAnalyser.ParamByName('cal_date').AsDateTime := EncodeDate(LY, LM, LD)
          else
            LInsertAnalyser.ParamByName('cal_date').Clear;
        end
        else
          LInsertAnalyser.ParamByName('cal_date').Clear;

        LInsertAnalyser.Execute;
      end;
    finally
      LInsertAnalyser.Free;
    end;
  end;
end;
```

- [ ] **Rebuild Horse API: F9 in RAD Studio**

- [ ] **Verify by posting a certificate with test_equipment array**

```bash
curl -s -X POST http://localhost:9000/certificates \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"asset_id":1,"cert_type":1,"template_name_id":1,"technician":"Test","technician_id":35,"test_date":"2026-06-03","doc_no":null,"tech_signature":null,"client_signature":null,"client_name":null,"patient_safe":1,"notes":null,"description":"CPAP OVP","test_equipment":[{"asset_id":55,"serial_no":"2041678","model":"ProSim 8","manufacturer":"Fluke","cal_date":"2026-01-01"}],"outputs":[]}' | python -m json.tool
```

Expected: `{ "id": <new_cert_id> }` and a row in `TestAnalyser` with `AnalyserTestID = <new_cert_id>`.

```bash
# Verify in psql:
$env:PGPASSWORD="Cbr900RR"; & "C:\Program Files\PostgreSQL\12\bin\psql.exe" -U postgres -d Stat_Trac -c "SELECT * FROM `"TestAnalyser`" ORDER BY `"TestAnalyserID`" DESC LIMIT 1;"
```

- [ ] **Commit**

```bash
git add "C:/Delphi/StatTracTechAPI/src/Certificates.Routes.pas"
git commit -m "feat(api): insert TestAnalyser rows in POST /certificates"
```

---

## Task 12: CertDetailsStep widget and equipment picker dialog

**Files:**
- Create: `lib/features/certification/presentation/widgets/cert_details_step.dart`

- [ ] **Create the file**

```dart
// lib/features/certification/presentation/widgets/cert_details_step.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../domain/entities/test_equipment_asset.dart';
import '../../domain/entities/test_equipment_selection.dart';
import '../../domain/entities/test_template_name.dart';
import '../providers/certificate_providers.dart';

class CertDetailsStep extends ConsumerStatefulWidget {
  const CertDetailsStep({
    super.key,
    required this.template,
    required this.initialDate,
    required this.initialEquipment,
    required this.onChanged,
    required this.onNext,
  });

  final TestTemplateName template;
  final DateTime initialDate;
  final List<TestEquipmentSelection?> initialEquipment;
  final void Function(DateTime testDate, List<TestEquipmentSelection?> equipment) onChanged;
  final VoidCallback onNext;

  @override
  ConsumerState<CertDetailsStep> createState() => _CertDetailsStepState();
}

class _CertDetailsStepState extends ConsumerState<CertDetailsStep> {
  late DateTime _testDate;
  late List<TestEquipmentSelection?> _equipment;

  @override
  void initState() {
    super.initState();
    _testDate = widget.initialDate;
    _equipment = List.from(widget.initialEquipment);
  }

  bool get _isValid =>
      widget.template.testEquipQty == 0 ||
      (_equipment.length == widget.template.testEquipQty &&
          _equipment.every((e) => e != null));

  void _notify() => widget.onChanged(_testDate, _equipment);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _testDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _testDate = picked);
      _notify();
    }
  }

  Future<void> _pickEquipment(int slotIndex) async {
    final excluded = _equipment
        .asMap()
        .entries
        .where((e) => e.key != slotIndex && e.value != null)
        .map((e) => e.value!.assetId)
        .toSet();

    final picked = await showTestEquipmentPicker(context, excludeAssetIds: excluded);
    if (picked != null) {
      setState(() => _equipment[slotIndex] = picked);
      _notify();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd MMM yyyy').format(_testDate);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Certificate Details',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),

          // Test Date
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Test Date',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(color: brandGrey)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: widget.template.editDate ? _pickDate : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: widget.template.editDate
                            ? null
                            : const Color(0xFFF0F2F5),
                        border: Border.all(
                          color: widget.template.editDate
                              ? brandTeal
                              : const Color(0xFFDDE3EA),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 18,
                              color: widget.template.editDate
                                  ? brandTeal
                                  : brandGrey),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              dateStr,
                              style: TextStyle(
                                color: widget.template.editDate
                                    ? null
                                    : brandGrey,
                              ),
                            ),
                          ),
                          if (widget.template.editDate)
                            Text('Tap to change',
                                style: TextStyle(
                                    fontSize: 11, color: brandTeal)),
                          if (!widget.template.editDate)
                            Text('Auto — today',
                                style: TextStyle(
                                    fontSize: 11, color: brandGrey)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Test Equipment
          if (widget.template.testEquipQty > 0) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Test Equipment',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: brandGrey)),
                    const SizedBox(height: 8),
                    for (var i = 0; i < widget.template.testEquipQty; i++)
                      _EquipmentSlot(
                        slotNo: i + 1,
                        selection: i < _equipment.length ? _equipment[i] : null,
                        onPick: () => _pickEquipment(i),
                      ),
                  ],
                ),
              ),
            ),
          ],

          const Spacer(),
          FilledButton(
            onPressed: _isValid ? widget.onNext : null,
            child: Text(_isValid
                ? 'Next'
                : 'Select all test equipment to continue'),
          ),
        ],
      ),
    );
  }
}

// ── Equipment slot tile ───────────────────────────────────────────────────────

class _EquipmentSlot extends StatelessWidget {
  const _EquipmentSlot({
    required this.slotNo,
    required this.selection,
    required this.onPick,
  });

  final int slotNo;
  final TestEquipmentSelection? selection;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final filled = selection != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: filled
                ? brandTeal.withAlpha(10)
                : const Color(0xFFFAFBFC),
            border: Border.all(
              color: filled
                  ? brandTeal.withAlpha(100)
                  : const Color(0xFFDDE3EA),
              width: filled ? 1.5 : 1,
              style: filled ? BorderStyle.solid : BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: brandTeal,
                child: Text('$slotNo',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: filled
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(selection!.displayName,
                              style: const TextStyle(fontWeight: FontWeight.w500)),
                          if (selection!.subtitleText.isNotEmpty)
                            Text(selection!.subtitleText,
                                style: TextStyle(
                                    fontSize: 11, color: brandGrey)),
                        ],
                      )
                    : Text('Select test equipment…',
                        style: TextStyle(color: brandGrey)),
              ),
              Text(filled ? 'Change' : 'Pick',
                  style: TextStyle(
                      fontSize: 11,
                      color: brandTeal,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Test equipment picker ─────────────────────────────────────────────────────

Future<TestEquipmentSelection?> showTestEquipmentPicker(
  BuildContext context, {
  Set<int> excludeAssetIds = const {},
}) {
  return showModalBottomSheet<TestEquipmentSelection>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) =>
        _TestEquipmentPickerSheet(excludeAssetIds: excludeAssetIds),
  );
}

class _TestEquipmentPickerSheet extends ConsumerWidget {
  const _TestEquipmentPickerSheet({required this.excludeAssetIds});
  final Set<int> excludeAssetIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetsAsync = ref.watch(testEquipmentAssetsProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Select Test Equipment',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          const Divider(height: 1),
          Expanded(
            child: assetsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Error loading equipment: $e')),
              data: (assets) {
                final available = assets
                    .where((a) => !excludeAssetIds.contains(a.assetId))
                    .toList();
                if (available.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.build_outlined,
                            size: 48, color: brandGrey),
                        const SizedBox(height: 12),
                        Text('No test equipment available',
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 4),
                        Text('Sync to load test equipment',
                            style: TextStyle(color: brandGrey)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  controller: controller,
                  itemCount: available.length,
                  itemBuilder: (_, i) {
                    final a = available[i];
                    return ListTile(
                      leading: const Icon(Icons.biotech_outlined,
                          color: brandTeal),
                      title: Text(a.displayName),
                      subtitle: Text([
                        if (a.serialNo != null) 'S/N: ${a.serialNo}',
                        if (a.calDate != null) 'Cal: ${a.calDate}',
                      ].join(' · ')),
                      onTap: () => Navigator.of(context).pop(
                        TestEquipmentSelection.fromAsset(a),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Run `flutter analyze` — expect no errors**

- [ ] **Commit**

```bash
git add lib/features/certification/presentation/widgets/cert_details_step.dart
git commit -m "feat(cert): add CertDetailsStep widget with date picker and equipment slots"
```

---

## Task 13: create_certificate_screen.dart — new step and state

**Files:**
- Modify: `lib/features/certification/presentation/screens/create_certificate_screen.dart`

- [ ] **Add imports**

```dart
import '../../domain/entities/test_equipment_selection.dart';
import '../widgets/cert_details_step.dart';
```

- [ ] **Add new state fields** (after `_saving` and `_allActualsValid`):

```dart
DateTime _testDate = DateTime.now();
List<TestEquipmentSelection?> _equipment = [];
```

- [ ] **Add navigation helper** (after the `_goToStep` method):

```dart
bool get _shouldShowDetailsStep =>
    _selectedTemplate != null &&
    (_selectedTemplate!.editDate || _selectedTemplate!.testEquipQty > 0);
```

- [ ] **Update template selection handler**

Replace the existing template selection inside `CertTemplatePicker.onSelected`:

```dart
CertTemplatePicker(
  certType: _selectedType!,
  onSelected: (t) {
    setState(() {
      _selectedTemplate = t;
      _equipment = List.filled(t.testEquipQty, null);
    });
    _goToStep(_shouldShowDetailsStep ? 3 : 4);
  },
)
```

- [ ] **Update back button** (in AppBar `leading`):

```dart
BackButton(
  onPressed: _step == 0
      ? () => Navigator.of(context).pop()
      : () {
          if (_step == 4 && !_shouldShowDetailsStep) {
            _goToStep(2);
          } else {
            _goToStep(_step - 1);
          }
        },
),
```

- [ ] **Add step 3 to IndexedStack and shift existing steps**

The IndexedStack children become 6 items (indices 0–5). Replace the entire `children:` list:

```dart
children: [
  // Step 0: type selector
  CertTypeSelector(
    onSelected: (type) {
      setState(() => _selectedType = type);
      _goToStep(1);
    },
  ),

  // Step 1: asset picker
  _AssetPickStep(
    selectedAsset: _selectedAsset,
    onPickTap: _pickAsset,
    onNext: _selectedAsset != null ? () => _goToStep(2) : null,
  ),

  // Step 2: template picker
  if (_selectedType != null)
    CertTemplatePicker(
      certType: _selectedType!,
      onSelected: (t) {
        setState(() {
          _selectedTemplate = t;
          _equipment = List.filled(t.testEquipQty, null);
        });
        _goToStep(_shouldShowDetailsStep ? 3 : 4);
      },
    )
  else
    const SizedBox.shrink(),

  // Step 3: certificate details (NEW)
  if (_selectedTemplate != null)
    CertDetailsStep(
      template: _selectedTemplate!,
      initialDate: _testDate,
      initialEquipment: _equipment,
      onChanged: (date, equip) =>
          setState(() {
            _testDate = date;
            _equipment = equip;
          }),
      onNext: () => _goToStep(4),
    )
  else
    const SizedBox.shrink(),

  // Step 4: test items grid (was step 3)
  if (_selectedTemplate != null && _selectedAsset != null)
    Column(
      children: [
        Expanded(
          child: CertTestGrid(
            templateNameId: _selectedTemplate!.id,
            assetId: _selectedAsset!.assetId ?? 0,
            onOutputsChanged: (outputs) => _outputs = outputs,
            onValidityChanged: (valid) =>
                setState(() => _allActualsValid = valid),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_savedCertId == null) ...[
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    hintText: 'Optional certificate notes…',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                  maxLength: 200,
                  maxLines: 2,
                  minLines: 1,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 8),
                _ComplianceSelector(
                  value: _patientSafe,
                  onChanged: (v) => setState(() => _patientSafe = v),
                ),
                const SizedBox(height: 8),
                if (!_allActualsValid || _patientSafe == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      [
                        if (!_allActualsValid)
                          'Fill in all test results and actual values.',
                        if (_patientSafe == null)
                          'Select a compliance status.',
                      ].join(' '),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                FilledButton(
                  onPressed: _saving ||
                          !_allActualsValid ||
                          _patientSafe == null
                      ? null
                      : _saveCertificate,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ] else ...[
                Text(
                  'Saved to device ✓',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.green[700]),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => _goToStep(5),
                  child: const Text('Sign Certificate'),
                ),
              ],
            ],
          ),
        ),
      ],
    )
  else
    const SizedBox.shrink(),

  // Step 5: signatures (was step 4)
  if (_selectedTemplate != null)
    CertSignatureStep(
      requiresCustomerSig: _selectedTemplate!.customerSigRequired,
      onSigned: _completeWithSignature,
    )
  else
    const SizedBox.shrink(),
],
```

- [ ] **Update `_saveCertificate` to pass test date and equipment**

Change the `TestCertificate` construction to use `_testDate`:
```dart
testDate: _testDate,   // was DateTime.now()
```

Change the `issueCertificate` call to include equipment:
```dart
final certId = await ref
    .read(certificateRepositoryProvider)
    .issueCertificate(
      cert: cert,
      outputs: _outputs,
      equipment: _equipment.whereType<TestEquipmentSelection>().toList(),
    );
```

- [ ] **Run `flutter analyze` — expect no errors**

- [ ] **Hot-restart app and walk through the full certificate creation flow**

Verify:
1. Template with `testEquipQty=0` and `editDate=0` → step 3 is skipped, goes straight to test grid
2. Template with `testEquipQty=2` → step 3 appears, 2 equipment slots shown, Next disabled until both filled
3. Template with `editDate=1` → date field is teal-bordered and tappable; picking a date updates it
4. After Save → "Sign Certificate" button navigates to step 5 (signature)
5. Back from test grid (step 4) when step 3 was skipped → goes to step 2 (template)

- [ ] **Commit**

```bash
git add lib/features/certification/presentation/screens/create_certificate_screen.dart
git commit -m "feat(cert): integrate CertDetailsStep into certificate creation wizard"
```

---

## Self-Review

**Spec coverage:**
- ✅ Step skipped when all conditions zero (Task 13 `_shouldShowDetailsStep`)
- ✅ Test date locked/editable based on `editDate` flag (Task 12)
- ✅ Equipment slots from `TestTemplateTestEquipQty` (Tasks 12, 13)
- ✅ Picker query via `GET /assets/test-equipment` (Tasks 9, 6)
- ✅ Local persistence in `test_cert_equipment` (Tasks 1, 5, 7)
- ✅ `TestAnalyser` insert on push (Tasks 11, 7)
- ✅ Three template flag columns synced (Tasks 2, 10)
- ✅ New sync step in pipeline (Task 8)
- ✅ Migration v11 covers all tables and columns (Task 1)
- ✅ Next service date stored in DB column but not exposed in UI (deferred per spec)

**Type consistency check:**
- `TestEquipmentSelection.fromAsset(TestEquipmentAsset)` defined in Task 4, used in Task 12 ✅
- `testEquipmentAssetsProvider` defined in Task 6, watched in Task 12 ✅
- `issueCertificate({..., equipment})` signature matches Tasks 7 and 13 ✅
- `_goToStep(5)` in Task 13 matches step 5 = signature in the 6-item IndexedStack ✅
- `saveEquipmentSelections` / `getEquipmentForCert` defined in Task 5, called in Tasks 7 ✅
