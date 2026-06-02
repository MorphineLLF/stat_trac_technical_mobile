# Cert Sync Option B, Display Fixes & Pagination — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the soft-delete cert pull (Option A) with a full-ID-set comparison (Option B), fix cert name and compliance display in the list and detail screens, store `cert_name` from the server for historical certs, and add `page_size` pagination to `GET /certificates/history`.

**Architecture:** Option B pull — `GET /certificates/ids` returns all server IDs for the technician; the app diffs against local `server_id` values and deletes orphans; `GET /certificates/history` is then called with a cursor and page size. `cert_name` is resolved server-side via correlated subqueries and stored in a new `cert_name TEXT` column on `test_certificates` so historical desktop-created certs (where `TestType = 0`) show the correct template name without a fragile JOIN. A one-time backfill re-pulls all certs when any row has `cert_name IS NULL`.

**Tech Stack:** Delphi 12 / Horse / UniDAC / PostgreSQL (server); Flutter / Dio / Riverpod 3 / sqflite (client).

> ✅ **STATUS: COMPLETE — implemented 2026-06-02**

---

## File Map

| File | Action | Purpose |
|---|---|---|
| `C:\Delphi\StatTracTechAPI\src\Certificates.Routes.pas` | Modify | Add `cert_name` subquery + `page_size` LIMIT to `/certificates/history`; `GET /certificates/ids` already present |
| `lib/features/certification/data/datasources/cert_remote_data_source.dart` | Modify | Revert history signature to simple list; add `fetchCertificateIds`; add `pageSize` param |
| `lib/features/certification/data/datasources/cert_local_data_source.dart` | Modify | Remove `getLastCertPullAt`/`setLastCertPullAt`; add `getSyncedServerIds`, `hasCertsWithNullCertName`; update `insertCertificateFromServer` to patch `cert_name` |
| `lib/features/certification/domain/repositories/certificate_repository.dart` | Modify | Update `pullCertificatesFromRemote` return type |
| `lib/features/certification/data/repositories/certificate_repository_impl.dart` | Modify | Option B pull logic + pagination loop + backfill cursor |
| `lib/sync/sync_notifier.dart` | Modify | Log `pull_certificates` success with deleted IDs and added count |
| `lib/database/migrations/migration_010_cert_name.dart` | Create | `ALTER TABLE test_certificates ADD COLUMN cert_name TEXT` |
| `lib/database/database_helper.dart` | Modify | Register migration 010, bump DB version to 10 |
| `lib/features/certification/domain/entities/test_certificate.dart` | Modify | Add `certName` field |
| `lib/features/certification/data/models/test_certificate_model.dart` | Modify | `certName` in `fromJson`, `fromMap`, `toMap` |
| `lib/features/certification/data/models/certificate_summary.dart` | Modify | Add `certificateNo`, `templateNameId`, `templateName`; `resolvedTemplateName` and `displayTitle` getters; COALESCE display chain |
| `lib/features/certification/presentation/screens/certificate_list_screen.dart` | Modify | Use `displayTitle`; always show equipment type; show `Cert #N`; compliance chip |
| `lib/features/certification/presentation/screens/certificate_detail_screen.dart` | Modify | Use `displayTitle`; add compliance chip to header |
| `C:\Users\HomePC\Nextcloud\...\1-Architecture-Overview.md` | Update | Certificate sync flow — pagination + backfill |
| `C:\Users\HomePC\Nextcloud\...\3-Horse-API.md` | Update | `/certificates/history` — `page_size`, `cert_name` |
| `C:\Users\HomePC\Nextcloud\...\4-Flutter-App.md` | Update | DB v10, migrations 008–010, full table schemas, sync pipeline |
| `C:\Users\HomePC\Nextcloud\...\5-Decisions-Log.md` | Update | cert_name storage rationale, backfill, pagination |
| `C:\Users\HomePC\Nextcloud\...\6-Security.md` | Create | Full security audit — implemented controls and pre-production gaps |
| `CLAUDE.md` | Update | DB version, migration table, Horse API contract, plans table |

---

## Task 1: Delphi — Add `cert_name` and `page_size` to `/certificates/history`

**Files:**
- Modify: `C:\Delphi\StatTracTechAPI\src\Certificates.Routes.pas`

- [x] **Step 1: Add `LPageSize` variable and read `page_size` query param**

In the history route handler's `var` block, add:
```pascal
LPageSize: Integer;
```
After reading `LAfterId`, add:
```pascal
LPageSize := StrToIntDef(Req.Query.Field('page_size').AsString, 100);
if LPageSize <= 0 then LPageSize := 100;
if LPageSize > 500 then LPageSize := 500;
```

- [x] **Step 2: Add `cert_name` COALESCE subquery and `LIMIT` to the cert SELECT**

Replace the existing `LCertQuery.SQL.Text` assignment to add the COALESCE subquery and LIMIT:
```pascal
LCertQuery.SQL.Text :=
  'SELECT "TestCertificateID", "TestAssetID", "TestDate", ' +
  '       "TestCertType", "TestType", "TestTech", "TestTechID", ' +
  '       "TestDocNo", "TestNextService", "TestWoNo", ' +
  '       "TestJobcardNo", "TestServiceInterval", "TestServiceType", ' +
  '       "TestClientNameSignature", ' +
  '       COALESCE(' +
  '         (SELECT tn."TestTemplateCertName" ' +
  '          FROM "TestTemplateName" tn ' +
  '          WHERE tn."TestTemplateNameID" = "TestCertificate"."TestType" ' +
  '          LIMIT 1), ' +
  '         (SELECT tn2."TestTemplateCertName" ' +
  '          FROM "TestOutput" o ' +
  '          JOIN "TestTemplate" tt ON tt."TestTempDescriptionID" = o."TestDescriptionID" ' +
  '          JOIN "TestTemplateName" tn2 ON tn2."TestTemplateNameID" = tt."TestTempCertificateNameID" ' +
  '          WHERE o."TestOutputCertID" = "TestCertificate"."TestCertificateID" ' +
  '          LIMIT 1) ' +
  '       ) AS "CertName" ' +
  'FROM "TestCertificate" ' +
  'WHERE "TestTechID" = :tech_id ' +
  '  AND "TestCertificateID" > :after_id ' +
  'ORDER BY "TestCertificateID" ASC ' +
  'LIMIT :page_size';
LCertQuery.ParamByName('tech_id').AsInteger   := LTechId;
LCertQuery.ParamByName('after_id').AsInteger  := LAfterId;
LCertQuery.ParamByName('page_size').AsInteger := LPageSize;
```

- [x] **Step 3: Emit `cert_name` in the JSON response**

After `LCertObj.AddPair('client_name', ...)`, add:
```pascal
if LCertQuery.FieldByName('CertName').IsNull or
   (Trim(LCertQuery.FieldByName('CertName').AsString) = '') then
  LCertObj.AddPair('cert_name', TJSONNull.Create)
else
  LCertObj.AddPair('cert_name',
    TJSONString.Create(Trim(LCertQuery.FieldByName('CertName').AsString)));
```

- [x] **Step 4: Build in RAD Studio (F9) and smoke-test**

```powershell
$r = Invoke-RestMethod -Method Post -Uri "http://localhost:9000/auth/login" `
  -ContentType "application/json" `
  -Body '{"username":"fritz","password":"<pwd>","db":"Stat_Trac"}'
$tok = $r.token.access_token

Invoke-RestMethod `
  -Uri "http://localhost:9000/certificates/history?technician_id=35&after_id=0&page_size=5" `
  -Headers @{Authorization="Bearer $tok"}
```

Expected: `data` array with ≤5 items; each item has `cert_name` field (string or null).

---

## Task 2: Flutter — Option B remote data source

**Files:**
- Modify: `lib/features/certification/data/datasources/cert_remote_data_source.dart`

- [x] **Step 1: Simplify `fetchCertificateHistory` interface (no record type)**

Replace the interface method:
```dart
/// `GET /certificates/history?technician_id=:id&after_id=:cursor&page_size=:n`
/// Returns up to [pageSize] certs with embedded outputs whose ID > afterId.
Future<List<(TestCertificateModel, List<TestOutputModel>)>>
    fetchCertificateHistory(int technicianId, int afterId,
        {int pageSize = 100});

/// `GET /certificates/ids?technician_id=:id`
/// Returns all TestCertificateID values for the technician on the server.
Future<List<int>> fetchCertificateIds(int technicianId);
```

- [x] **Step 2: Update the implementation to match**

```dart
@override
Future<List<(TestCertificateModel, List<TestOutputModel>)>>
    fetchCertificateHistory(int technicianId, int afterId,
        {int pageSize = 100}) async {
  final response = await _dio.get(
    '/certificates/history',
    queryParameters: {
      'technician_id': technicianId,
      'after_id': afterId,
      'page_size': pageSize,
    },
  );
  final data =
      ((response.data['data'] as List?) ?? []).cast<Map<String, dynamic>>();
  return data.map((j) {
    final cert = TestCertificateModel.fromJson(j);
    final rawOutputs =
        (j['outputs'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final outputs = rawOutputs
        .map((o) => TestOutputModel.fromJson(o, certificateId: 0))
        .toList();
    return (cert, outputs);
  }).toList();
}

@override
Future<List<int>> fetchCertificateIds(int technicianId) async {
  final response = await _dio.get(
    '/certificates/ids',
    queryParameters: {'technician_id': technicianId},
  );
  return ((response.data['ids'] as List?) ?? []).cast<int>();
}
```

- [x] **Step 3: `flutter analyze`** — expected: no issues.

---

## Task 3: Flutter — Option B local data source changes

**Files:**
- Modify: `lib/features/certification/data/datasources/cert_local_data_source.dart`

- [x] **Step 1: Remove `getLastCertPullAt` and `setLastCertPullAt` from interface and implementation**

These are no longer needed — Option B uses the full ID set, not a timestamp.

- [x] **Step 2: Add `getSyncedServerIds` to interface and implementation**

```dart
// Interface
Future<List<int>> getSyncedServerIds();

// Implementation
@override
Future<List<int>> getSyncedServerIds() async {
  final db = await _db.database;
  final rows = await db.query(
    'test_certificates',
    columns: ['server_id'],
    where: 'server_id IS NOT NULL',
  );
  return rows.map((r) => r['server_id'] as int).toList();
}
```

- [x] **Step 3: Add `hasCertsWithNullCertName` to interface and implementation**

```dart
// Interface
Future<bool> hasCertsWithNullCertName();

// Implementation
@override
Future<bool> hasCertsWithNullCertName() async {
  final db = await _db.database;
  final result = await db.rawQuery(
    'SELECT COUNT(*) AS c FROM test_certificates '
    'WHERE server_id IS NOT NULL AND cert_name IS NULL',
  );
  return ((result.first['c'] as int?) ?? 0) > 0;
}
```

- [x] **Step 4: Update `insertCertificateFromServer` to patch `cert_name` for existing certs**

```dart
@override
Future<int?> insertCertificateFromServer(TestCertificateModel cert) async {
  if (cert.serverId == null) return null;
  final db = await _db.database;
  final existing = await db.query(
    'test_certificates',
    columns: ['id'],
    where: 'server_id = ?',
    whereArgs: [cert.serverId],
  );
  if (existing.isNotEmpty) {
    if (cert.certName != null) {
      await db.update(
        'test_certificates',
        {'cert_name': cert.certName},
        where: 'server_id = ? AND cert_name IS NULL',
        whereArgs: [cert.serverId],
      );
    }
    return null;
  }
  return db.insert('test_certificates', cert.toMap());
}
```

- [x] **Step 5: `flutter analyze`** — expected: no issues.

---

## Task 4: Flutter — Migration 010, entity, model

**Files:**
- Create: `lib/database/migrations/migration_010_cert_name.dart`
- Modify: `lib/database/database_helper.dart`
- Modify: `lib/features/certification/domain/entities/test_certificate.dart`
- Modify: `lib/features/certification/data/models/test_certificate_model.dart`

- [x] **Step 1: Create migration 010**

```dart
import 'package:sqflite/sqflite.dart';

Future<void> migration010CertName(Database db) async {
  try {
    await db.execute(
      'ALTER TABLE test_certificates ADD COLUMN cert_name TEXT',
    );
  } catch (_) {}
}
```

- [x] **Step 2: Register in `database_helper.dart`**

Import the migration, bump `_dbVersion` to `10`, add to both `_onCreate` and `_onUpgrade`:
```dart
if (oldVersion < 10) await migration010CertName(db);
```

- [x] **Step 3: Add `certName` to entity and model**

In `test_certificate.dart`, add `this.certName` to constructor and `final String? certName;` field.

In `test_certificate_model.dart`, add to `fromJson`, `fromMap`, and `toMap`:
```dart
// fromJson
certName: j['cert_name'] as String?,
// fromMap
certName: m['cert_name'] as String?,
// toMap
'cert_name': certName,
```

- [x] **Step 4: `flutter analyze`** — expected: no issues.

---

## Task 5: Flutter — Repository Option B pull logic + pagination

**Files:**
- Modify: `lib/features/certification/domain/repositories/certificate_repository.dart`
- Modify: `lib/features/certification/data/repositories/certificate_repository_impl.dart`

- [x] **Step 1: Update domain interface return type**

```dart
/// Returns the IDs of deleted records and count of added records.
Future<({List<int> deletedIds, int added})> pullCertificatesFromRemote(int technicianId);
```

- [x] **Step 2: Implement Option B + pagination loop in repository**

```dart
@override
Future<({List<int> deletedIds, int added})> pullCertificatesFromRemote(
    int technicianId) async {
  // Option B: compare full ID sets to detect server-side deletes.
  final serverIds = (await remote.fetchCertificateIds(technicianId)).toSet();
  final localServerIds = await local.getSyncedServerIds();
  final deletedIds = <int>[];
  for (final id in localServerIds) {
    if (!serverIds.contains(id)) {
      try {
        await local.deleteCertificateByServerId(id);
        deletedIds.add(id);
      } catch (_) {}
    }
  }

  // Use cursor 0 to backfill cert_name for existing certs that lack it.
  final needsBackfill = await local.hasCertsWithNullCertName();
  var cursor = needsBackfill ? 0 : await local.getMaxServerId();
  var added = 0;
  const pageSize = 100;

  while (true) {
    final page = await remote.fetchCertificateHistory(
        technicianId, cursor, pageSize: pageSize);
    for (final (cert, outputs) in page) {
      try {
        final localId = await local.insertCertificateFromServer(cert);
        if (localId != null) {
          if (outputs.isNotEmpty) {
            await local.insertOutputsForCert(localId, outputs);
          }
          added++;
        }
      } catch (_) {}
      if (cert.serverId != null && cert.serverId! > cursor) {
        cursor = cert.serverId!;
      }
    }
    if (page.length < pageSize) break;
  }

  return (deletedIds: deletedIds, added: added);
}
```

- [x] **Step 3: `flutter analyze`** — expected: no issues.

---

## Task 6: Flutter — Sync notifier success logging

**Files:**
- Modify: `lib/sync/sync_notifier.dart`

- [x] **Step 1: Update pull step to use return value and post success log**

Replace the cert pull block with one that uses `({List<int> deletedIds, int added})`:
```dart
final pullResult = await ref
    .read(certificateRepositoryProvider)
    .pullCertificatesFromRemote(technicianId);
await errorLog.markResolved('pull_certificates');
final parts = <String>[];
if (pullResult.added > 0) parts.add('${pullResult.added} added');
if (pullResult.deletedIds.isNotEmpty) {
  parts.add(
    '${pullResult.deletedIds.length} deleted '
    '(IDs: ${pullResult.deletedIds.join(', ')})',
  );
}
await syncRemote.postSyncLog(
  operation: 'pull_certificates',
  entity: 'test_certificates',
  rowCount: pullResult.added + pullResult.deletedIds.length,
  status: 'success',
  message: parts.isEmpty ? 'No changes' : parts.join(', '),
);
```

- [x] **Step 2: `flutter analyze`** — expected: no issues.

---

## Task 7: Flutter — `CertificateSummary` model and display chain

**Files:**
- Modify: `lib/features/certification/data/datasources/cert_local_data_source.dart`
- Modify: `lib/features/certification/data/models/certificate_summary.dart`

- [x] **Step 1: Update `_certSummarySelect` with dual JOIN + COALESCE chain**

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

Order by `certificate_no DESC, tc.created_at DESC`.

- [x] **Step 2: Add new fields and getters to `CertificateSummary`**

Add constructor params and fields: `certificateNo`, `templateNameId`, `templateName`.

Add getters:
```dart
String? get resolvedTemplateName {
  if (certName != null && certName!.isNotEmpty) return certName!;
  if (templateName != null && templateName!.isNotEmpty) return templateName!;
  return null;
}

String get displayTitle =>
    resolvedTemplateName ?? '$typeLabel Certificate';
```

Update `fromMap` to read `certificate_no`, `template_name_id`, `template_name`.

- [x] **Step 3: `flutter analyze`** — expected: no issues.

---

## Task 8: Flutter — Certificate list and detail screen updates

**Files:**
- Modify: `lib/features/certification/presentation/screens/certificate_list_screen.dart`
- Modify: `lib/features/certification/presentation/screens/certificate_detail_screen.dart`

- [x] **Step 1: List screen — use `displayTitle`, always show equipment type, show cert number**

- Title: `cert.displayTitle`
- Subtitle line 1: `cert.equipmentType ?? '—'` (always rendered, not conditional)
- Date row: `'Cert #${cert.certificateNo}'` shown next to date when `certificateNo != null`
- Compliance chip already present — no change needed

- [x] **Step 2: Detail screen — use `displayTitle`, add compliance chip to header**

AppBar title: `s?.displayTitle ?? 'Certificate'`

In `_HeaderCard`, add compliance chip next to type chip:
```dart
if (summary.complianceLabel.isNotEmpty)
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: summary.complianceColor.withAlpha(20),
      border: Border.all(color: summary.complianceColor),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      summary.complianceLabel,
      style: TextStyle(
        color: summary.complianceColor,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    ),
  ),
```

Header title: `Text(summary.displayTitle, ...)`

- [x] **Step 3: `flutter analyze`** — expected: no issues.

---

## Task 9: Documentation

**Files:**
- Create: `C:\Users\HomePC\Nextcloud\...\6-Security.md`
- Modify: `1-Architecture-Overview.md`, `3-Horse-API.md`, `4-Flutter-App.md`, `5-Decisions-Log.md`
- Modify: `CLAUDE.md`

- [x] **Step 1: Create `6-Security.md`**

Full security audit doc covering: implemented controls (JWT, Keystore storage, HTTPS enforcement, multi-tenant isolation, login audit, DB name hiding), critical gaps (default JWT secret, unencrypted SQLite, plaintext passwords), medium gaps (no cert pinning, no biometric lock), POPIA compliance notes, and pre-production checklist.

- [x] **Step 2: Update all Nextcloud docs** — cert sync flow, Horse API pagination + `cert_name`, DB schema tables (full column lists for `test_template_names`, `test_template_items`, `test_certificates`, `test_outputs`), sync pipeline step 7, decisions log entry.

- [x] **Step 3: Update `CLAUDE.md`** — DB version 7→10, migration table, Horse API contract, cert data layer notes, plans table, `6-Security.md` in session-start reading table.

---

## Self-Review

**Spec coverage:**
- ✅ Option B ID set comparison — Task 5
- ✅ `GET /certificates/ids` endpoint (Delphi) — already existed; used in Task 5
- ✅ `fetchCertificateIds` remote method — Task 2
- ✅ `getSyncedServerIds` local method — Task 3
- ✅ `cert_name` Delphi correlated subquery — Task 1
- ✅ `cert_name` column migration 010 — Task 4
- ✅ `cert_name` backfill (cursor=0 + `insertCertificateFromServer` patch) — Tasks 3 & 5
- ✅ `page_size` pagination — Tasks 1, 2, 5
- ✅ `pullCertificatesFromRemote` returns `({List<int> deletedIds, int added})` — Tasks 5 & 6
- ✅ Success `AppSyncLog` entry with deleted IDs — Task 6
- ✅ `CertificateSummary` dual-JOIN COALESCE display chain — Task 7
- ✅ `displayTitle` / `resolvedTemplateName` getters — Task 7
- ✅ `certificateNo` field and list display — Tasks 7 & 8
- ✅ Compliance chip in detail screen — Task 8
- ✅ Security documentation — Task 9
- ✅ All Nextcloud docs + CLAUDE.md updated — Task 9

**Placeholder scan:** None — all steps contain complete code.

**Type consistency:**
- `fetchCertificateHistory` returns `List<(TestCertificateModel, List<TestOutputModel>)>` in interface, impl, and repository loop ✅
- `pullCertificatesFromRemote` returns `Future<({List<int> deletedIds, int added})>` in interface, impl, and notifier ✅
- `CertificateSummary.certificateNo` read from SQL alias `certificate_no` ✅
- `cert_name` column used in migration, `toMap`/`fromMap`/`fromJson`, and `_certSummarySelect` COALESCE ✅
