# Horse API Certificate Endpoints — Design

Date: 2026-06-01

## Summary

Add 3 certificate endpoints to the Delphi Horse REST API (`StatTracTechAPI`) and replace the Flutter stub implementations with real Dio calls. Certificates are saved to the existing production PostgreSQL tables (`TestCertificate`, `TestOutput`). Templates are read from `TestTemplateName` and `TestTemplate`. No PDF generation on this pass — data save only.

## Scope

### Server side (Delphi)
- New file: `C:\Delphi\StatTracTechAPI\src\Certificates.Routes.pas`
- Register `RegisterCertificateRoutes` in `StatTracTechAPI.dpr`

### Flutter side
- Replace stubs in `lib/features/certification/data/datasources/cert_remote_data_source.dart`
- Add template sync step to `lib/sync/sync_notifier.dart`

## Endpoints

### GET /certificates/templates?type=<1|2|3>

**Purpose:** Sync certificate templates to the Flutter app's local SQLite.

**Auth:** JWT Bearer (existing middleware)

**Query param:** `type` — integer 1=Test/OVP, 2=QA, 3=Commission

**DB query:** `SELECT * FROM "TestTemplateName" WHERE "TestTemplateType" = :type ORDER BY "TestTemplateCertName" ASC`

**Response:**
```json
{
  "data": [
    {
      "id": 41,
      "type": 1,
      "name": "EVOLUTION VENTILATOR - PERFORMANCE VERIFICATION",
      "cert_name": "EVOLUTION VENTILATOR OVP",
      "customer_sig_required": false,
      "doc_no": "TEVO001",
      "note": "Values given in this certificate..."
    }
  ]
}
```

`customer_sig_required` = `TestTemplateCustomerSig IS NOT NULL AND TestTemplateCustomerSig <> 0`

---

### GET /certificates/templates/:id/items

**Purpose:** Load test item checklist for a selected template.

**Auth:** JWT Bearer

**Route param:** `:id` = `TestTemplateNameID`

**DB query:** `SELECT * FROM "TestTemplate" WHERE "TestTempCertificateNameID" = :id ORDER BY "TestTempDescriptionNo" ASC, "TestTemplateID" ASC`

**Response:**
```json
{
  "data": [
    {
      "id": 14,
      "certificate_name_id": 41,
      "description_id": "ELECTRICAL SAFETY TESTS",
      "description_no": 2,
      "description": "Ground Resistance",
      "notes": "",
      "expected_value": "< 0.2 Ohm"
    }
  ]
}
```

Returns 404 if template ID not found in `TestTemplateName`.

---

### POST /certificates

**Purpose:** Save a completed certificate from the Flutter app to the production database.

**Auth:** JWT Bearer

**Request body:**
```json
{
  "asset_id": 1234,
  "cert_type": 1,
  "template_name_id": 41,
  "technician": "tech1",
  "technician_id": 5,
  "test_date": "2026-06-01",
  "doc_no": "TEVO001",
  "tech_signature": "<base64 PNG>",
  "client_signature": null,
  "client_name": null,
  "outputs": [
    {
      "description_id": "ELECTRICAL SAFETY TESTS",
      "description": "Ground Resistance",
      "expected_value": "< 0.2 Ohm",
      "actual_value": "0.12 Ohm",
      "pass": true,
      "fail": false,
      "na": false
    }
  ]
}
```

**Server logic:**
1. Validate body (asset_id required, outputs array required)
2. INSERT into `TestCertificate` — use RETURNING to get `TestCertificateID`
3. For each output: INSERT into `TestOutput` with `TestOutputCertID = TestCertificateID`
4. Call `WriteSyncLog`
5. Return `{ "id": <TestCertificateID> }`

**Column mapping — TestCertificate INSERT:**

| JSON | DB column | Notes |
|---|---|---|
| `asset_id` | `TestAssetID` | integer |
| `cert_type` | `TestType` | integer |
| `template_name_id` | `TestCertType` | integer |
| `technician` | `TestTech` | varchar 40 |
| `technician_id` | `TestTechID` | integer |
| `test_date` | `TestDate` | date |
| `doc_no` | `TestDocNo` | varchar 30 |
| `tech_signature` (base64) | `TestTechSignature` | bytea — decode from base64 |
| `client_signature` (base64 or null) | `TestClientSignature` | bytea — null if absent |
| `client_name` | `TestClientNameSignature` | varchar 50 |

**Column mapping — TestOutput INSERT (per item):**

| JSON | DB column |
|---|---|
| `TestCertificateID` (RETURNING) | `TestOutputCertID` |
| `asset_id` (from cert body) | `TestOutputAssetID` |
| `description_id` | `TestDescriptionID` |
| `description` | `TestDescription` |
| `expected_value` | `TestValue` |
| `actual_value` | `TestActualValue` |
| `pass` | `TestPass` |
| `fail` | `TestFail` |
| `na` | `TestNA` |

**Response:** `201 Created` with `{ "id": <TestCertificateID> }`

---

## Flutter Changes

### cert_remote_data_source.dart

Replace the three stub implementations with real Dio calls:

- `fetchTemplates(int type)` → `GET /certificates/templates?type={type}` → parse `data` array into `TestTemplateNameModel.fromJson`
- `fetchTemplateItems(int templateId)` → `GET /certificates/templates/{templateId}/items` → parse into `TestTemplateItemModel.fromJson`
- `pushCertificate(Map payload)` → `POST /certificates` → return `response.data['id'] as int`

Add `fromJson` factories to `TestTemplateNameModel` and `TestTemplateItemModel` (field names match the JSON keys above).

### sync_notifier.dart

After asset sync completes, add template sync for all 3 types:

```dart
await _repo.syncTemplatesFromRemote(); // calls fetchTemplates(1), (2), (3) + upsertTemplates
```

Log errors to `sync_error_log` the same way asset sync does.

---

## Delphi File Structure

```
C:\Delphi\StatTracTechAPI\
  src\
    Certificates.Routes.pas   ← NEW
  StatTracTechAPI.dpr         ← add Certificates.Routes + RegisterCertificateRoutes
```

Pattern matches `WorkOrders.Routes.pas` exactly:
- `JWT_SECRET` constant (same value)
- `ExtractDbName` helper (same pattern)
- `THorse.AddCallback(HorseJWT(...)).Get/Post(...)` pattern
- `WriteSyncLog` on success

## Error Handling

| Condition | Response |
|---|---|
| Missing db JWT claim | 401 Unauthorized |
| Invalid/missing body | 400 Bad Request |
| Template ID not found | 404 Not Found |
| DB error | 500 (exception propagates to Horse error handler) |
