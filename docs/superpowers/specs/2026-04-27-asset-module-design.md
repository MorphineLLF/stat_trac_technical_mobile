# Asset Module Design — Phase 1

**Date:** 2026-04-27
**Scope:** Sync + Browse/Search + Detail View
**Phase 2 (deferred):** Update fields, Create WO from asset

---

## Context

The Stat Trac Technical app is an offline-first Flutter app for field service technicians. Assets = medical equipment managed in the production `Stat_Trac` PostgreSQL database (`Asset` table, 10k–50k records). Technicians need to browse, search, and scan assets locally while offline, and view full details when connected.

The existing codebase already has a partial asset module:
- `Asset` entity, `AssetModel`, `AssetLocalDataSource` (search, getById, createProvisional)
- `AssetPickerDialog` (fully built — unchanged in Phase 1)
- SQLite `assets` table (migration 002 — schema replaced in migration 003)

---

## Production DB → Flutter Field Mapping

| Flutter (local slim) | Production (`Asset` table) |
|---|---|
| `asset_id` | `AssetID` (PK, auto-increment — this IS the asset number) |
| `equipment_type` | `AssetEquipmentType` |
| `model` | `AssetModel` |
| `manufacturer` | `AssetManufacturer` |
| `serial_number` | `AssetSerialNo` |
| `barcode` | `AssetBarcode` |
| `hospital` | `AssetHospital` |
| `location` | `AssetLocation` |
| `condition` | `AssetCondition` |
| `is_active` | `AssetActive = 1` |
| `is_condemned` | `AssetCondemned` |
| `next_service_date` | `AssetNextServiceDate` |

**Full detail** (fetched live from API, never stored locally): warranty dates, service plan, risk level, notes, hours, software version, loan status, purchase info, commission info, etc.

**Admin.UserActive:** 1 = active (can login), 2 = not active (cannot login).

---

## Architecture

Follows the same Clean Architecture pattern as Work Orders.

### Domain Layer

**`Asset`** (slim entity — local use)
```dart
class Asset {
  final int id;           // local SQLite PK
  final int? assetId;     // AssetID from production (null for provisionals)
  final String equipmentType;
  final String? model;
  final String? manufacturer;
  final String? serialNumber;
  final String? barcode;
  final String? hospital;
  final String? location;
  final String? condition;
  final bool isActive;
  final bool isCondemned;
  final DateTime? nextServiceDate;
  final bool isProvisional;
  final DateTime? syncedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

**`AssetDetail`** (full entity — remote, never stored locally)

Key fields (all nullable except `assetId`):
```dart
class AssetDetail {
  final int assetId;
  final String? equipmentType;
  final String? model;
  final String? manufacturer;
  final String? serialNumber;
  final String? barcode;
  final String? hospital;
  final String? hospitalGroup;
  final String? location;
  final String? condition;
  final String? notes;
  final String? softwareVersion;
  final String? accessories;
  final bool isActive;
  final bool isCondemned;
  final bool isLoan;
  final bool isDemo;
  final int? risk;               // 1=High, 2=Medium, 3=Low
  final int? assetType;          // 0=Non-warranty, 1=Warranty
  final int? moduletype;         // 1=Main, 2=Module
  final int? hours;
  final DateTime? nextServiceDate;
  final DateTime? lastServiceDate;
  final DateTime? warrantyDateStart;
  final DateTime? warrantyEndDate;
  final int? warrantyPeriod;
  final bool hasServicePlan;
  final DateTime? servicePlanStartDate;
  final DateTime? servicePlanExpDate;
  final double? servicePlanValue;
  final DateTime? manufactureDate;
  final DateTime? deliverDate;
  final DateTime? commissionDate;
}

**`AssetRepository`** interface:
```dart
abstract interface class AssetRepository {
  Future<void> syncAssets();
  Future<List<Asset>> getAssets({String? hospital});
  Future<List<Asset>> searchAssets(String query, {String? hospital});
  Future<Asset?> getAssetById(int id);
  Future<AssetDetail> getAssetDetail(int assetId);
  Future<Asset> createProvisional({
    required String equipmentType,
    String? model,
    String? manufacturer,
    String? serialNumber,
    String? hospital,
    String? location,
  });
}
```

### Data Layer

**`AssetLocalDataSource`** (updated):
- `upsertAll(List<AssetModel>)` — batch upsert by `asset_id` for sync
- `getAssets({String? hospital})` — browse, filtered by hospital
- `searchAssets(query, {hospital})` — search name/serial/barcode
- `getAssetById(int id)` — single record
- `createProvisional({...})` — unchanged

**`AssetRemoteDataSource`** (new):
- `getAssets({int page, int pageSize = 500})` → `GET /assets?page=N&page_size=500`
- `getAssetDetail(int assetId)` → `GET /assets/{id}`

**`AssetRepositoryImpl`** (new): wires local + remote, implements sync loop.

**`AssetDetailModel`** (new): `fromJson` factory for the full Horse API response.

### SQLite Migration 003

Drops and recreates the `assets` table. DB version bumps **3 → 4**.

```sql
CREATE TABLE assets (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  asset_id          INTEGER UNIQUE,           -- NULL for provisionals
  equipment_type    TEXT    NOT NULL,
  model             TEXT,
  manufacturer      TEXT,
  serial_number     TEXT,
  barcode           TEXT,
  hospital          TEXT,
  location          TEXT,
  condition         TEXT,
  is_active         INTEGER NOT NULL DEFAULT 1,
  is_condemned      INTEGER NOT NULL DEFAULT 0,
  next_service_date TEXT,
  is_provisional    INTEGER NOT NULL DEFAULT 0,
  synced_at         TEXT,
  created_at        TEXT    NOT NULL,
  updated_at        TEXT    NOT NULL
);
CREATE INDEX assets_barcode_idx ON assets (barcode);
CREATE INDEX assets_hospital_idx ON assets (hospital);
```

Existing provisional assets (no `asset_id`) are preserved across migrations.

### Presentation Layer

**`asset_providers.dart`** (new, Riverpod codegen):
- `assetRepositoryProvider` — wires `AssetRepositoryImpl`
- `assetsProvider(hospital?)` — `FutureProvider` for browse list
- `assetSearchProvider(query, hospital?)` — `FutureProvider.family`
- `assetDetailProvider(assetId)` — `FutureProvider.family`
- `hospitalListProvider` — distinct hospitals from local DB

---

## Screens

### Asset List Screen (`asset_list_screen.dart`)

```
AppBar: "Assets"  [🔍 search]  [📷 scan]
───────────────────────────────────────────
Hospital filter chips (scrollable)
  All  |  St. Mary's  |  Netcare  |  ...
───────────────────────────────────────────
ListView of AssetTile widgets
  equipment_type + model
  manufacturer · S/N
  hospital — location
  ⚠️ SERVICE DUE badge (next_service_date past or ≤ 30 days)
  CONDEMNED badge (muted style, not hidden)
  PROVISIONAL badge (amber, existing style)
```

### Asset Detail Screen (`asset_detail_screen.dart`)

```
AppBar: "Asset {asset_id}"
───────────────────────────────────────────
Header card (from local slim record — instant):
  equipment_type + model
  manufacturer · S/N · barcode
  hospital — location

Tabs: Overview | Service | Warranty
  (content from GET /assets/{id} — skeleton loader while fetching)

[Overview]   condition, risk, active/condemned flags, notes
[Service]    last/next service date, service plan, hours
[Warranty]   type, start/end dates, status

FAB: ➕ New Work Order  (Phase 2 — hidden for now)
```

Offline state: header shows from local record; tabs show "Connect to view full details".

### Barcode Scanner

`mobile_scanner` package. Launched from AppBar 📷 button on Asset List Screen.

**On scan:**
1. Look up `barcode` in local SQLite
2. Found → navigate to `AssetDetailScreen`
3. Not found → "Asset not found — register provisional?" prompt (opens existing `AssetPickerDialog` provisional form)

---

## Sync Flow

```
syncAssets()
  page = 1
  loop:
    GET /assets?page={page}&page_size=500
    upsertAll(batch) — INSERT OR REPLACE on asset_id
    if batch.length < 500: break
    page++
  save sync timestamp → SharedPreferences key: 'assets_last_synced'
```

- Provisionals (`is_provisional = 1`, `asset_id = NULL`) are never matched by upsert — safe.
- Sync is triggered via `SyncNotifier.triggerSync()` on the Dashboard.
- `syncAssets()` is added to the sync sequence in `SyncService`.

---

## Navigation

Assets is added as a new item to the Dashboard's existing bottom navigation bar (alongside the current Work Orders entry).

```
Dashboard
  └── [Assets] bottom nav tab → AssetListScreen
        ├── tap asset tile → AssetDetailScreen
        └── [📷] scan → barcode scanner → AssetDetailScreen (or provisional prompt)

CreateWorkOrderScreen (existing, unchanged in Phase 1)
  └── asset picker → AssetPickerDialog (unchanged)
```

---

## New Files Summary

| File | Status |
|---|---|
| `domain/entities/asset.dart` | Update (rename + new fields) |
| `domain/entities/asset_detail.dart` | New |
| `domain/repositories/asset_repository.dart` | New |
| `data/datasources/asset_local_data_source.dart` | Update |
| `data/datasources/asset_remote_data_source.dart` | New |
| `data/models/asset_model.dart` | Update |
| `data/models/asset_detail_model.dart` | New |
| `data/repositories/asset_repository_impl.dart` | New |
| `database/migrations/migration_003_assets_v2.dart` | New |
| `database/database_helper.dart` | Update (version 3→4, add migration 003) |
| `presentation/providers/asset_providers.dart` | New |
| `presentation/providers/asset_providers.g.dart` | Generated |
| `presentation/screens/asset_list_screen.dart` | New |
| `presentation/screens/asset_detail_screen.dart` | New |
| `presentation/widgets/asset_picker_dialog.dart` | Minor update (use new Asset fields) |

---

## Phase 2 (deferred)

- Update asset fields (condition, notes, location) → sync back via Horse API
- Create Work Order pre-filled from Asset Detail screen FAB
- Horse API `PATCH /assets/{id}` endpoint

---

## Horse API Endpoints Required (Phase 1)

| Method | Path | Description |
|---|---|---|
| `GET` | `/assets?page=N&page_size=500` | Paginated slim asset list for sync |
| `GET` | `/assets/{id}` | Full asset record by AssetID |
