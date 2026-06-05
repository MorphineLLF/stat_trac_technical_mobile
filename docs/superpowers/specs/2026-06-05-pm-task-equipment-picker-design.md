# PM Task Selection & Test Equipment Picker Improvements

**Date:** 2026-06-05
**Status:** Approved

## Overview

Two related improvements to the certificate creation wizard:

1. **Test equipment picker** — add equipment type to display, rename "Cal:" → "Next Cal:", highlight expired cal dates in red and block selection of expired equipment.
2. **PM task selector** — when creating a certificate, allow the technician to select which PM task (from `AssetPmTask`) the certificate relates to. Requires syncing `AssetPmTask` from a new Horse API endpoint.

---

## Section 1: Data Layer

### Migration 011 (single migration, three changes)

**New table: `asset_pm_tasks`**
```sql
CREATE TABLE asset_pm_tasks (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  pm_task_id      INTEGER NOT NULL UNIQUE,
  asset_id        INTEGER NOT NULL,
  description     TEXT NOT NULL,
  schedule_date   TEXT,
  active          INTEGER NOT NULL DEFAULT 1
);
CREATE INDEX idx_asset_pm_tasks_asset_id ON asset_pm_tasks (asset_id);
```

**Alter `test_certificates`**
```sql
ALTER TABLE test_certificates ADD COLUMN pm_task_description TEXT;
```

**Alter `test_equipment_assets`**
```sql
ALTER TABLE test_equipment_assets ADD COLUMN equipment_type TEXT;
```

**Alter `test_cert_equipment`**
```sql
ALTER TABLE test_cert_equipment ADD COLUMN equipment_type TEXT;
```

### Horse API — `Assets.Routes.pas`

New endpoint: `GET /assets/pm-tasks`

- No since-cursor — full pull every sync.
- Filters `PmTaskActive = 1`.
- Response: `{ data: [{ pm_task_id, asset_id, description, schedule_date, active }] }`

### Horse API — `Certificates.Routes.pas`

- Accept `pm_task_description` (nullable string) in `POST /certificates` body.
- Insert into `"TestCertificate"."TestPmTaskDescription"` (new nullable `varchar` column — add via pgAdmin ALTER, not at runtime per project rule).

### Sync pipeline — `sync_notifier.dart`

New step after asset sync, before template sync:
1. `CertRemoteDataSource.fetchAssetPmTasks()` — `GET /assets/pm-tasks`
2. `CertLocalDataSource.upsertAssetPmTasks(tasks)` — truncate `asset_pm_tasks`, re-insert all rows in a transaction (same full-replace pattern as `upsertTestEquipmentAssets`)
3. Log success/failure to `sync_error_log` and `AppSyncLog` under operation `sync_pm_tasks`

### New data source methods

**`CertLocalDataSource`**
- `upsertAssetPmTasks(List<AssetPmTaskModel> tasks)` — truncate + batch insert
- `getAssetPmTasks(int assetId)` → `Future<List<AssetPmTask>>` — query `asset_pm_tasks` where `asset_id = ? AND active = 1`, ordered by `description ASC`

**`CertRemoteDataSource`**
- `fetchAssetPmTasks()` → `Future<List<AssetPmTaskModel>>` — `GET /assets/pm-tasks`

### New domain entity: `AssetPmTask`

```dart
class AssetPmTask {
  final int pmTaskId;
  final int assetId;
  final String description;
  final DateTime? scheduleDate;
  final bool active;
}
```

---

## Section 2: Test Equipment Picker UI

### `TestEquipmentAsset` entity changes
- Add `equipmentType String?`
- Change `calDate` from `String?` → `DateTime?` (enables expiry comparison without UI-layer parsing)
- Add `isCalExpired` getter: `calDate != null && calDate!.isBefore(DateTime.now())`

### `TestEquipmentAssetModel` changes
- Map `equipment_type` column from `test_equipment_assets`
- Parse `cal_date` ISO string → `DateTime?` on `fromMap`; serialize back in `toMap`

### `TestEquipmentSelection` entity changes
- Add `equipmentType String?`
- Change `calDate` from `String?` → `DateTime?`
- Add `isCalExpired` getter (same logic)
- Update `subtitleText`: format `calDate` as `'dd MMM yyyy'`, label "Next Cal:" instead of "Cal:"
- `displayName` unchanged (manufacturer + model)

### `saveEquipmentSelections` / `getEquipmentForCert`
- Serialize `calDate` as ISO-8601 string in `toMap`
- Parse ISO-8601 string back to `DateTime?` in `getEquipmentForCert`
- Include `equipment_type` in the insert map and read it back on load

### `_TestEquipmentPickerSheet` (in `cert_details_step.dart`)

Each list tile:
- **Title:** `a.equipmentType` (prominent); falls back to `a.displayName` if null
- **Subtitle line 1:** manufacturer + model (if equipment type shown in title)
- **Subtitle line 2:** "Next Cal: dd MMM yyyy" — red text if expired; omitted if null
- **Expired behaviour:** `onTap: null`; tile title and subtitle rendered in red; trailing shows a red "EXPIRED" chip badge instead of chevron
- **Non-expired:** normal tappable tile

### `_EquipmentSlot` filled state
`selection!.subtitleText` already uses the updated `TestEquipmentSelection` entity — "Next Cal:" flows through automatically. No changes needed here.

---

## Section 3: CertDetailsStep — PM Task Selector

### Signature changes

```dart
class CertDetailsStep extends ConsumerStatefulWidget {
  const CertDetailsStep({
    required this.template,
    required this.selectedAsset,       // NEW — Asset? from step 1
    required this.initialDate,
    required this.initialEquipment,
    required this.onChanged,
    required this.onNext,
  });

  // onChanged updated to carry pmTaskDescription
  final void Function(
    DateTime testDate,
    List<TestEquipmentSelection?> equipment,
    String? pmTaskDescription,         // NEW
  ) onChanged;
}
```

### `create_certificate_screen.dart`
- Pass `_selectedAsset` to `CertDetailsStep`
- Add `String? _pmTaskDescription` to screen state
- `onChanged` callback updated to capture `pmTaskDescription`
- `_saveCertificate()` passes `_pmTaskDescription` to `TestCertificate` constructor

### New Riverpod provider

```dart
@riverpod
Future<List<AssetPmTask>> assetPmTasks(Ref ref, int assetId) =>
    ref.watch(certLocalDataSourceProvider).getAssetPmTasks(assetId);
```

### "PM Task" card in `CertDetailsStep`

Positioned below the Test Equipment card, above the Next button.

Visibility rules:
- Hidden if `selectedAsset == null` or `selectedAsset!.assetId == null`
- Hidden if 0 active tasks (provider returns empty list)

Content rules:
- **1 task** — auto-selected in `initState`/`didUpdateWidget`; shown as a locked read-only field (no tap, grey border, lock icon)
- **2+ tasks** — radio-style chip list (one chip per description); Next button blocked until one is selected; validation message "Select a PM task to continue" shown when unselected

### `_CertDetailsStepState`
- Holds `String? _pmTaskDescription`
- Auto-selects single task on provider data load
- Calls `_notify()` (which calls `onChanged`) when `_pmTaskDescription` changes
- `_isValid` updated: also requires `_pmTaskDescription != null` when tasks exist

---

## Section 4: Certificate Storage & Push

### `TestCertificate` entity
- Add `pmTaskDescription String?`

### `TestCertificateModel`
- `toMap()` includes `'pm_task_description': pmTaskDescription`
- `fromMap()` reads `pm_task_description` (nullable, null for existing records)

### Cert push payload (`cert_remote_data_source.dart`)
- Include `pm_task_description` in the JSON body of `POST /certificates`

### `certificate_detail_screen.dart`
- Show `pmTaskDescription` in the cert header card if non-null
- Label: "PM Task", same style as other header fields (labelLarge in brandGrey, value in bodyLarge)

---

## Horse API PostgreSQL

New column to add manually in pgAdmin (not at runtime):
```sql
ALTER TABLE "TestCertificate" ADD COLUMN "TestPmTaskDescription" VARCHAR(100);
```

---

## Files Affected

| File | Change |
|---|---|
| `database/migrations/migration_011_pm_tasks.dart` | NEW — 3 DDL changes |
| `database/database_helper.dart` | Register migration 011, bump DB version to 11 |
| `features/certification/domain/entities/asset_pm_task.dart` | NEW entity |
| `features/certification/domain/entities/test_equipment_asset.dart` | Add equipmentType, DateTime calDate |
| `features/certification/domain/entities/test_equipment_selection.dart` | Add equipmentType, DateTime calDate, isCalExpired, updated subtitleText |
| `features/certification/domain/entities/test_certificate.dart` | Add pmTaskDescription |
| `features/certification/data/models/asset_pm_task_model.dart` | NEW model |
| `features/certification/data/models/test_equipment_asset_model.dart` | Map equipment_type, parse calDate |
| `features/certification/data/models/test_certificate_model.dart` | toMap/fromMap for pm_task_description |
| `features/certification/data/datasources/cert_local_data_source.dart` | upsertAssetPmTasks, getAssetPmTasks; fix calDate serialization in equipment methods |
| `features/certification/data/datasources/cert_remote_data_source.dart` | fetchAssetPmTasks |
| `features/certification/presentation/providers/certificate_providers.dart` + `.g.dart` | assetPmTasksProvider |
| `features/certification/presentation/widgets/cert_details_step.dart` | selectedAsset param, PM task card, updated onChanged, expire UI in picker |
| `features/certification/presentation/screens/create_certificate_screen.dart` | Pass selectedAsset, store pmTaskDescription, updated onChanged |
| `features/certification/presentation/screens/certificate_detail_screen.dart` | Show pmTaskDescription in header |
| `sync/sync_notifier.dart` | sync_pm_tasks step |
| `C:\Delphi\StatTracTechAPI\src\Assets.Routes.pas` | GET /assets/pm-tasks endpoint |
| `C:\Delphi\StatTracTechAPI\src\Certificates.Routes.pas` | Accept pm_task_description in POST /certificates |
| PostgreSQL `"TestCertificate"` | ADD COLUMN "TestPmTaskDescription" VARCHAR(100) — manual pgAdmin |
