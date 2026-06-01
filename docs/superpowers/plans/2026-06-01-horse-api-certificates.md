# Horse API Certificate Endpoints Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement 3 certificate REST endpoints in the Delphi Horse API and replace the Flutter stub implementations with real Dio calls + template sync.

**Architecture:** New `Certificates.Routes.pas` follows the identical pattern as `WorkOrders.Routes.pas` — JWT middleware, UniDAC queries, WriteSyncLog. Flutter's `CertRemoteDataSourceImpl` gets a real Dio client and `SyncNotifier.triggerSync()` gains a template sync step after asset sync.

**Tech Stack:** Delphi 12 / Horse framework / UniDAC / PostgreSQL on the server; Flutter / Dio / Riverpod 3 / sqflite on the client.

---

## File Map

| File | Action | Purpose |
|---|---|---|
| `C:\Delphi\StatTracTechAPI\src\Certificates.Routes.pas` | Create | 3 certificate endpoints |
| `C:\Delphi\StatTracTechAPI\StatTracTechAPI.dpr` | Modify | Register certificate routes |
| `lib/features/certification/data/models/test_template_name_model.dart` | Modify | Add `fromJson` factory |
| `lib/features/certification/data/models/test_template_item_model.dart` | Modify | Add `fromJson` factory |
| `lib/features/certification/data/datasources/cert_remote_data_source.dart` | Modify | Replace stubs with real Dio calls |
| `lib/features/certification/presentation/providers/certificate_providers.dart` | Modify | Pass Dio client to remote data source |
| `lib/features/certification/presentation/providers/certificate_providers.g.dart` | Regenerate | build_runner output |
| `lib/features/certification/data/repositories/certificate_repository_impl.dart` | Modify | Implement `syncTemplatesFromRemote()` |
| `lib/sync/sync_notifier.dart` | Modify | Add template sync step to `triggerSync()` |

---

## Task 1: Delphi — Certificates.Routes.pas

**Files:**
- Create: `C:\Delphi\StatTracTechAPI\src\Certificates.Routes.pas`

- [ ] **Step 1: Create the file**

```pascal
unit Certificates.Routes;

interface

procedure RegisterCertificateRoutes;

implementation

uses
  Horse,
  Horse.JWT,
  Horse.Jhonson,
  System.JSON,
  System.SysUtils,
  System.NetEncoding,
  Uni,
  PostgreSQLUniProvider,
  Database.Connection,
  SyncLog;

const
  JWT_SECRET = 'stat-trac-secret-CHANGE-IN-PRODUCTION';

function ExtractDbName(Req: THorseRequest): string;
var
  LPayload: TJSONObject;
begin
  Result := '';
  try
    LPayload := Req.Session<TJSONObject>;
    if Assigned(LPayload) then
      Result := LPayload.GetValue('db').Value;
  except
    Result := '';
  end;
end;

procedure RegisterCertificateRoutes;
begin

  // ── GET /certificates/templates?type=<1|2|3> ─────────────────────────────────
  // Returns TestTemplateName rows filtered by type.
  // type: 1=Test/OVP, 2=QA, 3=Commission
  THorse
    .AddCallback(HorseJWT(JWT_SECRET))
    .Get('/certificates/templates',
      procedure(Req: THorseRequest; Res: THorseResponse)
      var
        LType: Integer;
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

        LType := StrToIntDef(Req.Query.Field('type').AsString, 0);
        if not (LType in [1, 2, 3]) then
        begin
          Res.Status(THTTPStatus.BadRequest).Send('type must be 1, 2 or 3');
          Exit;
        end;

        LConn := NewDBConnection(ExtractDbName(Req));
        try
          LQuery := TUniQuery.Create(nil);
          try
            LQuery.Connection := LConn;
            LQuery.SQL.Text :=
              'SELECT "TestTemplateNameID", "TestTemplateName", "TestTemplateCertName", ' +
              '       "TestTemplateType", "TestTemplateCustomerSig", ' +
              '       "TestTemplateDocNo", "TestTemplateNote" ' +
              'FROM "TestTemplateName" ' +
              'WHERE "TestTemplateType" = :ttype ' +
              'ORDER BY "TestTemplateCertName" ASC';
            LQuery.ParamByName('ttype').AsInteger := LType;
            LQuery.Open;

            LData := TJSONArray.Create;
            while not LQuery.Eof do
            begin
              LRow := TJSONObject.Create;
              LRow.AddPair('id',   TJSONNumber.Create(
                LQuery.FieldByName('TestTemplateNameID').AsInteger));
              LRow.AddPair('type', TJSONNumber.Create(
                LQuery.FieldByName('TestTemplateType').AsInteger));

              if LQuery.FieldByName('TestTemplateName').IsNull or
                 (Trim(LQuery.FieldByName('TestTemplateName').AsString) = '') then
                LRow.AddPair('name', TJSONNull.Create)
              else
                LRow.AddPair('name',
                  TJSONString.Create(Trim(LQuery.FieldByName('TestTemplateName').AsString)));

              if LQuery.FieldByName('TestTemplateCertName').IsNull or
                 (Trim(LQuery.FieldByName('TestTemplateCertName').AsString) = '') then
                LRow.AddPair('cert_name', TJSONNull.Create)
              else
                LRow.AddPair('cert_name',
                  TJSONString.Create(Trim(LQuery.FieldByName('TestTemplateCertName').AsString)));

              var LSig := LQuery.FieldByName('TestTemplateCustomerSig');
              if LSig.IsNull or (LSig.AsInteger = 0) then
                LRow.AddPair('customer_sig_required', TJSONFalse.Create)
              else
                LRow.AddPair('customer_sig_required', TJSONTrue.Create);

              if LQuery.FieldByName('TestTemplateDocNo').IsNull or
                 (Trim(LQuery.FieldByName('TestTemplateDocNo').AsString) = '') then
                LRow.AddPair('doc_no', TJSONNull.Create)
              else
                LRow.AddPair('doc_no',
                  TJSONString.Create(Trim(LQuery.FieldByName('TestTemplateDocNo').AsString)));

              if LQuery.FieldByName('TestTemplateNote').IsNull or
                 (Trim(LQuery.FieldByName('TestTemplateNote').AsString) = '') then
                LRow.AddPair('note', TJSONNull.Create)
              else
                LRow.AddPair('note',
                  TJSONString.Create(Trim(LQuery.FieldByName('TestTemplateNote').AsString)));

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

  // ── GET /certificates/templates/:id/items ────────────────────────────────────
  // Returns TestTemplate rows for the given TestTemplateNameID.
  THorse
    .AddCallback(HorseJWT(JWT_SECRET))
    .Get('/certificates/templates/:id/items',
      procedure(Req: THorseRequest; Res: THorseResponse)
      var
        LId: Integer;
        LConn: TUniConnection;
        LQuery, LCheck: TUniQuery;
        LData: TJSONArray;
        LRow: TJSONObject;
        LResponse: TJSONObject;
      begin
        if ExtractDbName(Req).IsEmpty then
        begin
          Res.Status(THTTPStatus.Unauthorized).Send('Missing db claim');
          Exit;
        end;

        LId := StrToIntDef(Req.Params.Field('id').AsString, 0);
        if LId <= 0 then
        begin
          Res.Status(THTTPStatus.BadRequest).Send('Invalid template id');
          Exit;
        end;

        LConn := NewDBConnection(ExtractDbName(Req));
        try
          // Verify the template exists.
          LCheck := TUniQuery.Create(nil);
          try
            LCheck.Connection := LConn;
            LCheck.SQL.Text :=
              'SELECT 1 FROM "TestTemplateName" WHERE "TestTemplateNameID" = :id';
            LCheck.ParamByName('id').AsInteger := LId;
            LCheck.Open;
            if LCheck.IsEmpty then
            begin
              Res.Status(THTTPStatus.NotFound).Send('Template not found');
              Exit;
            end;
          finally
            LCheck.Free;
          end;

          LQuery := TUniQuery.Create(nil);
          try
            LQuery.Connection := LConn;
            LQuery.SQL.Text :=
              'SELECT "TestTemplateID", "TestTempCertificateNameID", ' +
              '       "TestTempDescriptionID", "TestTempDescriptionNo", ' +
              '       "TestTempDescription", "TestTempNotes", "TestTempValue" ' +
              'FROM "TestTemplate" ' +
              'WHERE "TestTempCertificateNameID" = :id ' +
              'ORDER BY "TestTempDescriptionNo" ASC, "TestTemplateID" ASC';
            LQuery.ParamByName('id').AsInteger := LId;
            LQuery.Open;

            LData := TJSONArray.Create;
            while not LQuery.Eof do
            begin
              LRow := TJSONObject.Create;
              LRow.AddPair('id',
                TJSONNumber.Create(LQuery.FieldByName('TestTemplateID').AsInteger));
              LRow.AddPair('certificate_name_id',
                TJSONNumber.Create(LQuery.FieldByName('TestTempCertificateNameID').AsInteger));

              if LQuery.FieldByName('TestTempDescriptionID').IsNull or
                 (Trim(LQuery.FieldByName('TestTempDescriptionID').AsString) = '') then
                LRow.AddPair('description_id', TJSONNull.Create)
              else
                LRow.AddPair('description_id',
                  TJSONString.Create(Trim(LQuery.FieldByName('TestTempDescriptionID').AsString)));

              if LQuery.FieldByName('TestTempDescriptionNo').IsNull then
                LRow.AddPair('description_no', TJSONNull.Create)
              else
                LRow.AddPair('description_no',
                  TJSONNumber.Create(LQuery.FieldByName('TestTempDescriptionNo').AsInteger));

              if LQuery.FieldByName('TestTempDescription').IsNull or
                 (Trim(LQuery.FieldByName('TestTempDescription').AsString) = '') then
                LRow.AddPair('description', TJSONNull.Create)
              else
                LRow.AddPair('description',
                  TJSONString.Create(Trim(LQuery.FieldByName('TestTempDescription').AsString)));

              if LQuery.FieldByName('TestTempNotes').IsNull or
                 (Trim(LQuery.FieldByName('TestTempNotes').AsString) = '') then
                LRow.AddPair('notes', TJSONNull.Create)
              else
                LRow.AddPair('notes',
                  TJSONString.Create(Trim(LQuery.FieldByName('TestTempNotes').AsString)));

              if LQuery.FieldByName('TestTempValue').IsNull or
                 (Trim(LQuery.FieldByName('TestTempValue').AsString) = '') then
                LRow.AddPair('expected_value', TJSONNull.Create)
              else
                LRow.AddPair('expected_value',
                  TJSONString.Create(Trim(LQuery.FieldByName('TestTempValue').AsString)));

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

  // ── POST /certificates ────────────────────────────────────────────────────────
  // Saves a completed certificate: 1 TestCertificate row + N TestOutput rows.
  // Returns { "id": <TestCertificateID> }
  THorse
    .AddCallback(HorseJWT(JWT_SECRET))
    .Post('/certificates',
      procedure(Req: THorseRequest; Res: THorseResponse)
      var
        LBody: TJSONObject;
        LOutputs: TJSONArray;
        LOutput: TJSONValue;
        LOutObj: TJSONObject;
        LConn: TUniConnection;
        LInsertCert, LInsertOut: TUniQuery;
        LNewCertId, LAssetId: Integer;
        LTechSig64, LClientSig64: string;
        LTechSigBytes, LClientSigBytes: TBytes;
        LVal: TJSONValue;

        function BodyStr(const AKey: string): string;
        var V: TJSONValue;
        begin
          V := LBody.GetValue(AKey);
          if (V = nil) or (V is TJSONNull) then Result := ''
          else Result := Trim(V.Value);
        end;

        function BodyInt(const AKey: string): Integer;
        var V: TJSONValue;
        begin
          V := LBody.GetValue(AKey);
          if (V = nil) or (V is TJSONNull) then Result := 0
          else Result := (V as TJSONNumber).AsInt;
        end;

        function OutStr(Obj: TJSONObject; const AKey: string): string;
        var V: TJSONValue;
        begin
          V := Obj.GetValue(AKey);
          if (V = nil) or (V is TJSONNull) then Result := ''
          else Result := Trim(V.Value);
        end;

        function OutBool(Obj: TJSONObject; const AKey: string): Boolean;
        var V: TJSONValue;
        begin
          V := Obj.GetValue(AKey);
          Result := (V <> nil) and (V is TJSONTrue);
        end;

      begin
        if ExtractDbName(Req).IsEmpty then
        begin
          Res.Status(THTTPStatus.Unauthorized).Send('Missing db claim');
          Exit;
        end;

        LBody := Req.Body<TJSONObject>;
        if not Assigned(LBody) then
        begin
          Res.Status(THTTPStatus.BadRequest).Send('Missing JSON body');
          Exit;
        end;

        LVal := LBody.GetValue('asset_id');
        if (LVal = nil) or (LVal is TJSONNull) then
        begin
          Res.Status(THTTPStatus.BadRequest).Send('asset_id is required');
          Exit;
        end;

        LOutputs := LBody.GetValue('outputs') as TJSONArray;
        if not Assigned(LOutputs) then
        begin
          Res.Status(THTTPStatus.BadRequest).Send('outputs array is required');
          Exit;
        end;

        LAssetId := BodyInt('asset_id');

        // Decode base64 signatures to bytes.
        LTechSig64 := BodyStr('tech_signature');
        if not LTechSig64.IsEmpty then
          LTechSigBytes := TNetEncoding.Base64.DecodeStringToBytes(LTechSig64)
        else
          SetLength(LTechSigBytes, 0);

        LClientSig64 := BodyStr('client_signature');
        if not LClientSig64.IsEmpty then
          LClientSigBytes := TNetEncoding.Base64.DecodeStringToBytes(LClientSig64)
        else
          SetLength(LClientSigBytes, 0);

        LConn := NewDBConnection(ExtractDbName(Req));
        try
          LInsertCert := TUniQuery.Create(nil);
          try
            LInsertCert.Connection := LConn;
            LInsertCert.SQL.Text :=
              'INSERT INTO "TestCertificate" ' +
              '  ("TestAssetID", "TestDate", "TestCertType", "TestType", ' +
              '   "TestTech", "TestTechID", "TestDocNo", ' +
              '   "TestTechSignature", "TestClientSignature", "TestClientNameSignature") ' +
              'VALUES ' +
              '  (:asset_id, :test_date, :cert_type, :test_type, ' +
              '   :technician, :technician_id, :doc_no, ' +
              '   :tech_sig, :client_sig, :client_name) ' +
              'RETURNING "TestCertificateID"';

            LInsertCert.ParamByName('asset_id').AsInteger      := LAssetId;
            LInsertCert.ParamByName('test_type').AsInteger     := BodyInt('cert_type');
            LInsertCert.ParamByName('cert_type').AsInteger     := BodyInt('template_name_id');
            LInsertCert.ParamByName('technician').AsString     := BodyStr('technician');
            LInsertCert.ParamByName('technician_id').AsInteger := BodyInt('technician_id');
            LInsertCert.ParamByName('doc_no').AsString         := BodyStr('doc_no');
            LInsertCert.ParamByName('client_name').AsString    := BodyStr('client_name');

            var LDateStr := BodyStr('test_date');
            if LDateStr.IsEmpty then
              LInsertCert.ParamByName('test_date').AsDateTime := Date
            else
              LInsertCert.ParamByName('test_date').AsDateTime :=
                StrToDateDef(Copy(LDateStr, 1, 10), Date);

            if Length(LTechSigBytes) > 0 then
              LInsertCert.ParamByName('tech_sig').AsBytes := LTechSigBytes
            else
              LInsertCert.ParamByName('tech_sig').Clear;

            if Length(LClientSigBytes) > 0 then
              LInsertCert.ParamByName('client_sig').AsBytes := LClientSigBytes
            else
              LInsertCert.ParamByName('client_sig').Clear;

            LInsertCert.Open;
            LNewCertId := LInsertCert.Fields[0].AsInteger;
          finally
            LInsertCert.Free;
          end;

          // Insert one TestOutput row per output item.
          LInsertOut := TUniQuery.Create(nil);
          try
            LInsertOut.Connection := LConn;
            LInsertOut.SQL.Text :=
              'INSERT INTO "TestOutput" ' +
              '  ("TestOutputCertID", "TestOutputAssetID", "TestDescriptionID", ' +
              '   "TestDescription", "TestValue", "TestActualValue", ' +
              '   "TestPass", "TestFail", "TestNA") ' +
              'VALUES ' +
              '  (:cert_id, :asset_id, :desc_id, ' +
              '   :description, :expected_value, :actual_value, ' +
              '   :pass, :fail, :na)';

            for LOutput in LOutputs do
            begin
              LOutObj := LOutput as TJSONObject;
              LInsertOut.ParamByName('cert_id').AsInteger    := LNewCertId;
              LInsertOut.ParamByName('asset_id').AsInteger   := LAssetId;
              LInsertOut.ParamByName('desc_id').AsString     := OutStr(LOutObj, 'description_id');
              LInsertOut.ParamByName('description').AsString := OutStr(LOutObj, 'description');
              LInsertOut.ParamByName('expected_value').AsString := OutStr(LOutObj, 'expected_value');
              LInsertOut.ParamByName('actual_value').AsString   := OutStr(LOutObj, 'actual_value');
              LInsertOut.ParamByName('pass').AsBoolean := OutBool(LOutObj, 'pass');
              LInsertOut.ParamByName('fail').AsBoolean := OutBool(LOutObj, 'fail');
              LInsertOut.ParamByName('na').AsBoolean   := OutBool(LOutObj, 'na');
              LInsertOut.Execute;
            end;
          finally
            LInsertOut.Free;
          end;
        finally
          LConn.Free;
        end;

        WriteSyncLog(Req, 'push_certificate', 'TestCertificate', LNewCertId,
          LOutputs.Count, 'success', '');

        var LResp := TJSONObject.Create;
        LResp.AddPair('id', TJSONNumber.Create(LNewCertId));
        Res.Status(THTTPStatus.Created).Send<TJSONObject>(LResp);
      end);

end;

end.
```

- [ ] **Step 2: Verify the file compiles — open RAD Studio, add the file to the project, build**

Open `C:\Delphi\StatTracTechAPI\StatTracTechAPI.dpr` in RAD Studio.
In Project Manager, right-click → Add → select `src\Certificates.Routes.pas`.
Press F9 (Build).
Expected: Build succeeds with no errors.

If `StrToDateDef` is not available, replace with:
```pascal
LInsertCert.ParamByName('test_date').AsDateTime :=
  StrToDateTimeDef(Copy(LDateStr, 1, 10), Date);
```

- [ ] **Step 3: Commit (git, not RAD Studio)**

```
git add "C:\Delphi\StatTracTechAPI\src\Certificates.Routes.pas"
git -C "C:\Delphi\StatTracTechAPI" commit -m "feat(cert): add Certificates.Routes.pas — GET templates, GET items, POST certificate"
```

---

## Task 2: Register Certificate Routes in StatTracTechAPI.dpr

**Files:**
- Modify: `C:\Delphi\StatTracTechAPI\StatTracTechAPI.dpr`

- [ ] **Step 1: Add the unit reference and call**

Find the `uses` block and add `Certificates.Routes`:

```pascal
uses
  ...
  Visits.Routes      in 'src\Visits.Routes.pas',
  Certificates.Routes in 'src\Certificates.Routes.pas';  // ADD THIS
```

Find the route registration block and add:

```pascal
    RegisterVisitRoutes;
    RegisterCertificateRoutes;   // ADD THIS
```

- [ ] **Step 2: Build in RAD Studio**

Press F9.
Expected: Build succeeds.

- [ ] **Step 3: Run the server and smoke-test the endpoints**

Press F9 to run. The console shows:
```
StatTrac Technical API
Listening on port 9000
```

From PowerShell (separate terminal), get a JWT first:
```powershell
$r = Invoke-RestMethod -Method Post -Uri "http://localhost:9000/auth/login" `
  -ContentType "application/json" `
  -Body '{"username":"tech1","password":"Test1234!","db":"Stat_Trac"}'
$tok = $r.token.access_token
```

Test template list:
```powershell
Invoke-RestMethod -Uri "http://localhost:9000/certificates/templates?type=1" `
  -Headers @{Authorization="Bearer $tok"}
```
Expected: JSON with `data` array of templates (type 1 = Test/OVP).

Test items for template 41 (Evolution Ventilator):
```powershell
Invoke-RestMethod -Uri "http://localhost:9000/certificates/templates/41/items" `
  -Headers @{Authorization="Bearer $tok"}
```
Expected: JSON with `data` array of test items.

- [ ] **Step 4: Commit**

```
git -C "C:\Delphi\StatTracTechAPI" add StatTracTechAPI.dpr
git -C "C:\Delphi\StatTracTechAPI" commit -m "feat(cert): register certificate routes in main project"
```

---

## Task 3: Flutter — Add fromJson Factories to Template Models

**Files:**
- Modify: `lib/features/certification/data/models/test_template_name_model.dart`
- Modify: `lib/features/certification/data/models/test_template_item_model.dart`

The JSON keys from the API (`id`, `name`, `cert_name`, etc.) differ from the SQLite column names the existing `fromMap` uses (`test_template_name`, `test_template_cert_name`, etc.). Both factories are needed.

- [ ] **Step 1: Add `fromJson` to TestTemplateNameModel**

Open `lib/features/certification/data/models/test_template_name_model.dart`.

After the existing `fromMap` factory, add:

```dart
  factory TestTemplateNameModel.fromJson(Map<String, dynamic> j) =>
      TestTemplateNameModel(
        id: j['id'] as int,
        certType: TestTemplateName.typeFromInt(j['type'] as int?),
        templateName: j['name'] as String?,
        certName: j['cert_name'] as String?,
        customerSigRequired: j['customer_sig_required'] as bool? ?? false,
        docNo: j['doc_no'] as String?,
        note: j['note'] as String?,
        lastSyncedAt: DateTime.now(),
      );
```

- [ ] **Step 2: Add `fromJson` to TestTemplateItemModel**

Open `lib/features/certification/data/models/test_template_item_model.dart`.

After the existing `fromMap` factory, add:

```dart
  factory TestTemplateItemModel.fromJson(Map<String, dynamic> j) =>
      TestTemplateItemModel(
        id: j['id'] as int,
        certificateNameId: j['certificate_name_id'] as int,
        descriptionId: j['description_id'] as String?,
        descriptionNo: j['description_no'] as int?,
        description: j['description'] as String?,
        notes: j['notes'] as String?,
        expectedValue: j['expected_value'] as String?,
      );
```

- [ ] **Step 3: Run flutter analyze**

Run: `flutter analyze lib/features/certification/data/models/`
Expected: No errors.

- [ ] **Step 4: Commit**

```
git add lib/features/certification/data/models/test_template_name_model.dart lib/features/certification/data/models/test_template_item_model.dart
git commit -m "feat(cert): add fromJson factories to template name and item models"
```

---

## Task 4: Flutter — CertRemoteDataSourceImpl with Real Dio Calls

**Files:**
- Modify: `lib/features/certification/data/datasources/cert_remote_data_source.dart`

Replace the stub implementation with a real Dio implementation. The constructor now accepts a `Dio` instance (same pattern as `SyncRemoteDataSourceImpl`).

- [ ] **Step 1: Replace the entire file content**

```dart
import 'package:dio/dio.dart';

import '../models/test_template_name_model.dart';
import '../models/test_template_item_model.dart';

abstract interface class CertRemoteDataSource {
  /// GET /certificates/templates?type=<1|2|3>
  Future<List<TestTemplateNameModel>> fetchTemplates(int type);

  /// GET /certificates/templates/:id/items
  Future<List<TestTemplateItemModel>> fetchTemplateItems(int templateId);

  /// POST /certificates — returns the server-assigned TestCertificateID.
  Future<int> pushCertificate(Map<String, dynamic> payload);
}

class CertRemoteDataSourceImpl implements CertRemoteDataSource {
  CertRemoteDataSourceImpl(this._dio);
  final Dio _dio;

  @override
  Future<List<TestTemplateNameModel>> fetchTemplates(int type) async {
    final response = await _dio.get(
      '/certificates/templates',
      queryParameters: {'type': type},
    );
    final data = (response.data['data'] as List)
        .cast<Map<String, dynamic>>();
    return data.map(TestTemplateNameModel.fromJson).toList();
  }

  @override
  Future<List<TestTemplateItemModel>> fetchTemplateItems(int templateId) async {
    final response =
        await _dio.get('/certificates/templates/$templateId/items');
    final data = (response.data['data'] as List)
        .cast<Map<String, dynamic>>();
    return data.map(TestTemplateItemModel.fromJson).toList();
  }

  @override
  Future<int> pushCertificate(Map<String, dynamic> payload) async {
    final response = await _dio.post('/certificates', data: payload);
    return response.data['id'] as int;
  }
}
```

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze lib/features/certification/data/datasources/cert_remote_data_source.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```
git add lib/features/certification/data/datasources/cert_remote_data_source.dart
git commit -m "feat(cert): replace CertRemoteDataSource stubs with real Dio calls"
```

---

## Task 5: Flutter — Pass Dio to CertRemoteDataSource in Providers

**Files:**
- Modify: `lib/features/certification/presentation/providers/certificate_providers.dart`
- Regenerate: `lib/features/certification/presentation/providers/certificate_providers.g.dart`

The `certRemoteDataSource` provider must now build a Dio client with the auth interceptor, matching how `syncRemoteDataSource` is wired in `sync_notifier.dart`.

- [ ] **Step 1: Update certificate_providers.dart**

Open `lib/features/certification/presentation/providers/certificate_providers.dart`.

Add these imports at the top (after existing imports):

```dart
import '../../../../api/auth_interceptor.dart';
import '../../../../api/dio_client.dart';
import '../../../auth/data/datasources/auth_local_data_source.dart';
import '../../../auth/data/datasources/auth_remote_data_source.dart';
```

Also add this import (already may be present — check first):
```dart
import 'package:dio/dio.dart';
```

Replace the `certRemoteDataSource` provider:

```dart
// BEFORE:
@riverpod
CertRemoteDataSource certRemoteDataSource(Ref ref) =>
    CertRemoteDataSourceImpl();

// AFTER:
@riverpod
CertRemoteDataSource certRemoteDataSource(Ref ref) {
  final authLocal = ref.watch(authLocalDataSourceProvider);
  final authRemote = ref.watch(authRemoteDataSourceProvider);
  final interceptor = AuthInterceptor(local: authLocal, remote: authRemote);
  return CertRemoteDataSourceImpl(buildDioClient(interceptor));
}
```

- [ ] **Step 2: Run code generation**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: No errors, `.g.dart` regenerated.

- [ ] **Step 3: Run flutter analyze**

Run: `flutter analyze lib/features/certification/`
Expected: No errors.

- [ ] **Step 4: Commit**

```
git add lib/features/certification/presentation/providers/
git commit -m "feat(cert): wire auth Dio client into CertRemoteDataSource provider"
```

---

## Task 6: Flutter — Implement syncTemplatesFromRemote()

**Files:**
- Modify: `lib/features/certification/data/repositories/certificate_repository_impl.dart`

Replace the no-op stub with a real implementation that fetches all 3 template types and their items, then upserts them locally.

- [ ] **Step 1: Update certificate_repository_impl.dart**

Open `lib/features/certification/data/repositories/certificate_repository_impl.dart`.

Add these imports at the top:

```dart
import '../models/test_template_item_model.dart';
import '../models/test_template_name_model.dart';
```

Replace the `syncTemplatesFromRemote` method:

```dart
  @override
  Future<void> syncTemplatesFromRemote() async {
    for (final typeInt in [1, 2, 3]) {
      final templates = await remote.fetchTemplates(typeInt);
      if (templates.isEmpty) continue;

      await local.upsertTemplates(templates);

      for (final template in templates) {
        final items = await remote.fetchTemplateItems(template.id);
        if (items.isNotEmpty) {
          await local.upsertTemplateItems(items);
        }
      }
    }
  }
```

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze lib/features/certification/data/repositories/`
Expected: No errors.

- [ ] **Step 3: Commit**

```
git add lib/features/certification/data/repositories/certificate_repository_impl.dart
git commit -m "feat(cert): implement syncTemplatesFromRemote — fetch all types + items from API"
```

---

## Task 7: Flutter — Wire Template Sync into SyncNotifier

**Files:**
- Modify: `lib/sync/sync_notifier.dart`

Add a template sync step after asset sync in `triggerSync()`. Template sync errors are logged to `sync_error_log` the same way asset sync errors are, but do not prevent the overall sync from completing.

- [ ] **Step 1: Add the certificate repository import**

Open `lib/sync/sync_notifier.dart`.

Add this import after the existing imports:

```dart
import '../features/certification/presentation/providers/certificate_providers.dart';
```

- [ ] **Step 2: Add template sync step inside triggerSync()**

Find the `try` block inside `triggerSync()`. The current structure is:

```dart
    try {
      final result = await ref.read(assetRepositoryProvider).syncAssets();
      // ... success handling ...
      state = SyncComplete(DateTime.now());
      ref.invalidate(unresolvedSyncErrorCountProvider);
    } on Exception catch (e, st) {
      // ... error handling ...
    }
```

Replace it with:

```dart
    try {
      final result = await ref.read(assetRepositoryProvider).syncAssets();

      final message = _buildSyncMessage(
          result.rowCount, result.pageCount, result.removedIds, result.changes);
      await syncRemote.postSyncLog(
        entity: 'assets',
        rowCount: result.rowCount,
        status: 'success',
        message: message,
      );

      await errorLog.markResolved('sync_assets');
    } on Exception catch (e, st) {
      await errorLog.logError(
        operation: 'sync_assets',
        entityTable: 'assets',
        errorMessage: e.toString(),
        stackTrace: st.toString(),
      );
      state = SyncError(
        message: _friendlySyncError(e),
        lastSyncedAt: previousSuccess,
      );
      ref.invalidate(unresolvedSyncErrorCountProvider);
      return;
    }

    // Template sync — errors are logged but do not block the overall sync.
    try {
      await ref.read(certificateRepositoryProvider).syncTemplatesFromRemote();
      await errorLog.markResolved('sync_templates');
    } on Exception catch (e, st) {
      await errorLog.logError(
        operation: 'sync_templates',
        entityTable: 'test_template_names',
        errorMessage: e.toString(),
        stackTrace: st.toString(),
      );
    }

    state = SyncComplete(DateTime.now());
    ref.invalidate(unresolvedSyncErrorCountProvider);
```

**Note:** The `_buildSyncMessage` call and `postSyncLog` were previously inside the try block. They stay there — only the `state = SyncComplete` and `ref.invalidate` move to after both sync steps.

- [ ] **Step 3: Run build_runner (sync_notifier has a generated .g.dart)**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: No errors.

- [ ] **Step 4: Run the full test suite**

Run: `flutter test`
Expected: All 13 tests pass.

- [ ] **Step 5: Run flutter analyze**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 6: Commit**

```
git add lib/sync/sync_notifier.dart lib/sync/sync_notifier.g.dart
git commit -m "feat(cert): wire template sync into SyncNotifier — syncs all 3 template types on each cycle"
```

---

## Task 8: End-to-End Integration Test

This task verifies the full pipeline: Horse API → Flutter sync → local SQLite → UI display.

- [ ] **Step 1: Start the Horse API server**

Open RAD Studio, load `StatTracTechAPI.dpr`, press F9. Confirm console shows:
```
StatTrac Technical API
Listening on port 9000
Ready.
```

- [ ] **Step 2: Run the Flutter app on the Android emulator**

Run: `flutter run`
App launches. Log in as `tech1` / `Test1234!`.

- [ ] **Step 3: Trigger sync**

Tap the sync icon in the AppBar, or wait for the post-frame auto-sync.
Watch the console for Horse API requests — you should see:
```
GET /assets
GET /certificates/templates?type=1
GET /certificates/templates?type=2
GET /certificates/templates?type=3
GET /certificates/templates/41/items
... (one per synced template)
```

- [ ] **Step 4: Verify templates loaded in SQLite**

Use Flutter DevTools → App tab → Storage, or add a temporary debug print:
```dart
final db = await DatabaseHelper.instance.database;
final count = Sqflite.firstIntValue(
  await db.rawQuery('SELECT COUNT(*) FROM test_template_names'));
print('Templates in SQLite: $count');
```
Expected: count > 0 (should be 62 if all templates sync).

- [ ] **Step 5: Test Create Certificate flow**

Dashboard → "Create Certificate" → "Test Certificate" → pick any asset → pick a template from the list (should now show real templates from DB) → fill in test items → sign → "Issue Certificate".

Expected:
- Template list shows real templates from `TestTemplateName`
- Test items grid shows real items from `TestTemplate`
- Snackbar: "Certificate saved — PDF will be generated on next sync"

- [ ] **Step 6: Verify TestCertificate row written to PostgreSQL**

```powershell
$env:PGPASSWORD='Cbr900RR'
psql -U postgres -d Stat_Trac -c 'SELECT "TestCertificateID", "TestAssetID", "TestDate", "TestType" FROM "TestCertificate" ORDER BY "TestCertificateID" DESC LIMIT 3;'
```
Expected: The new certificate appears as the latest row.

- [ ] **Step 7: Final commit if any cleanup was needed**

```
git add .
git commit -m "feat(cert): Horse API certificate endpoints fully integrated — templates sync, certificates POST"
```
