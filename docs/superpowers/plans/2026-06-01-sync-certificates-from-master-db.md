# Sync Certificates from Master DB Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pull `TestCertificate` + `TestOutput` records from the master PostgreSQL DB into local SQLite on each sync cycle so the certificate list shows certs created on other devices or in the back-office, and the detail screen shows their full test results.

**Architecture:** New `GET /certificates/history?technician_id=<id>&after_id=<last_server_id>` endpoint on the Horse API returns cert headers with outputs embedded. Flutter `SyncNotifier` calls `pullCertificatesFromRemote()` after pushing pending certs. The cursor is `MAX(server_id)` from the local `test_certificates` table — no extra storage needed. Locally-created certs (already have `server_id`) are skipped on pull to preserve signatures.

**Tech Stack:** Delphi 12 / Horse / UniDAC / PostgreSQL on the server; Flutter / Dio / Riverpod 3 / sqflite on the client.

---

## File Map

| File | Action | Purpose |
|---|---|---|
| `C:\Delphi\StatTracTechAPI\src\Certificates.Routes.pas` | Modify | Add `GET /certificates/history` endpoint |
| `lib/features/certification/data/models/test_certificate_model.dart` | Modify | Add `fromJson` factory |
| `lib/features/certification/data/models/test_output_model.dart` | Modify | Add `fromJson` factory |
| `lib/features/certification/data/datasources/cert_remote_data_source.dart` | Modify | Add `fetchCertificateHistory()` |
| `lib/features/certification/data/datasources/cert_local_data_source.dart` | Modify | Add `getMaxServerId()`, `insertCertificateFromServer()`, `insertOutputsForCert()` |
| `lib/features/certification/domain/repositories/certificate_repository.dart` | Modify | Add `pullCertificatesFromRemote()` to interface |
| `lib/features/certification/data/repositories/certificate_repository_impl.dart` | Modify | Implement `pullCertificatesFromRemote()` |
| `lib/sync/sync_notifier.dart` | Modify | Add pull step after push |

---

## Task 1: Delphi — Add GET /certificates/history endpoint

**Files:**
- Modify: `C:\Delphi\StatTracTechAPI\src\Certificates.Routes.pas`

This endpoint is added inside the existing `RegisterCertificateRoutes` procedure, after the `POST /certificates` block, before the final `end;`.

- [ ] **Step 1: Add the endpoint block**

Open `C:\Delphi\StatTracTechAPI\src\Certificates.Routes.pas`.

Find the line `end;` that closes `RegisterCertificateRoutes` (the very last `end;` before `end.`). Insert the following block immediately before it:

```pascal
  // ── GET /certificates/history?technician_id=<id>&after_id=<n> ───────────────
  // Returns TestCertificate rows with TestOutput rows embedded.
  // Only returns certs for the given technician with ID > after_id (cursor).
  THorse
    .AddCallback(HorseJWT(JWT_SECRET))
    .Get('/certificates/history',
      procedure(Req: THorseRequest; Res: THorseResponse)
      var
        LTechId: Integer;
        LAfterId: Integer;
        LConn: TUniConnection;
        LCertQuery, LOutQuery: TUniQuery;
        LData: TJSONArray;
        LCertObj, LOutObj: TJSONObject;
        LOutputs: TJSONArray;
        LCertId: Integer;
        LResponse: TJSONObject;

        function NullableStr(const AFieldName: string): TJSONValue;
        var S: string;
        begin
          if LCertQuery.FieldByName(AFieldName).IsNull then
            Result := TJSONNull.Create
          else
          begin
            S := Trim(LCertQuery.FieldByName(AFieldName).AsString);
            if S = '' then Result := TJSONNull.Create
            else Result := TJSONString.Create(S);
          end;
        end;

        function NullableDate(const AFieldName: string): TJSONValue;
        begin
          if LCertQuery.FieldByName(AFieldName).IsNull then
            Result := TJSONNull.Create
          else
            Result := TJSONString.Create(
              FormatDateTime('yyyy-mm-dd',
                LCertQuery.FieldByName(AFieldName).AsDateTime));
        end;

      begin
        if ExtractDbName(Req).IsEmpty then
        begin
          Res.Status(THTTPStatus.Unauthorized).Send('Missing db claim');
          Exit;
        end;

        LTechId  := StrToIntDef(Req.Query.Field('technician_id').AsString, 0);
        LAfterId := StrToIntDef(Req.Query.Field('after_id').AsString, 0);

        if LTechId <= 0 then
        begin
          Res.Status(THTTPStatus.BadRequest).Send('technician_id is required');
          Exit;
        end;

        LConn := NewDBConnection(ExtractDbName(Req));
        try
          LCertQuery := TUniQuery.Create(nil);
          try
            LCertQuery.Connection := LConn;
            LCertQuery.SQL.Text :=
              'SELECT "TestCertificateID", "TestAssetID", "TestDate", ' +
              '       "TestCertType", "TestType", "TestTech", "TestTechID", ' +
              '       "TestDocNo", "TestNextService", "TestWoNo", ' +
              '       "TestJobcardNo", "TestServiceInterval", "TestServiceType", ' +
              '       "TestClientNameSignature" ' +
              'FROM "TestCertificate" ' +
              'WHERE "TestTechID" = :tech_id ' +
              '  AND "TestCertificateID" > :after_id ' +
              'ORDER BY "TestCertificateID" ASC';
            LCertQuery.ParamByName('tech_id').AsInteger  := LTechId;
            LCertQuery.ParamByName('after_id').AsInteger := LAfterId;
            LCertQuery.Open;

            LData := TJSONArray.Create;

            LOutQuery := TUniQuery.Create(nil);
            try
              LOutQuery.Connection := LConn;

              while not LCertQuery.Eof do
              begin
                LCertId := LCertQuery.FieldByName('TestCertificateID').AsInteger;

                LCertObj := TJSONObject.Create;
                LCertObj.AddPair('id',
                  TJSONNumber.Create(LCertId));
                LCertObj.AddPair('asset_id',
                  TJSONNumber.Create(
                    LCertQuery.FieldByName('TestAssetID').AsInteger));
                LCertObj.AddPair('test_date',
                  NullableDate('TestDate'));
                LCertObj.AddPair('cert_type',
                  TJSONNumber.Create(
                    LCertQuery.FieldByName('TestType').AsInteger));
                LCertObj.AddPair('template_name_id',
                  TJSONNumber.Create(
                    LCertQuery.FieldByName('TestCertType').AsInteger));
                LCertObj.AddPair('technician',   NullableStr('TestTech'));
                LCertObj.AddPair('technician_id',
                  TJSONNumber.Create(
                    LCertQuery.FieldByName('TestTechID').AsInteger));
                LCertObj.AddPair('doc_no',           NullableStr('TestDocNo'));
                LCertObj.AddPair('next_service',     NullableDate('TestNextService'));
                LCertObj.AddPair('wo_number',
                  TJSONNumber.Create(
                    LCertQuery.FieldByName('TestWoNo').AsInteger));
                LCertObj.AddPair('jobcard_no',       NullableStr('TestJobcardNo'));
                LCertObj.AddPair('service_interval', NullableStr('TestServiceInterval'));
                LCertObj.AddPair('service_type',     NullableStr('TestServiceType'));
                LCertObj.AddPair('client_name',      NullableStr('TestClientNameSignature'));

                // Fetch outputs for this cert.
                LOutQuery.Close;
                LOutQuery.SQL.Text :=
                  'SELECT "TestOutPutID", "TestDescriptionID", "TestDescription", ' +
                  '       "TestValue", "TestActualValue", "TestNotes", ' +
                  '       "TestPass", "TestFail", "TestNA" ' +
                  'FROM "TestOutput" ' +
                  'WHERE "TestOutputCertID" = :cert_id ' +
                  'ORDER BY "TestOutPutID" ASC';
                LOutQuery.ParamByName('cert_id').AsInteger := LCertId;
                LOutQuery.Open;

                LOutputs := TJSONArray.Create;
                while not LOutQuery.Eof do
                begin
                  LOutObj := TJSONObject.Create;
                  LOutObj.AddPair('id',
                    TJSONNumber.Create(
                      LOutQuery.FieldByName('TestOutPutID').AsInteger));

                  if LOutQuery.FieldByName('TestDescriptionID').IsNull or
                     (Trim(LOutQuery.FieldByName('TestDescriptionID').AsString) = '') then
                    LOutObj.AddPair('description_id', TJSONNull.Create)
                  else
                    LOutObj.AddPair('description_id',
                      TJSONString.Create(
                        Trim(LOutQuery.FieldByName('TestDescriptionID').AsString)));

                  if LOutQuery.FieldByName('TestDescription').IsNull or
                     (Trim(LOutQuery.FieldByName('TestDescription').AsString) = '') then
                    LOutObj.AddPair('description', TJSONNull.Create)
                  else
                    LOutObj.AddPair('description',
                      TJSONString.Create(
                        Trim(LOutQuery.FieldByName('TestDescription').AsString)));

                  if LOutQuery.FieldByName('TestValue').IsNull or
                     (Trim(LOutQuery.FieldByName('TestValue').AsString) = '') then
                    LOutObj.AddPair('expected_value', TJSONNull.Create)
                  else
                    LOutObj.AddPair('expected_value',
                      TJSONString.Create(
                        Trim(LOutQuery.FieldByName('TestValue').AsString)));

                  if LOutQuery.FieldByName('TestActualValue').IsNull or
                     (Trim(LOutQuery.FieldByName('TestActualValue').AsString) = '') then
                    LOutObj.AddPair('actual_value', TJSONNull.Create)
                  else
                    LOutObj.AddPair('actual_value',
                      TJSONString.Create(
                        Trim(LOutQuery.FieldByName('TestActualValue').AsString)));

                  if LOutQuery.FieldByName('TestNotes').IsNull or
                     (Trim(LOutQuery.FieldByName('TestNotes').AsString) = '') then
                    LOutObj.AddPair('notes', TJSONNull.Create)
                  else
                    LOutObj.AddPair('notes',
                      TJSONString.Create(
                        Trim(LOutQuery.FieldByName('TestNotes').AsString)));

                  if LOutQuery.FieldByName('TestPass').IsNull then
                    LOutObj.AddPair('pass', TJSONFalse.Create)
                  else if LOutQuery.FieldByName('TestPass').AsBoolean then
                    LOutObj.AddPair('pass', TJSONTrue.Create)
                  else
                    LOutObj.AddPair('pass', TJSONFalse.Create);

                  if LOutQuery.FieldByName('TestFail').IsNull then
                    LOutObj.AddPair('fail', TJSONFalse.Create)
                  else if LOutQuery.FieldByName('TestFail').AsBoolean then
                    LOutObj.AddPair('fail', TJSONTrue.Create)
                  else
                    LOutObj.AddPair('fail', TJSONFalse.Create);

                  if LOutQuery.FieldByName('TestNA').IsNull then
                    LOutObj.AddPair('na', TJSONFalse.Create)
                  else if LOutQuery.FieldByName('TestNA').AsBoolean then
                    LOutObj.AddPair('na', TJSONTrue.Create)
                  else
                    LOutObj.AddPair('na', TJSONFalse.Create);

                  LOutputs.AddElement(LOutObj);
                  LOutQuery.Next;
                end;

                LCertObj.AddPair('outputs', LOutputs);
                LData.AddElement(LCertObj);
                LCertQuery.Next;
              end;
            finally
              LOutQuery.Free;
            end;
          finally
            LCertQuery.Free;
          end;
        finally
          LConn.Free;
        end;

        LResponse := TJSONObject.Create;
        LResponse.AddPair('data', LData);
        Res.Send<TJSONObject>(LResponse);
      end);
```

- [ ] **Step 2: Build in RAD Studio and smoke-test**

Open RAD Studio → press F9 (run). In PowerShell:

```powershell
$r = Invoke-RestMethod -Method Post -Uri "http://localhost:9000/auth/login" `
  -ContentType "application/json" `
  -Body '{"username":"tech1","password":"Test1234!","db":"Stat_Trac"}'
$tok = $r.token.access_token

Invoke-RestMethod `
  -Uri "http://localhost:9000/certificates/history?technician_id=5&after_id=0" `
  -Headers @{Authorization="Bearer $tok"}
```

Expected: JSON with `data` array (may be empty if tech_id=5 has no certs — try a different technician_id if needed).

- [ ] **Step 3: Commit Delphi changes**

```
git -C "C:\Delphi\StatTracTechAPI" add src/Certificates.Routes.pas
git -C "C:\Delphi\StatTracTechAPI" commit -m "feat(cert): add GET /certificates/history — cert headers + outputs for technician sync"
```

---

## Task 2: Flutter — fromJson factory on TestCertificateModel

**Files:**
- Modify: `lib/features/certification/data/models/test_certificate_model.dart`

The JSON keys from `GET /certificates/history` differ from SQLite column names. `fromJson` maps server JSON → entity. The local `id` is 0 (placeholder — SQLite assigns it on insert). Signatures are not in the server response.

- [ ] **Step 1: Add the factory**

Open [test_certificate_model.dart](lib/features/certification/data/models/test_certificate_model.dart).

After the `fromMap` factory (line 27), add:

```dart
  factory TestCertificateModel.fromJson(Map<String, dynamic> j) {
    final testDateStr = j['test_date'] as String?;
    final nextServiceStr = j['next_service'] as String?;
    return TestCertificateModel(
      id: 0,
      serverId: j['id'] as int,
      assetId: j['asset_id'] as int?,
      testDate: testDateStr != null ? DateTime.tryParse(testDateStr) : null,
      certType: j['cert_type'] as int? ?? 1,
      templateNameId: j['template_name_id'] as int?,
      technician: j['technician'] as String?,
      technicianId: j['technician_id'] as int?,
      nextService: nextServiceStr != null ? DateTime.tryParse(nextServiceStr) : null,
      woNumber: j['wo_number'] as int?,
      jobcardNo: j['jobcard_no'] as String?,
      docNo: j['doc_no'] as String?,
      serviceInterval: j['service_interval'] as String?,
      serviceType: j['service_type'] as String?,
      clientName: j['client_name'] as String?,
      syncStatus: 'synced',
      createdAt: testDateStr != null
          ? (DateTime.tryParse(testDateStr) ?? DateTime.now())
          : DateTime.now(),
    );
  }
```

- [ ] **Step 2: Run flutter analyze**

```
flutter analyze lib/features/certification/data/models/test_certificate_model.dart
```
Expected: No issues.

- [ ] **Step 3: Commit**

```
git add lib/features/certification/data/models/test_certificate_model.dart
git commit -m "feat(cert): add fromJson factory to TestCertificateModel for server history pull"
```

---

## Task 3: Flutter — fromJson factory on TestOutputModel

**Files:**
- Modify: `lib/features/certification/data/models/test_output_model.dart`

`certificateId` is 0 as a placeholder; the repository sets the real local cert ID before inserting.

- [ ] **Step 1: Add the factory**

Open [test_output_model.dart](lib/features/certification/data/models/test_output_model.dart).

After the `fromMap` factory (line 18), add:

```dart
  factory TestOutputModel.fromJson(Map<String, dynamic> j, {int certificateId = 0}) =>
      TestOutputModel(
        id: 0,
        certificateId: certificateId,
        descriptionId: j['description_id'] as String?,
        description: j['description'] as String?,
        expectedValue: j['expected_value'] as String?,
        actualValue: j['actual_value'] as String?,
        notes: j['notes'] as String?,
        pass: j['pass'] as bool? ?? false,
        fail: j['fail'] as bool? ?? false,
        na: j['na'] as bool? ?? false,
      );
```

- [ ] **Step 2: Run flutter analyze**

```
flutter analyze lib/features/certification/data/models/test_output_model.dart
```
Expected: No issues.

- [ ] **Step 3: Commit**

```
git add lib/features/certification/data/models/test_output_model.dart
git commit -m "feat(cert): add fromJson factory to TestOutputModel"
```

---

## Task 4: Flutter — Add fetchCertificateHistory to CertRemoteDataSource

**Files:**
- Modify: `lib/features/certification/data/datasources/cert_remote_data_source.dart`

Returns a list of Dart records — each record is a cert model paired with its output models. No new classes needed.

- [ ] **Step 1: Update the interface and implementation**

Open [cert_remote_data_source.dart](lib/features/certification/data/datasources/cert_remote_data_source.dart).

Add the import at the top:
```dart
import '../models/test_certificate_model.dart';
import '../models/test_output_model.dart';
```

Add the method signature to the abstract interface:
```dart
abstract interface class CertRemoteDataSource {
  Future<List<TestTemplateNameModel>> fetchTemplates(int type);
  Future<List<TestTemplateItemModel>> fetchTemplateItems(int templateId);
  Future<int> pushCertificate(Map<String, dynamic> payload);

  /// GET /certificates/history?technician_id=<id>&after_id=<cursor>
  /// Returns cert + embedded outputs for certs the technician created on the
  /// server that are not yet in local SQLite.
  Future<List<(TestCertificateModel, List<TestOutputModel>)>>
      fetchCertificateHistory(int technicianId, int afterId);
}
```

Add the implementation to `CertRemoteDataSourceImpl`:
```dart
  @override
  Future<List<(TestCertificateModel, List<TestOutputModel>)>>
      fetchCertificateHistory(int technicianId, int afterId) async {
    final response = await _dio.get(
      '/certificates/history',
      queryParameters: {
        'technician_id': technicianId,
        'after_id': afterId,
      },
    );
    final data =
        (response.data['data'] as List).cast<Map<String, dynamic>>();
    return data.map((j) {
      final cert = TestCertificateModel.fromJson(j);
      final rawOutputs =
          (j['outputs'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final outputs = rawOutputs
          .map((o) => TestOutputModel.fromJson(o))
          .toList();
      return (cert, outputs);
    }).toList();
  }
```

- [ ] **Step 2: Run flutter analyze**

```
flutter analyze lib/features/certification/data/datasources/cert_remote_data_source.dart
```
Expected: No issues.

- [ ] **Step 3: Commit**

```
git add lib/features/certification/data/datasources/cert_remote_data_source.dart
git commit -m "feat(cert): add fetchCertificateHistory to CertRemoteDataSource"
```

---

## Task 5: Flutter — Add cursor + upsert methods to CertLocalDataSource

**Files:**
- Modify: `lib/features/certification/data/datasources/cert_local_data_source.dart`

Three new methods:
- `getMaxServerId()` — returns the ID cursor for the next pull
- `insertCertificateFromServer(cert)` — inserts only if `server_id` not already local; returns local `id` or `null` if skipped
- `insertOutputsForCert(localCertId, outputs)` — bulk-inserts outputs for a newly-inserted cert

Locally-created certs already have `server_id` set by `markSynced()`, so `insertCertificateFromServer` skips them and their signatures are preserved.

- [ ] **Step 1: Add to the abstract interface**

Open [cert_local_data_source.dart](lib/features/certification/data/datasources/cert_local_data_source.dart).

In `abstract interface class CertLocalDataSource`, add after `getCertificateById`:

```dart
  /// Returns the highest server_id stored locally (0 if none).
  /// Used as the after_id cursor for GET /certificates/history.
  Future<int> getMaxServerId();

  /// Inserts a server-sourced cert if it is not already in local SQLite
  /// (checked by server_id). Returns the new local autoincrement id, or
  /// null if the cert was skipped because it already exists.
  Future<int?> insertCertificateFromServer(TestCertificateModel cert);

  /// Bulk-inserts outputs for a cert that was just inserted by
  /// insertCertificateFromServer. certificateId in each model is ignored —
  /// localCertId is used instead.
  Future<void> insertOutputsForCert(
      int localCertId, List<TestOutputModel> outputs);
```

- [ ] **Step 2: Add to the implementation class**

In `CertLocalDataSourceImpl`, add after the `getCertificateById` method:

```dart
  @override
  Future<int> getMaxServerId() async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT MAX(server_id) AS max_id FROM test_certificates',
    );
    return (result.first['max_id'] as int?) ?? 0;
  }

  @override
  Future<int?> insertCertificateFromServer(TestCertificateModel cert) async {
    final db = await _db.database;
    final existing = await db.query(
      'test_certificates',
      columns: ['id'],
      where: 'server_id = ?',
      whereArgs: [cert.serverId],
    );
    if (existing.isNotEmpty) return null; // already have this cert
    return db.insert('test_certificates', cert.toMap());
  }

  @override
  Future<void> insertOutputsForCert(
      int localCertId, List<TestOutputModel> outputs) async {
    final db = await _db.database;
    final batch = db.batch();
    for (final o in outputs) {
      final map = o.toMap();
      map['certificate_id'] = localCertId;
      batch.insert('test_outputs', map);
    }
    await batch.commit(noResult: true);
  }
```

- [ ] **Step 3: Run flutter analyze**

```
flutter analyze lib/features/certification/data/datasources/cert_local_data_source.dart
```
Expected: No issues.

- [ ] **Step 4: Commit**

```
git add lib/features/certification/data/datasources/cert_local_data_source.dart
git commit -m "feat(cert): add getMaxServerId, insertCertificateFromServer, insertOutputsForCert to CertLocalDataSource"
```

---

## Task 6: Flutter — Add pullCertificatesFromRemote to domain interface and implement

**Files:**
- Modify: `lib/features/certification/domain/repositories/certificate_repository.dart`
- Modify: `lib/features/certification/data/repositories/certificate_repository_impl.dart`

- [ ] **Step 1: Add to the domain interface**

Open [certificate_repository.dart](lib/features/certification/domain/repositories/certificate_repository.dart).

Add at the end of the abstract class:

```dart
  /// Pulls certs and their outputs from the server for the given technician
  /// that are not yet stored locally. Uses MAX(server_id) as the cursor.
  Future<void> pullCertificatesFromRemote(int technicianId);
```

- [ ] **Step 2: Implement in the repository**

Open [certificate_repository_impl.dart](lib/features/certification/data/repositories/certificate_repository_impl.dart).

Add at the end of the class (after `syncTemplatesFromRemote`):

```dart
  @override
  Future<void> pullCertificatesFromRemote(int technicianId) async {
    final afterId = await local.getMaxServerId();
    final records =
        await remote.fetchCertificateHistory(technicianId, afterId);

    for (final (cert, outputs) in records) {
      final localId = await local.insertCertificateFromServer(cert);
      if (localId != null && outputs.isNotEmpty) {
        await local.insertOutputsForCert(localId, outputs);
      }
    }
  }
```

- [ ] **Step 3: Run flutter analyze**

```
flutter analyze lib/features/certification/
```
Expected: No issues.

- [ ] **Step 4: Commit**

```
git add lib/features/certification/domain/repositories/certificate_repository.dart
git add lib/features/certification/data/repositories/certificate_repository_impl.dart
git commit -m "feat(cert): implement pullCertificatesFromRemote — cursor-based pull from server"
```

---

## Task 7: Flutter — Wire pull step into SyncNotifier

**Files:**
- Modify: `lib/sync/sync_notifier.dart`

Pull happens **after** push so that any cert just pushed (now has a `server_id`) is not re-fetched on the same cycle (the updated `MAX(server_id)` already covers it). The technician ID comes from `authNotifierProvider` state.

- [ ] **Step 1: Add the pull step**

Open [sync_notifier.dart](lib/sync/sync_notifier.dart).

Find the existing `pushPendingCertificates` block (lines 106–116):

```dart
    // Push pending certificates to the server.
    try {
      await ref.read(certificateRepositoryProvider).pushPendingCertificates();
      await errorLog.markResolved('push_certificates');
    } on Exception catch (e, st) {
      await errorLog.logError(
        operation: 'push_certificates',
        entityTable: 'test_certificates',
        errorMessage: e.toString(),
        stackTrace: st.toString(),
      );
    }
```

Replace it with (push first, then pull):

```dart
    // Push pending certificates to the server.
    try {
      await ref.read(certificateRepositoryProvider).pushPendingCertificates();
      await errorLog.markResolved('push_certificates');
    } on Exception catch (e, st) {
      await errorLog.logError(
        operation: 'push_certificates',
        entityTable: 'test_certificates',
        errorMessage: e.toString(),
        stackTrace: st.toString(),
      );
    }

    // Pull certificates from the server for this technician.
    final authState = ref.read(authNotifierProvider);
    final technicianId = switch (authState) {
      AuthAuthenticated(:final user) => user.id,
      _ => 0,
    };
    if (technicianId > 0) {
      try {
        await ref
            .read(certificateRepositoryProvider)
            .pullCertificatesFromRemote(technicianId);
        await errorLog.markResolved('pull_certificates');
      } on Exception catch (e, st) {
        await errorLog.logError(
          operation: 'pull_certificates',
          entityTable: 'test_certificates',
          errorMessage: e.toString(),
          stackTrace: st.toString(),
        );
      }
    }
```

Also add the missing import at the top of the file (check if already present before adding):

```dart
import '../features/auth/presentation/providers/auth_state.dart';
```

- [ ] **Step 2: Run build_runner**

```
dart run build_runner build --delete-conflicting-outputs
```
Expected: `sync_notifier.g.dart` regenerated with no errors.

- [ ] **Step 3: Run flutter analyze**

```
flutter analyze
```
Expected: No issues.

- [ ] **Step 4: Run tests**

```
flutter test
```
Expected: All tests pass.

- [ ] **Step 5: Commit**

```
git add lib/sync/sync_notifier.dart lib/sync/sync_notifier.g.dart
git commit -m "feat(cert): pull certificates from master DB on each sync cycle"
```

---

## Self-Review

**Spec coverage:**
- ✅ New Horse API endpoint `GET /certificates/history` with technician + cursor params
- ✅ `fromJson` factories on both cert and output models
- ✅ `fetchCertificateHistory` on remote data source
- ✅ Cursor (`getMaxServerId`) + insert methods on local data source
- ✅ `pullCertificatesFromRemote` in domain interface and implementation
- ✅ SyncNotifier wires pull after push
- ✅ Locally-created certs (already have `server_id`) skipped — signatures preserved
- ✅ List screen: no change needed (reads from SQLite, auto-shows pulled certs)
- ✅ Detail screen: no change needed (reads outputs from SQLite)

**Placeholder scan:** None found — all steps contain complete code.

**Type consistency:**
- `insertCertificateFromServer` returns `Future<int?>` in both interface and impl ✅
- `fetchCertificateHistory` returns `List<(TestCertificateModel, List<TestOutputModel>)>` in both interface and impl ✅
- `TestCertificateModel.fromJson` sets `id: 0, serverId: j['id']` — consistent with `toMap()` which skips `id` when 0 ✅
- `TestOutputModel.fromJson` sets `id: 0, certificateId: certificateId` — `toMap()` skips `id` when 0, but `insertOutputsForCert` overwrites `certificate_id` before insert ✅
