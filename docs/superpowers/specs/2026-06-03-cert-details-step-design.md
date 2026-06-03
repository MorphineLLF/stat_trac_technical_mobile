# Certificate Details Step — Design Spec

**Date:** 2026-06-03  
**Status:** Approved  
**Scope:** New wizard step inserted between "Select Template" and "Test Items Grid" in the certificate creation flow.

---

## Overview

After the tech selects a template, a new "Certificate Details" step conditionally appears based on flags stored in `TestTemplateName`. The step handles:

1. **Test date** — editable or locked depending on `TestTemplateEditDate`
2. **Test equipment selection** — N slots based on `TestTemplateTestEquipQty`, each selecting a calibrated instrument from `test_equipment_assets`

The step is skipped entirely if `TestTemplateEditDate = 0` AND `TestTemplateTestEquipQty = 0`.

**Out of scope (deferred):** Next service date (`TestTemplateNextService`). Customer signature notice removed from this step — stays at end of wizard.

---

## Wizard Navigation

```
Before:  Type → Asset → Template → Test Grid → Signature
After:   Type → Asset → Template → Details* → Test Grid → Signature
                                      * skipped when no conditions apply
```

Skip condition: `template.editDate == false && template.testEquipQty == 0`

Back navigation also respects the skip — pressing back from Test Grid jumps to Template if Details was skipped.

---

## Section 1: Data Layer

### New Horse API endpoint — `GET /assets/test-equipment`

Returns slim records only (5 fields):

```json
{ "data": [
  { "asset_id": 55, "manufacturer": "Fluke", "model": "ProSim 8",
    "serial_no": "2041678", "cal_date": "2026-01-01" }
]}
```

Query:
```sql
SELECT "AssetID", "AssetManufacturer", "AssetModel",
       "AssetSerialNo", "PmTaskScheduleDate"
FROM "Asset", "AssetPmTask"
WHERE "AssetID" = "PmAssetID"
  AND "AssetTestEquipment" = 1
ORDER BY "AssetManufacturer"
```

### New local SQLite table — `test_equipment_assets`

| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PK AUTOINCREMENT | |
| `asset_id` | INTEGER UNIQUE | |
| `manufacturer` | TEXT | |
| `model` | TEXT | |
| `serial_no` | TEXT | |
| `cal_date` | TEXT | ISO-8601 from `PmTaskScheduleDate` |
| `synced_at` | TEXT | ISO-8601 UTC |

Full replace on every sync. No deletion detection needed.

### New local SQLite table — `test_cert_equipment`

| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PK AUTOINCREMENT | |
| `certificate_id` | INTEGER | FK → `test_certificates.id` |
| `slot_no` | INTEGER | 1-based |
| `asset_id` | INTEGER | |
| `manufacturer` | TEXT | |
| `model` | TEXT | |
| `serial_no` | TEXT | |
| `cal_date` | TEXT | ISO-8601 |

Rows kept after sync for local reference.

### Migration v11

- Creates `test_equipment_assets`
- Creates `test_cert_equipment`
- Adds 3 columns to `test_template_names`:
  - `test_template_edit_date INTEGER`
  - `test_template_next_service INTEGER` (stored now, used when next service is implemented)
  - `test_template_test_equip_qty INTEGER`

### `GET /certificates/templates` response — 3 new fields

```json
{ "id": 12, "type": 1, "name": "...", "cert_name": "...",
  "edit_date": 1, "next_service": 0, "test_equip_qty": 2,
  "customer_sig_required": true, "doc_no": "..." }
```

### New sync step in `SyncNotifier.triggerSync()`

Added after template sync (step 5), before push certificates (step 6):

- `GET /assets/test-equipment` → upsert all into `test_equipment_assets`
- POST `/sync/log` on success or failure
- Progress: 68%

---

## Section 2: Wizard Step

### New widget — `CertDetailsStep`

File: `lib/features/certification/presentation/widgets/cert_details_step.dart`

Inputs:
- `template` — `TestTemplateName` (drives which sections appear)
- `initialDate` — `DateTime` (defaults to `DateTime.now()`)
- `onChanged` — `void Function(DateTime testDate, List<TestEquipmentSelection> equipment)`

#### Test Date section

Always shown on this step.
- `TestTemplateEditDate = 1` → teal-bordered date field, tappable → `showDatePicker`
- `TestTemplateEditDate = 0` → greyed-out locked field labelled "Auto — today"

#### Test Equipment section

Shown only when `testEquipQty > 0`. Renders `testEquipQty` numbered slots.

Each slot:
- Empty state: dashed border, "Select test equipment…", "Pick" button
- Filled state: solid teal border, manufacturer · model · S/N · cal date, "Change" button
- Tapping opens `TestEquipmentPickerDialog` — reads from local `test_equipment_assets`, sorted by manufacturer. Already-selected `asset_id` values are excluded from other slots.

"Next" button enables when all `testEquipQty` slots are filled.

### `TestEquipmentSelection` data class

```dart
class TestEquipmentSelection {
  final int assetId;
  final String manufacturer;
  final String model;
  final String serialNo;
  final String? calDate;
}
```

### Changes to `create_certificate_screen.dart`

New state fields:
```dart
DateTime _testDate = DateTime.now();
List<TestEquipmentSelection?> _equipment = [];  // sized on template selection
```

On template selected: resize `_equipment` to `template.testEquipQty` filled with nulls.

Step indices shift:
- 0: Type selector (unchanged)
- 1: Asset picker (unchanged)
- 2: Template picker (unchanged)
- 3: **Certificate Details** (new — skipped if conditions not met)
- 4: Test items grid (was 3)
- 5: Signature (was 4)

Navigation helper:
```dart
int get _nextStepAfterTemplate =>
    _shouldShowDetailsStep ? 3 : 4;

int get _prevStepBeforeTestGrid =>
    _shouldShowDetailsStep ? 3 : 2;
```

---

## Section 3: Save & Push

### `issueCertificate()` — new parameter

```dart
Future<int> issueCertificate({
  required TestCertificate cert,
  required List<TestOutput> outputs,
  List<TestEquipmentSelection> equipment = const [],
})
```

After saving cert and outputs, writes `equipment` to `test_cert_equipment` with `certificate_id = certId`.

### Push payload — `_pushSingleCertificate()` extended

Fetches `test_cert_equipment` rows for the cert and appends:

```json
"test_equipment": [
  { "asset_id": 55, "serial_no": "2041678", "model": "ProSim 8",
    "manufacturer": "Fluke", "cal_date": "2026-01-01" },
  { "asset_id": 56, "serial_no": "9900123", "model": "ES601+",
    "manufacturer": "Rigel", "cal_date": "2025-11-15" }
]
```

Empty array if no equipment selected (templates with qty=0).

### Horse API — `POST /certificates` extended

After inserting `TestCertificate` and obtaining `LNewCertId`, loops over `test_equipment` array:

```sql
INSERT INTO "TestAnalyser"
  ("AnalyserAssetID", "AnalyserTestID", "AnalyserCalDate",
   "AnalyserSerialNo", "AnalyserModel", "AnalyserManufacturer")
VALUES
  (:asset_id, :cert_id, :cal_date, :serial_no, :model, :manufacturer)
```

All within the same connection. If an analyser insert fails, API returns 500 and Flutter retries on next sync (cert remains `pending`).

---

## Files Changed

| File | Change |
|---|---|
| `C:\Delphi\StatTracTechAPI\src\Certificates.Routes.pas` | Add `test_equip_qty`, `edit_date`, `next_service` to templates response; loop TestAnalyser inserts in POST |
| `C:\Delphi\StatTracTechAPI\src\Assets.Routes.pas` | New `GET /assets/test-equipment` route |
| `lib/database/migrations/migration_011_cert_details.dart` | New tables + new columns on test_template_names |
| `lib/database/database_helper.dart` | Register migration, bump version to 11 |
| `lib/features/certification/domain/entities/test_template_name.dart` | Add `editDate`, `nextService`, `testEquipQty` |
| `lib/features/certification/data/models/test_template_name_model.dart` | Map new fields |
| `lib/features/certification/domain/entities/test_equipment_selection.dart` | New data class |
| `lib/features/certification/data/datasources/cert_local_data_source.dart` | CRUD for test_equipment_assets + test_cert_equipment |
| `lib/features/certification/data/datasources/cert_remote_data_source.dart` | `fetchTestEquipmentAssets()` |
| `lib/features/certification/data/repositories/certificate_repository_impl.dart` | Extend issueCertificate, pushSingleCertificate |
| `lib/features/certification/presentation/widgets/cert_details_step.dart` | New widget |
| `lib/features/certification/presentation/screens/create_certificate_screen.dart` | New step + state |
| `lib/sync/sync_notifier.dart` | New sync step for test equipment assets |
