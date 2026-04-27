# Asset Module Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the full Asset module Phase 1: DB migration, paginated sync, browse/search, barcode scanner, and asset detail view.

**Architecture:** Clean Architecture matching Work Orders — domain entities (`Asset`, `AssetDetail`), data layer (local SQLite + remote Horse API), Riverpod providers (codegen), and three new screens. Assets sync via paginated GET. Full detail is fetched on-demand.

**Tech Stack:** Flutter, Riverpod (codegen), sqflite, Dio, `mobile_scanner` (barcode), `shared_preferences` (sync timestamp), `mocktail` (unit tests).

---

## File Map

| Status | Path |
|---|---|
| **New** | `lib/database/migrations/migration_003_assets_v2.dart` |
| **Update** | `lib/database/database_helper.dart` |
| **Update** | `lib/features/assets/domain/entities/asset.dart` |
| **Update** | `lib/features/assets/data/models/asset_model.dart` |
| **New** | `lib/features/assets/domain/entities/asset_detail.dart` |
| **New** | `lib/features/assets/data/models/asset_detail_model.dart` |
| **Update** | `lib/features/assets/data/datasources/asset_local_data_source.dart` |
| **New** | `lib/features/assets/domain/repositories/asset_repository.dart` |
| **New** | `lib/features/assets/data/datasources/asset_remote_data_source.dart` |
| **New** | `lib/features/assets/data/repositories/asset_repository_impl.dart` |
| **New** | `lib/features/assets/presentation/providers/asset_providers.dart` |
| **Generated** | `lib/features/assets/presentation/providers/asset_providers.g.dart` |
| **Update** | `lib/features/assets/presentation/widgets/asset_picker_dialog.dart` |
| **New** | `lib/features/assets/presentation/screens/asset_list_screen.dart` |
| **New** | `lib/features/assets/presentation/screens/asset_barcode_scanner_screen.dart` |
| **New** | `lib/features/assets/presentation/screens/asset_detail_screen.dart` |
| **Update** | `lib/features/dashboard/presentation/screens/dashboard_screen.dart` |
| **Update** | `lib/sync/sync_notifier.dart` |
| **Update** | `pubspec.yaml` |
| **New** | `test/features/assets/data/models/asset_model_test.dart` |
| **New** | `test/features/assets/data/models/asset_detail_model_test.dart` |
| **New** | `test/features/assets/data/repositories/asset_repository_impl_test.dart` |

---

## Task 1: Add Dependencies

**Files:**
- Update: `pubspec.yaml`

- [ ] **Step 1: Add runtime and dev dependencies**

In `pubspec.yaml`, under `dependencies:` (after `path: ^1.9.1`), add:
```yaml
  # Barcode scanning
  mobile_scanner: ^6.0.2

  # Sync timestamp persistence
  shared_preferences: ^2.3.2
```

Under `dev_dependencies:` (after `build_runner`), add:
```yaml
  # Unit test mocking
  mocktail: ^1.0.4
```

- [ ] **Step 2: Fetch packages**

```bash
flutter pub get
```

Expected: resolves without errors. `mobile_scanner`, `shared_preferences`, `mocktail` appear in `.dart_tool/package_config.json`.

- [ ] **Step 3: Verify mobile_scanner Android setup**

Open `android/app/src/main/AndroidManifest.xml`. Add camera permission inside `<manifest>` if not present:
```xml
<uses-permission android:name="android.permission.CAMERA" />
```

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml
git commit -m "deps: add mobile_scanner, shared_preferences, mocktail"
```

---

## Task 2: SQLite Migration 003 + DatabaseHelper v4

The current schema (migration 002) has wrong field names. Migration 003 drops and recreates the `assets` table with the production-aligned schema. DB version bumps 3 → 4.

**Files:**
- Create: `lib/database/migrations/migration_003_assets_v2.dart`
- Update: `lib/database/database_helper.dart`

- [ ] **Step 1: Write migration file**

Create `lib/database/migrations/migration_003_assets_v2.dart`:
```dart
import 'package:sqflite/sqflite.dart';

Future<void> migration003AssetsV2(Database db) async {
  // Rescue provisional records before dropping the old schema.
  // Old columns: name (→ equipment_type), department (→ location).
  // Provisionals have is_provisional=1 and no asset_id.
  await db.execute('''
    CREATE TABLE IF NOT EXISTS assets_prov_rescue (
      equipment_type TEXT NOT NULL,
      model          TEXT,
      manufacturer   TEXT,
      serial_number  TEXT,
      hospital       TEXT,
      location       TEXT,
      created_at     TEXT NOT NULL,
      updated_at     TEXT NOT NULL
    )
  ''');

  await db.rawInsert('''
    INSERT INTO assets_prov_rescue
      (equipment_type, model, manufacturer, serial_number,
       hospital, location, created_at, updated_at)
    SELECT
      COALESCE(name, 'Unknown'),
      model, manufacturer, serial_number,
      account_name,
      department,
      created_at, updated_at
    FROM assets
    WHERE is_provisional = 1
  ''');

  await db.execute('DROP TABLE IF EXISTS assets');

  await db.execute('''
    CREATE TABLE assets (
      id                INTEGER PRIMARY KEY AUTOINCREMENT,
      asset_id          INTEGER UNIQUE,
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
    )
  ''');

  await db.execute(
      'CREATE INDEX assets_barcode_idx ON assets (barcode)');
  await db.execute(
      'CREATE INDEX assets_hospital_idx ON assets (hospital)');

  // Restore rescued provisionals into the new table.
  await db.rawInsert('''
    INSERT INTO assets
      (equipment_type, model, manufacturer, serial_number,
       hospital, location, is_active, is_condemned, is_provisional,
       created_at, updated_at)
    SELECT
      equipment_type, model, manufacturer, serial_number,
      hospital, location, 1, 0, 1,
      created_at, updated_at
    FROM assets_prov_rescue
  ''');

  await db.execute('DROP TABLE assets_prov_rescue');
}
```

- [ ] **Step 2: Update DatabaseHelper**

Replace the entire content of `lib/database/database_helper.dart`:
```dart
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'migrations/migration_001_work_orders.dart';
import 'migrations/migration_002_assets.dart';
import 'migrations/migration_003_assets_v2.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'stat_trac_technical.db';
  static const _dbVersion = 4;

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = p.join(await getDatabasesPath(), _dbName);
    return openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await migration001WorkOrders(db);
    await migration003AssetsV2(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await migration001WorkOrders(db);
    if (oldVersion < 4) await migration003AssetsV2(db);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
```

Note: `_onCreate` skips `migration002Assets` (obsolete) and goes straight to `migration003AssetsV2`. Existing installs upgrading from v3 hit the `oldVersion < 4` branch which drops and recreates assets.

- [ ] **Step 3: Run flutter analyze**

```bash
flutter analyze lib/database/
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add lib/database/
git commit -m "feat(db): migration 003 - replace assets table with production-aligned schema (v4)"
```

---

## Task 3: Update Asset Entity + AssetModel

The old `Asset` entity has `serverId`, `assetNumber`, `name`, `accountId`, `accountName`, `department`, `category`. Replace with production-aligned fields. Update `AssetModel` to match. Fix all callers of changed fields (`asset_picker_dialog.dart`, `work_order_detail_screen.dart` uses `displayName` only — that stays).

**Files:**
- Update: `lib/features/assets/domain/entities/asset.dart`
- Update: `lib/features/assets/data/models/asset_model.dart`
- Update: `lib/features/assets/presentation/widgets/asset_picker_dialog.dart` (field name fixes only — full rewrite comes in Task 5)

- [ ] **Step 1: Write entity test first**

Create `test/features/assets/data/models/asset_model_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/features/assets/data/models/asset_model.dart';

void main() {
  group('AssetModel.fromMap', () {
    test('maps all SQLite columns', () {
      final m = {
        'id': 1,
        'asset_id': 42,
        'equipment_type': 'Defibrillator',
        'model': 'AED Plus',
        'manufacturer': 'ZOLL',
        'serial_number': 'SN001',
        'barcode': 'BC001',
        'hospital': 'St. Mary',
        'location': 'ICU',
        'condition': 'Good',
        'is_active': 1,
        'is_condemned': 0,
        'next_service_date': '2026-06-01T00:00:00.000',
        'is_provisional': 0,
        'synced_at': '2026-04-27T10:00:00.000',
        'created_at': '2026-04-27T08:00:00.000',
        'updated_at': '2026-04-27T08:00:00.000',
      };

      final asset = AssetModel.fromMap(m);

      expect(asset.id, 1);
      expect(asset.assetId, 42);
      expect(asset.equipmentType, 'Defibrillator');
      expect(asset.model, 'AED Plus');
      expect(asset.isActive, isTrue);
      expect(asset.isCondemned, isFalse);
      expect(asset.isProvisional, isFalse);
      expect(asset.nextServiceDate, isNotNull);
    });

    test('handles null optionals', () {
      final m = {
        'id': 2,
        'asset_id': null,
        'equipment_type': 'Unknown',
        'model': null,
        'manufacturer': null,
        'serial_number': null,
        'barcode': null,
        'hospital': null,
        'location': null,
        'condition': null,
        'is_active': 1,
        'is_condemned': 0,
        'next_service_date': null,
        'is_provisional': 1,
        'synced_at': null,
        'created_at': '2026-01-01T00:00:00.000',
        'updated_at': '2026-01-01T00:00:00.000',
      };

      final asset = AssetModel.fromMap(m);

      expect(asset.assetId, isNull);
      expect(asset.isProvisional, isTrue);
      expect(asset.syncedAt, isNull);
    });

    test('toMap round-trips through fromMap', () {
      final m = {
        'id': 3,
        'asset_id': 99,
        'equipment_type': 'Ventilator',
        'model': null,
        'manufacturer': 'Philips',
        'serial_number': null,
        'barcode': 'BAR99',
        'hospital': 'Netcare',
        'location': 'ICU',
        'condition': null,
        'is_active': 1,
        'is_condemned': 0,
        'next_service_date': null,
        'is_provisional': 0,
        'synced_at': null,
        'created_at': '2026-01-01T00:00:00.000',
        'updated_at': '2026-01-01T00:00:00.000',
      };

      final asset = AssetModel.fromMap(m);
      final roundTripped = AssetModel.fromMap(asset.toMap()..['id'] = 3);

      expect(roundTripped.assetId, asset.assetId);
      expect(roundTripped.equipmentType, asset.equipmentType);
      expect(roundTripped.hospital, asset.hospital);
    });
  });

  group('AssetModel.fromJson', () {
    test('maps API response fields', () {
      final j = {
        'asset_id': 55,
        'equipment_type': 'Monitor',
        'model': 'X200',
        'manufacturer': 'GE',
        'serial_number': 'SN55',
        'barcode': 'BC55',
        'hospital': 'Mediclinic',
        'location': 'Ward 3',
        'condition': 'Fair',
        'is_active': true,
        'is_condemned': false,
        'next_service_date': '2026-09-01',
      };

      final asset = AssetModel.fromJson(j);

      expect(asset.assetId, 55);
      expect(asset.equipmentType, 'Monitor');
      expect(asset.isActive, isTrue);
      expect(asset.isProvisional, isFalse);
      expect(asset.syncedAt, isNotNull);
    });
  });
}
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
flutter test test/features/assets/data/models/asset_model_test.dart
```

Expected: FAIL — `AssetModel` doesn't have `assetId`, `equipmentType`, etc. yet.

- [ ] **Step 3: Replace Asset entity**

Replace the entire content of `lib/features/assets/domain/entities/asset.dart`:
```dart
import 'package:flutter/foundation.dart';

@immutable
class Asset {
  const Asset({
    required this.id,
    required this.equipmentType,
    required this.isActive,
    required this.isCondemned,
    required this.isProvisional,
    required this.createdAt,
    required this.updatedAt,
    this.assetId,
    this.model,
    this.manufacturer,
    this.serialNumber,
    this.barcode,
    this.hospital,
    this.location,
    this.condition,
    this.nextServiceDate,
    this.syncedAt,
  });

  final int id;
  final int? assetId;
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

  String get displayName =>
      assetId != null ? '${assetId} — $equipmentType' : 'PROV — $equipmentType';

  bool get isServiceDue {
    if (nextServiceDate == null) return false;
    return nextServiceDate!
        .isBefore(DateTime.now().add(const Duration(days: 30)));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Asset && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
```

- [ ] **Step 4: Replace AssetModel**

Replace the entire content of `lib/features/assets/data/models/asset_model.dart`:
```dart
import '../../domain/entities/asset.dart';

class AssetModel extends Asset {
  const AssetModel({
    required super.id,
    required super.equipmentType,
    required super.isActive,
    required super.isCondemned,
    required super.isProvisional,
    required super.createdAt,
    required super.updatedAt,
    super.assetId,
    super.model,
    super.manufacturer,
    super.serialNumber,
    super.barcode,
    super.hospital,
    super.location,
    super.condition,
    super.nextServiceDate,
    super.syncedAt,
  });

  /// From SQLite row.
  factory AssetModel.fromMap(Map<String, dynamic> m) => AssetModel(
        id: m['id'] as int,
        assetId: m['asset_id'] as int?,
        equipmentType: m['equipment_type'] as String,
        model: m['model'] as String?,
        manufacturer: m['manufacturer'] as String?,
        serialNumber: m['serial_number'] as String?,
        barcode: m['barcode'] as String?,
        hospital: m['hospital'] as String?,
        location: m['location'] as String?,
        condition: m['condition'] as String?,
        isActive: (m['is_active'] as int? ?? 1) == 1,
        isCondemned: (m['is_condemned'] as int? ?? 0) == 1,
        nextServiceDate: m['next_service_date'] != null
            ? DateTime.parse(m['next_service_date'] as String)
            : null,
        isProvisional: (m['is_provisional'] as int? ?? 0) == 1,
        syncedAt: m['synced_at'] != null
            ? DateTime.parse(m['synced_at'] as String)
            : null,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );

  /// From Horse API slim list response (GET /assets?page=N).
  factory AssetModel.fromJson(Map<String, dynamic> j) {
    final now = DateTime.now();
    return AssetModel(
      id: 0,
      assetId: j['asset_id'] as int?,
      equipmentType: j['equipment_type'] as String? ?? '',
      model: j['model'] as String?,
      manufacturer: j['manufacturer'] as String?,
      serialNumber: j['serial_number'] as String?,
      barcode: j['barcode'] as String?,
      hospital: j['hospital'] as String?,
      location: j['location'] as String?,
      condition: j['condition'] as String?,
      isActive: j['is_active'] as bool? ?? true,
      isCondemned: j['is_condemned'] as bool? ?? false,
      nextServiceDate: j['next_service_date'] != null
          ? DateTime.tryParse(j['next_service_date'] as String)
          : null,
      isProvisional: false,
      syncedAt: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != 0) 'id': id,
        'asset_id': assetId,
        'equipment_type': equipmentType,
        'model': model,
        'manufacturer': manufacturer,
        'serial_number': serialNumber,
        'barcode': barcode,
        'hospital': hospital,
        'location': location,
        'condition': condition,
        'is_active': isActive ? 1 : 0,
        'is_condemned': isCondemned ? 1 : 0,
        'next_service_date': nextServiceDate?.toIso8601String(),
        'is_provisional': isProvisional ? 1 : 0,
        'synced_at': syncedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
```

- [ ] **Step 5: Fix AssetPickerDialog field references**

The `_AssetTile` widget in `asset_picker_dialog.dart` references `asset.name` and `asset.assetNumber`. Update those two references inside `_AssetTile.build`:

Find in `lib/features/assets/presentation/widgets/asset_picker_dialog.dart`:
```dart
      title: Text(asset.name,
          style: Theme.of(context).textTheme.bodyLarge),
      subtitle: Text(
        [
          asset.assetNumber,
          if (asset.serialNumber != null) 'S/N: ${asset.serialNumber}',
        ].join('  ·  '),
        style: Theme.of(context).textTheme.bodySmall,
      ),
```

Replace with:
```dart
      title: Text(asset.equipmentType,
          style: Theme.of(context).textTheme.bodyLarge),
      subtitle: Text(
        [
          if (asset.assetId != null) '#${asset.assetId}',
          if (asset.serialNumber != null) 'S/N: ${asset.serialNumber}',
        ].join('  ·  '),
        style: Theme.of(context).textTheme.bodySmall,
      ),
```

- [ ] **Step 6: Run tests — expect PASS**

```bash
flutter test test/features/assets/data/models/asset_model_test.dart
```

Expected: all 5 tests PASS.

- [ ] **Step 7: Verify no compile errors**

```bash
flutter analyze lib/features/assets/
```

Expected: no errors.

- [ ] **Step 8: Commit**

```bash
git add lib/features/assets/domain/entities/asset.dart \
        lib/features/assets/data/models/asset_model.dart \
        lib/features/assets/presentation/widgets/asset_picker_dialog.dart \
        test/features/assets/data/models/asset_model_test.dart
git commit -m "feat(assets): replace Asset entity with production-aligned schema"
```

---

## Task 4: AssetDetail Entity + AssetDetailModel

Full asset record fetched live from `GET /assets/{id}`. Never stored in SQLite.

**Files:**
- Create: `lib/features/assets/domain/entities/asset_detail.dart`
- Create: `lib/features/assets/data/models/asset_detail_model.dart`
- Create: `test/features/assets/data/models/asset_detail_model_test.dart`

- [ ] **Step 1: Write test first**

Create `test/features/assets/data/models/asset_detail_model_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/features/assets/data/models/asset_detail_model.dart';

void main() {
  group('AssetDetailModel.fromJson', () {
    test('maps all fields from full API response', () {
      final j = {
        'asset_id': 42,
        'equipment_type': 'Defibrillator',
        'model': 'AED Plus',
        'manufacturer': 'ZOLL',
        'serial_number': 'SN001',
        'barcode': 'BC001',
        'hospital': 'St. Mary',
        'hospital_group': 'Netcare Group',
        'location': 'ICU',
        'condition': 'Good',
        'notes': 'Annual service done',
        'software_version': '2.1.0',
        'accessories': 'Pads x2',
        'is_active': true,
        'is_condemned': false,
        'is_loan': false,
        'is_demo': false,
        'risk': 1,
        'asset_type': 1,
        'moduletype': 1,
        'hours': 1200,
        'next_service_date': '2026-09-01',
        'last_service_date': '2025-09-01',
        'warranty_date_start': '2023-01-01',
        'warranty_end_date': '2025-01-01',
        'warranty_period': 24,
        'has_service_plan': true,
        'service_plan_start_date': '2025-01-01',
        'service_plan_exp_date': '2027-01-01',
        'service_plan_value': 5000.0,
        'manufacture_date': '2022-06-01',
        'deliver_date': '2022-12-01',
        'commission_date': '2023-01-15',
      };

      final detail = AssetDetailModel.fromJson(j);

      expect(detail.assetId, 42);
      expect(detail.equipmentType, 'Defibrillator');
      expect(detail.risk, 1);
      expect(detail.hasServicePlan, isTrue);
      expect(detail.warrantyPeriod, 24);
      expect(detail.nextServiceDate, isNotNull);
      expect(detail.servicePlanValue, 5000.0);
    });

    test('handles all-null optionals gracefully', () {
      final j = {
        'asset_id': 1,
        'equipment_type': null,
        'model': null,
        'manufacturer': null,
        'serial_number': null,
        'barcode': null,
        'hospital': null,
        'hospital_group': null,
        'location': null,
        'condition': null,
        'notes': null,
        'software_version': null,
        'accessories': null,
        'is_active': false,
        'is_condemned': false,
        'is_loan': false,
        'is_demo': false,
        'risk': null,
        'asset_type': null,
        'moduletype': null,
        'hours': null,
        'next_service_date': null,
        'last_service_date': null,
        'warranty_date_start': null,
        'warranty_end_date': null,
        'warranty_period': null,
        'has_service_plan': false,
        'service_plan_start_date': null,
        'service_plan_exp_date': null,
        'service_plan_value': null,
        'manufacture_date': null,
        'deliver_date': null,
        'commission_date': null,
      };

      final detail = AssetDetailModel.fromJson(j);

      expect(detail.assetId, 1);
      expect(detail.equipmentType, isNull);
      expect(detail.risk, isNull);
      expect(detail.servicePlanValue, isNull);
    });
  });
}
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
flutter test test/features/assets/data/models/asset_detail_model_test.dart
```

Expected: FAIL — files don't exist yet.

- [ ] **Step 3: Create AssetDetail entity**

Create `lib/features/assets/domain/entities/asset_detail.dart`:
```dart
import 'package:flutter/foundation.dart';

@immutable
class AssetDetail {
  const AssetDetail({
    required this.assetId,
    required this.isActive,
    required this.isCondemned,
    required this.isLoan,
    required this.isDemo,
    required this.hasServicePlan,
    this.equipmentType,
    this.model,
    this.manufacturer,
    this.serialNumber,
    this.barcode,
    this.hospital,
    this.hospitalGroup,
    this.location,
    this.condition,
    this.notes,
    this.softwareVersion,
    this.accessories,
    this.risk,
    this.assetType,
    this.moduletype,
    this.hours,
    this.nextServiceDate,
    this.lastServiceDate,
    this.warrantyDateStart,
    this.warrantyEndDate,
    this.warrantyPeriod,
    this.servicePlanStartDate,
    this.servicePlanExpDate,
    this.servicePlanValue,
    this.manufactureDate,
    this.deliverDate,
    this.commissionDate,
  });

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

  /// 1=High, 2=Medium, 3=Low
  final int? risk;

  /// 0=Non-warranty, 1=Warranty
  final int? assetType;

  /// 1=Main, 2=Module
  final int? moduletype;

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

  String get riskLabel => switch (risk) {
        1 => 'High',
        2 => 'Medium',
        3 => 'Low',
        _ => 'Unknown',
      };

  bool get isUnderWarranty {
    if (warrantyEndDate == null) return false;
    return warrantyEndDate!.isAfter(DateTime.now());
  }
}
```

- [ ] **Step 4: Create AssetDetailModel**

Create `lib/features/assets/data/models/asset_detail_model.dart`:
```dart
import '../../domain/entities/asset_detail.dart';

class AssetDetailModel extends AssetDetail {
  const AssetDetailModel({
    required super.assetId,
    required super.isActive,
    required super.isCondemned,
    required super.isLoan,
    required super.isDemo,
    required super.hasServicePlan,
    super.equipmentType,
    super.model,
    super.manufacturer,
    super.serialNumber,
    super.barcode,
    super.hospital,
    super.hospitalGroup,
    super.location,
    super.condition,
    super.notes,
    super.softwareVersion,
    super.accessories,
    super.risk,
    super.assetType,
    super.moduletype,
    super.hours,
    super.nextServiceDate,
    super.lastServiceDate,
    super.warrantyDateStart,
    super.warrantyEndDate,
    super.warrantyPeriod,
    super.servicePlanStartDate,
    super.servicePlanExpDate,
    super.servicePlanValue,
    super.manufactureDate,
    super.deliverDate,
    super.commissionDate,
  });

  factory AssetDetailModel.fromJson(Map<String, dynamic> j) =>
      AssetDetailModel(
        assetId: j['asset_id'] as int,
        equipmentType: j['equipment_type'] as String?,
        model: j['model'] as String?,
        manufacturer: j['manufacturer'] as String?,
        serialNumber: j['serial_number'] as String?,
        barcode: j['barcode'] as String?,
        hospital: j['hospital'] as String?,
        hospitalGroup: j['hospital_group'] as String?,
        location: j['location'] as String?,
        condition: j['condition'] as String?,
        notes: j['notes'] as String?,
        softwareVersion: j['software_version'] as String?,
        accessories: j['accessories'] as String?,
        isActive: j['is_active'] as bool? ?? false,
        isCondemned: j['is_condemned'] as bool? ?? false,
        isLoan: j['is_loan'] as bool? ?? false,
        isDemo: j['is_demo'] as bool? ?? false,
        risk: j['risk'] as int?,
        assetType: j['asset_type'] as int?,
        moduletype: j['moduletype'] as int?,
        hours: j['hours'] as int?,
        nextServiceDate: _parseDate(j['next_service_date']),
        lastServiceDate: _parseDate(j['last_service_date']),
        warrantyDateStart: _parseDate(j['warranty_date_start']),
        warrantyEndDate: _parseDate(j['warranty_end_date']),
        warrantyPeriod: j['warranty_period'] as int?,
        hasServicePlan: j['has_service_plan'] as bool? ?? false,
        servicePlanStartDate: _parseDate(j['service_plan_start_date']),
        servicePlanExpDate: _parseDate(j['service_plan_exp_date']),
        servicePlanValue: (j['service_plan_value'] as num?)?.toDouble(),
        manufactureDate: _parseDate(j['manufacture_date']),
        deliverDate: _parseDate(j['deliver_date']),
        commissionDate: _parseDate(j['commission_date']),
      );

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v as String);
  }
}
```

- [ ] **Step 5: Run tests — expect PASS**

```bash
flutter test test/features/assets/data/models/asset_detail_model_test.dart
```

Expected: all 2 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/assets/domain/entities/asset_detail.dart \
        lib/features/assets/data/models/asset_detail_model.dart \
        test/features/assets/data/models/asset_detail_model_test.dart
git commit -m "feat(assets): add AssetDetail entity and AssetDetailModel"
```

---

## Task 5: Update AssetLocalDataSource + AssetPickerDialog

The old interface has `AccountSummary`, `getAccounts()`, `searchAssets({accountId})`, and `createProvisional({assetNumber, name, ...})`. Replace with the new interface: `upsertAll`, `getAssets`, `searchAssets({hospital})`, `getHospitals`, `createProvisional({equipmentType, ...})`. Then update `AssetPickerDialog` to match the new interface.

**Files:**
- Update: `lib/features/assets/data/datasources/asset_local_data_source.dart`
- Update: `lib/features/assets/presentation/widgets/asset_picker_dialog.dart`

- [ ] **Step 1: Replace AssetLocalDataSource**

Replace the entire content of `lib/features/assets/data/datasources/asset_local_data_source.dart`:
```dart
import '../../../../database/database_helper.dart';
import '../../domain/entities/asset.dart';
import '../models/asset_model.dart';

abstract interface class AssetLocalDataSource {
  /// Batch upsert synced records by asset_id (INSERT OR REPLACE).
  Future<void> upsertAll(List<AssetModel> assets);

  /// Browse all assets, optionally filtered by hospital name.
  Future<List<Asset>> getAssets({String? hospital});

  /// Search by equipment_type, serial_number, or barcode.
  Future<List<Asset>> searchAssets(String query, {String? hospital});

  /// Single record by local SQLite PK.
  Future<Asset?> getAssetById(int id);

  /// Single record by production AssetID (for barcode scan lookup).
  Future<Asset?> getAssetByAssetId(int assetId);

  /// Single record by barcode value (for scanner).
  Future<Asset?> getAssetByBarcode(String barcode);

  /// Distinct hospital names from synced records.
  Future<List<String>> getHospitals();

  /// Create a provisional (offline) asset record.
  Future<Asset> createProvisional({
    required String equipmentType,
    String? model,
    String? manufacturer,
    String? serialNumber,
    String? hospital,
    String? location,
  });
}

class AssetLocalDataSourceImpl implements AssetLocalDataSource {
  AssetLocalDataSourceImpl(this._db);
  final DatabaseHelper _db;

  static const _table = 'assets';

  @override
  Future<void> upsertAll(List<AssetModel> assets) async {
    final db = await _db.database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    for (final a in assets) {
      final map = a.toMap()
        ..remove('id')
        ..['synced_at'] = now
        ..['created_at'] = now
        ..['updated_at'] = now;
      batch.rawInsert('''
        INSERT OR REPLACE INTO $_table
          (asset_id, equipment_type, model, manufacturer, serial_number,
           barcode, hospital, location, condition, is_active, is_condemned,
           next_service_date, is_provisional, synced_at, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?)
      ''', [
        a.assetId,
        a.equipmentType,
        a.model,
        a.manufacturer,
        a.serialNumber,
        a.barcode,
        a.hospital,
        a.location,
        a.condition,
        a.isActive ? 1 : 0,
        a.isCondemned ? 1 : 0,
        a.nextServiceDate?.toIso8601String(),
        now, now, now,
      ]);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<List<Asset>> getAssets({String? hospital}) async {
    final db = await _db.database;
    final rows = await db.query(
      _table,
      where: hospital != null ? 'hospital = ?' : null,
      whereArgs: hospital != null ? [hospital] : null,
      orderBy: 'is_provisional ASC, equipment_type ASC',
    );
    return rows.map((r) => AssetModel.fromMap(r)).toList();
  }

  @override
  Future<List<Asset>> searchAssets(String query, {String? hospital}) async {
    final db = await _db.database;
    final like = '%${query.toLowerCase()}%';

    final where = StringBuffer(
      '(LOWER(equipment_type) LIKE ? OR LOWER(serial_number) LIKE ? OR LOWER(barcode) LIKE ?)',
    );
    final args = <dynamic>[like, like, like];

    if (hospital != null) {
      where.write(' AND hospital = ?');
      args.add(hospital);
    }

    final rows = await db.query(
      _table,
      where: where.toString(),
      whereArgs: args,
      orderBy: 'is_provisional ASC, equipment_type ASC',
      limit: 50,
    );
    return rows.map((r) => AssetModel.fromMap(r)).toList();
  }

  @override
  Future<Asset?> getAssetById(int id) async {
    final db = await _db.database;
    final rows = await db.query(_table, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return AssetModel.fromMap(rows.first);
  }

  @override
  Future<Asset?> getAssetByAssetId(int assetId) async {
    final db = await _db.database;
    final rows =
        await db.query(_table, where: 'asset_id = ?', whereArgs: [assetId]);
    if (rows.isEmpty) return null;
    return AssetModel.fromMap(rows.first);
  }

  @override
  Future<Asset?> getAssetByBarcode(String barcode) async {
    final db = await _db.database;
    final rows =
        await db.query(_table, where: 'barcode = ?', whereArgs: [barcode]);
    if (rows.isEmpty) return null;
    return AssetModel.fromMap(rows.first);
  }

  @override
  Future<List<String>> getHospitals() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT DISTINCT hospital
      FROM $_table
      WHERE hospital IS NOT NULL AND is_provisional = 0
      ORDER BY hospital ASC
    ''');
    return rows.map((r) => r['hospital'] as String).toList();
  }

  @override
  Future<Asset> createProvisional({
    required String equipmentType,
    String? model,
    String? manufacturer,
    String? serialNumber,
    String? hospital,
    String? location,
  }) async {
    final db = await _db.database;
    final now = DateTime.now();
    final draft = AssetModel(
      id: 0,
      equipmentType: equipmentType,
      model: model,
      manufacturer: manufacturer,
      serialNumber: serialNumber,
      hospital: hospital,
      location: location,
      isActive: true,
      isCondemned: false,
      isProvisional: true,
      createdAt: now,
      updatedAt: now,
    );
    final id = await db.insert(_table, draft.toMap());
    return AssetModel.fromMap({...draft.toMap(), 'id': id});
  }
}
```

- [ ] **Step 2: Rewrite AssetPickerDialog**

Replace the entire content of `lib/features/assets/presentation/widgets/asset_picker_dialog.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../sync/sync_notifier.dart';
import '../../../../sync/sync_state.dart';
import '../../data/datasources/asset_local_data_source.dart';
import '../../domain/entities/asset.dart';

// ── Scoped providers ──────────────────────────────────────────────────────────

final _assetDataSourceProvider = Provider<AssetLocalDataSource>(
  (ref) => throw UnimplementedError('Override before use'),
  dependencies: [],
);

final _hospitalsProvider = FutureProvider.autoDispose<List<String>>(
  (ref) => ref.watch(_assetDataSourceProvider).getHospitals(),
  dependencies: [_assetDataSourceProvider],
);

final _selectedHospitalProvider = StateProvider<String?>(
  (ref) => null,
  dependencies: [],
);

final _assetSearchQueryProvider = StateProvider<String>(
  (ref) => '',
  dependencies: [],
);

final _assetSearchResultsProvider =
    FutureProvider.autoDispose.family<List<Asset>, String>(
  (ref, query) async {
    final hospital = ref.watch(_selectedHospitalProvider);
    final ds = ref.watch(_assetDataSourceProvider);
    return ds.searchAssets(query, hospital: hospital);
  },
  dependencies: [_assetDataSourceProvider, _selectedHospitalProvider],
);

// ── Public entry point ────────────────────────────────────────────────────────

Future<Asset?> showAssetPicker(
  BuildContext context,
  AssetLocalDataSource dataSource,
) {
  return showDialog<Asset>(
    context: context,
    builder: (_) => ProviderScope(
      overrides: [
        _assetDataSourceProvider.overrideWithValue(dataSource),
      ],
      child: const _AssetPickerDialog(),
    ),
  );
}

// ── Dialog shell ──────────────────────────────────────────────────────────────

class _AssetPickerDialog extends ConsumerWidget {
  const _AssetPickerDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedHospital = ref.watch(_selectedHospitalProvider);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Column(
          children: [
            _DialogHeader(
              title:
                  selectedHospital == null ? 'Select Hospital' : selectedHospital,
              showBack: selectedHospital != null,
              onBack: () =>
                  ref.read(_selectedHospitalProvider.notifier).state = null,
              onClose: () => Navigator.of(context).pop(),
            ),
            const Divider(height: 1),
            Expanded(
              child: selectedHospital == null
                  ? const _HospitalPage()
                  : const _AssetPage(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dialog header ─────────────────────────────────────────────────────────────

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({
    required this.title,
    required this.showBack,
    required this.onBack,
    required this.onClose,
  });
  final String title;
  final bool showBack;
  final VoidCallback onBack;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
      child: Row(
        children: [
          if (showBack)
            IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack)
          else
            const SizedBox(width: 48),
          Expanded(
            child: Text(title,
                style: Theme.of(context).textTheme.titleMedium),
          ),
          IconButton(icon: const Icon(Icons.close), onPressed: onClose),
        ],
      ),
    );
  }
}

// ── Page 1: Hospital selection ────────────────────────────────────────────────

class _HospitalPage extends ConsumerWidget {
  const _HospitalPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hospitalsAsync = ref.watch(_hospitalsProvider);

    return hospitalsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error: $e', style: Theme.of(context).textTheme.bodySmall),
      ),
      data: (hospitals) => hospitals.isEmpty
          ? _SyncEmptyState(
              message: 'No hospitals available',
              subtitle: 'Sync to download the asset list',
            )
          : ListView.separated(
              itemCount: hospitals.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 16),
              itemBuilder: (_, i) => ListTile(
                leading: const Icon(Icons.local_hospital_outlined,
                    color: brandTeal),
                title: Text(hospitals[i],
                    style: Theme.of(context).textTheme.bodyLarge),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () =>
                    ref.read(_selectedHospitalProvider.notifier).state =
                        hospitals[i],
              ),
            ),
    );
  }
}

// ── Page 2: Asset selection ───────────────────────────────────────────────────

class _AssetPage extends ConsumerStatefulWidget {
  const _AssetPage();

  @override
  ConsumerState<_AssetPage> createState() => _AssetPageState();
}

class _AssetPageState extends ConsumerState<_AssetPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openProvisionalForm() async {
    final hospital = ref.read(_selectedHospitalProvider);
    final ds = ref.read(_assetDataSourceProvider);
    final asset = await showModalBottomSheet<Asset>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProvisionalAssetForm(
        dataSource: ds,
        prefilledHospital: hospital,
      ),
    );
    if (asset != null && mounted) {
      Navigator.of(context).pop(asset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(_assetSearchQueryProvider);
    final resultsAsync = ref.watch(_assetSearchResultsProvider(query));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Search by equipment type, serial or barcode…',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (v) =>
                ref.read(_assetSearchQueryProvider.notifier).state = v.trim(),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: resultsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text('Error: $e',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            data: (assets) => assets.isEmpty
                ? _SyncEmptyState(
                    message: query.isNotEmpty
                        ? 'No assets matched'
                        : 'No assets for this hospital',
                    subtitle: query.isNotEmpty
                        ? 'Try a different search or register a provisional'
                        : 'Sync to download assets, or register a provisional',
                    showProvisional: true,
                    onProvisional: _openProvisionalForm,
                  )
                : ListView.separated(
                    itemCount: assets.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 16),
                    itemBuilder: (_, i) => _AssetTile(
                      asset: assets[i],
                      onTap: () => Navigator.of(context).pop(assets[i]),
                    ),
                  ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: TextButton.icon(
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('Asset not listed — register provisional'),
            onPressed: _openProvisionalForm,
          ),
        ),
      ],
    );
  }
}

// ── Asset tile ────────────────────────────────────────────────────────────────

class _AssetTile extends StatelessWidget {
  const _AssetTile({required this.asset, required this.onTap});
  final Asset asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(
        Icons.medical_services_outlined,
        color: asset.isProvisional ? const Color(0xFFF57F17) : brandTeal,
      ),
      title: Text(asset.equipmentType,
          style: Theme.of(context).textTheme.bodyLarge),
      subtitle: Text(
        [
          if (asset.assetId != null) '#${asset.assetId}',
          if (asset.serialNumber != null) 'S/N: ${asset.serialNumber}',
        ].join('  ·  '),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: asset.isProvisional
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF57F17).withAlpha(30),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFF57F17)),
              ),
              child: const Text(
                'PROVISIONAL',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFF57F17),
                ),
              ),
            )
          : const Icon(Icons.chevron_right, size: 18),
    );
  }
}

// ── Sync / empty state ────────────────────────────────────────────────────────

class _SyncEmptyState extends ConsumerWidget {
  const _SyncEmptyState({
    required this.message,
    required this.subtitle,
    this.showProvisional = false,
    this.onProvisional,
  });
  final String message;
  final String subtitle;
  final bool showProvisional;
  final VoidCallback? onProvisional;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSyncing = ref.watch(syncNotifierProvider) is SyncInProgress;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_download_outlined,
                size: 48, color: brandGrey),
            const SizedBox(height: 12),
            Text(message,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(subtitle,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.sync, size: 18),
              label: Text(isSyncing ? 'Syncing…' : 'Sync Now'),
              onPressed: isSyncing
                  ? null
                  : () =>
                      ref.read(syncNotifierProvider.notifier).triggerSync(),
            ),
            if (showProvisional && onProvisional != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onProvisional,
                child: const Text('Or register a provisional asset'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Provisional asset form ────────────────────────────────────────────────────

class _ProvisionalAssetForm extends StatefulWidget {
  const _ProvisionalAssetForm({
    required this.dataSource,
    this.prefilledHospital,
  });
  final AssetLocalDataSource dataSource;
  final String? prefilledHospital;

  @override
  State<_ProvisionalAssetForm> createState() => _ProvisionalAssetFormState();
}

class _ProvisionalAssetFormState extends State<_ProvisionalAssetForm> {
  final _formKey = GlobalKey<FormState>();
  final _equipmentTypeCtrl = TextEditingController();
  final _serialCtrl = TextEditingController();
  final _manufacturerCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _equipmentTypeCtrl.dispose();
    _serialCtrl.dispose();
    _manufacturerCtrl.dispose();
    _modelCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final asset = await widget.dataSource.createProvisional(
      equipmentType: _equipmentTypeCtrl.text.trim(),
      serialNumber:
          _serialCtrl.text.trim().isEmpty ? null : _serialCtrl.text.trim(),
      manufacturer: _manufacturerCtrl.text.trim().isEmpty
          ? null
          : _manufacturerCtrl.text.trim(),
      model:
          _modelCtrl.text.trim().isEmpty ? null : _modelCtrl.text.trim(),
      hospital: widget.prefilledHospital,
      location: _locationCtrl.text.trim().isEmpty
          ? null
          : _locationCtrl.text.trim(),
    );
    if (mounted) Navigator.of(context).pop(asset);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFF57F17)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Provisional Asset',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              ]),
              const SizedBox(height: 4),
              Text(
                'This record will be flagged for admin registration after sync.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (widget.prefilledHospital != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: brandTeal.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: brandTeal.withAlpha(60)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.local_hospital_outlined,
                        size: 16, color: brandTeal),
                    const SizedBox(width: 8),
                    Text(widget.prefilledHospital!,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: brandTeal)),
                  ]),
                ),
              ],
              const SizedBox(height: 20),
              TextFormField(
                controller: _equipmentTypeCtrl,
                decoration:
                    const InputDecoration(labelText: 'Equipment Type *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _serialCtrl,
                decoration:
                    const InputDecoration(labelText: 'Serial Number'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _manufacturerCtrl,
                decoration:
                    const InputDecoration(labelText: 'Manufacturer'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _modelCtrl,
                decoration: const InputDecoration(labelText: 'Model'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationCtrl,
                decoration:
                    const InputDecoration(labelText: 'Location / Ward'),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Provisional Asset'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Verify compile**

```bash
flutter analyze lib/features/assets/
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add lib/features/assets/data/datasources/asset_local_data_source.dart \
        lib/features/assets/presentation/widgets/asset_picker_dialog.dart
git commit -m "feat(assets): update AssetLocalDataSource interface + rewrite AssetPickerDialog for new schema"
```

---

## Task 6: AssetRepository Interface

**Files:**
- Create: `lib/features/assets/domain/repositories/asset_repository.dart`

- [ ] **Step 1: Create the interface**

Create `lib/features/assets/domain/repositories/asset_repository.dart`:
```dart
import '../entities/asset.dart';
import '../entities/asset_detail.dart';

abstract interface class AssetRepository {
  /// Paginated sync from Horse API → local SQLite.
  Future<void> syncAssets();

  /// All local assets, optionally filtered by hospital.
  Future<List<Asset>> getAssets({String? hospital});

  /// Search local assets by equipment_type, serial_number, or barcode.
  Future<List<Asset>> searchAssets(String query, {String? hospital});

  /// Lookup by local SQLite PK.
  Future<Asset?> getAssetById(int id);

  /// Fetch full asset record from Horse API (not stored locally).
  Future<AssetDetail> getAssetDetail(int assetId);

  /// Create a provisional record offline.
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

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/features/assets/domain/
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/assets/domain/repositories/asset_repository.dart
git commit -m "feat(assets): add AssetRepository interface"
```

---

## Task 7: AssetRemoteDataSource

**Files:**
- Create: `lib/features/assets/data/datasources/asset_remote_data_source.dart`

- [ ] **Step 1: Create the remote datasource**

Create `lib/features/assets/data/datasources/asset_remote_data_source.dart`:
```dart
import 'package:dio/dio.dart';

import '../../data/models/asset_detail_model.dart';
import '../../data/models/asset_model.dart';

abstract interface class AssetRemoteDataSource {
  /// GET /assets?page=N&page_size=500 — slim records for sync.
  Future<List<AssetModel>> getAssets({required int page, int pageSize = 500});

  /// GET /assets/{id} — full record for detail view.
  Future<AssetDetailModel> getAssetDetail(int assetId);
}

class AssetRemoteDataSourceImpl implements AssetRemoteDataSource {
  AssetRemoteDataSourceImpl(this._dio);
  final Dio _dio;

  @override
  Future<List<AssetModel>> getAssets({
    required int page,
    int pageSize = 500,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/assets',
      queryParameters: {'page': page, 'page_size': pageSize},
    );
    final items = response.data!['data'] as List<dynamic>;
    return items
        .cast<Map<String, dynamic>>()
        .map(AssetModel.fromJson)
        .toList();
  }

  @override
  Future<AssetDetailModel> getAssetDetail(int assetId) async {
    final response =
        await _dio.get<Map<String, dynamic>>('/assets/$assetId');
    return AssetDetailModel.fromJson(response.data!);
  }
}
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/features/assets/data/datasources/asset_remote_data_source.dart
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/assets/data/datasources/asset_remote_data_source.dart
git commit -m "feat(assets): add AssetRemoteDataSource"
```

---

## Task 8: AssetRepositoryImpl + Unit Tests

**Files:**
- Create: `lib/features/assets/data/repositories/asset_repository_impl.dart`
- Create: `test/features/assets/data/repositories/asset_repository_impl_test.dart`

- [ ] **Step 1: Write tests first**

Create `test/features/assets/data/repositories/asset_repository_impl_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stat_trac_technical/features/assets/data/datasources/asset_local_data_source.dart';
import 'package:stat_trac_technical/features/assets/data/datasources/asset_remote_data_source.dart';
import 'package:stat_trac_technical/features/assets/data/models/asset_model.dart';
import 'package:stat_trac_technical/features/assets/data/repositories/asset_repository_impl.dart';

class MockAssetLocal extends Mock implements AssetLocalDataSource {}

class MockAssetRemote extends Mock implements AssetRemoteDataSource {}

AssetModel _makeModel(int assetId) => AssetModel(
      id: 0,
      assetId: assetId,
      equipmentType: 'Type $assetId',
      isActive: true,
      isCondemned: false,
      isProvisional: false,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  late MockAssetLocal mockLocal;
  late MockAssetRemote mockRemote;
  late AssetRepositoryImpl repo;

  setUp(() {
    mockLocal = MockAssetLocal();
    mockRemote = MockAssetRemote();
    repo = AssetRepositoryImpl(local: mockLocal, remote: mockRemote);
  });

  group('syncAssets', () {
    test('fetches one page when batch size < 500', () async {
      final batch = List.generate(3, _makeModel);
      when(() => mockRemote.getAssets(page: 1, pageSize: 500))
          .thenAnswer((_) async => batch);
      when(() => mockLocal.upsertAll(any())).thenAnswer((_) async {});

      await repo.syncAssets();

      verify(() => mockRemote.getAssets(page: 1, pageSize: 500)).called(1);
      verify(() => mockLocal.upsertAll(batch)).called(1);
      // Only 1 page because batch.length (3) < 500.
      verifyNever(() => mockRemote.getAssets(page: 2, pageSize: 500));
    });

    test('fetches multiple pages when first batch is full', () async {
      final fullBatch = List.generate(500, _makeModel);
      final lastBatch = List.generate(10, (i) => _makeModel(i + 500));

      when(() => mockRemote.getAssets(page: 1, pageSize: 500))
          .thenAnswer((_) async => fullBatch);
      when(() => mockRemote.getAssets(page: 2, pageSize: 500))
          .thenAnswer((_) async => lastBatch);
      when(() => mockLocal.upsertAll(any())).thenAnswer((_) async {});

      await repo.syncAssets();

      verify(() => mockRemote.getAssets(page: 1, pageSize: 500)).called(1);
      verify(() => mockRemote.getAssets(page: 2, pageSize: 500)).called(1);
      verifyNever(() => mockRemote.getAssets(page: 3, pageSize: 500));
    });

    test('rethrows remote exceptions', () async {
      when(() => mockRemote.getAssets(page: 1, pageSize: 500))
          .thenThrow(Exception('network error'));

      expect(() => repo.syncAssets(), throwsA(isA<Exception>()));
    });
  });

  group('getAssets', () {
    test('delegates to local datasource', () async {
      final assets = [_makeModel(1), _makeModel(2)];
      when(() => mockLocal.getAssets(hospital: any(named: 'hospital')))
          .thenAnswer((_) async => assets);

      final result = await repo.getAssets(hospital: 'St. Mary');

      expect(result, assets);
      verify(() => mockLocal.getAssets(hospital: 'St. Mary')).called(1);
    });
  });
}
```

- [ ] **Step 2: Run tests — expect FAIL**

```bash
flutter test test/features/assets/data/repositories/asset_repository_impl_test.dart
```

Expected: FAIL — `AssetRepositoryImpl` doesn't exist yet.

- [ ] **Step 3: Create AssetRepositoryImpl**

Create `lib/features/assets/data/repositories/asset_repository_impl.dart`:
```dart
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/asset.dart';
import '../../domain/entities/asset_detail.dart';
import '../../domain/repositories/asset_repository.dart';
import '../datasources/asset_local_data_source.dart';
import '../datasources/asset_remote_data_source.dart';

class AssetRepositoryImpl implements AssetRepository {
  AssetRepositoryImpl({
    required AssetLocalDataSource local,
    required AssetRemoteDataSource remote,
  })  : _local = local,
        _remote = remote;

  final AssetLocalDataSource _local;
  final AssetRemoteDataSource _remote;

  static const _syncKey = 'assets_last_synced';

  @override
  Future<void> syncAssets() async {
    var page = 1;
    while (true) {
      final batch = await _remote.getAssets(page: page, pageSize: 500);
      await _local.upsertAll(batch);
      if (batch.length < 500) break;
      page++;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_syncKey, DateTime.now().toIso8601String());
  }

  @override
  Future<List<Asset>> getAssets({String? hospital}) =>
      _local.getAssets(hospital: hospital);

  @override
  Future<List<Asset>> searchAssets(String query, {String? hospital}) =>
      _local.searchAssets(query, hospital: hospital);

  @override
  Future<Asset?> getAssetById(int id) => _local.getAssetById(id);

  @override
  Future<AssetDetail> getAssetDetail(int assetId) =>
      _remote.getAssetDetail(assetId);

  @override
  Future<Asset> createProvisional({
    required String equipmentType,
    String? model,
    String? manufacturer,
    String? serialNumber,
    String? hospital,
    String? location,
  }) =>
      _local.createProvisional(
        equipmentType: equipmentType,
        model: model,
        manufacturer: manufacturer,
        serialNumber: serialNumber,
        hospital: hospital,
        location: location,
      );
}
```

- [ ] **Step 4: Run tests — expect PASS**

```bash
flutter test test/features/assets/data/repositories/asset_repository_impl_test.dart
```

Expected: all 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/assets/data/repositories/asset_repository_impl.dart \
        test/features/assets/data/repositories/asset_repository_impl_test.dart
git commit -m "feat(assets): add AssetRepositoryImpl with paginated sync"
```

---

## Task 9: Asset Providers + build_runner

**Files:**
- Create: `lib/features/assets/presentation/providers/asset_providers.dart`
- Generated: `lib/features/assets/presentation/providers/asset_providers.g.dart`

The provider file imports `databaseHelperProvider` and `assetLocalDataSourceProvider` from `work_order_providers.dart` — they're already wired there and we reuse them rather than duplicate.

- [ ] **Step 1: Create asset_providers.dart**

Create `lib/features/assets/presentation/providers/asset_providers.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../api/auth_interceptor.dart';
import '../../../../../api/dio_client.dart';
import '../../../../auth/presentation/providers/auth_providers.dart';
import '../../../work_orders/presentation/providers/work_order_providers.dart';
import '../../data/datasources/asset_remote_data_source.dart';
import '../../data/repositories/asset_repository_impl.dart';
import '../../domain/entities/asset.dart';
import '../../domain/entities/asset_detail.dart';
import '../../domain/repositories/asset_repository.dart';

part 'asset_providers.g.dart';

// ── Infrastructure ────────────────────────────────────────────────────────────

@riverpod
AssetRemoteDataSource assetRemoteDataSource(Ref ref) {
  final authLocal = ref.watch(authLocalDataSourceProvider);
  final authRemote = ref.watch(authRemoteDataSourceProvider);
  final interceptor = AuthInterceptor(local: authLocal, remote: authRemote);
  return AssetRemoteDataSourceImpl(buildDioClient(interceptor));
}

@riverpod
AssetRepository assetRepository(Ref ref) => AssetRepositoryImpl(
      local: ref.watch(assetLocalDataSourceProvider),
      remote: ref.watch(assetRemoteDataSourceProvider),
    );

// ── Browse ────────────────────────────────────────────────────────────────────

@riverpod
Future<List<Asset>> assets(Ref ref, {String? hospital}) =>
    ref.watch(assetRepositoryProvider).getAssets(hospital: hospital);

@riverpod
Future<List<String>> hospitalList(Ref ref) =>
    ref.watch(assetLocalDataSourceProvider).getHospitals();

// ── Search ────────────────────────────────────────────────────────────────────

@riverpod
Future<List<Asset>> assetSearch(
  Ref ref,
  String query, {
  String? hospital,
}) =>
    ref.watch(assetRepositoryProvider).searchAssets(query, hospital: hospital);

// ── Detail ────────────────────────────────────────────────────────────────────

@riverpod
Future<AssetDetail> assetDetail(Ref ref, int assetId) =>
    ref.watch(assetRepositoryProvider).getAssetDetail(assetId);
```

- [ ] **Step 2: Run build_runner**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: `asset_providers.g.dart` is generated. No errors.

- [ ] **Step 3: Verify compile**

```bash
flutter analyze lib/features/assets/presentation/providers/
```

Expected: no errors.

- [ ] **Step 4: Run all asset tests**

```bash
flutter test test/features/assets/
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/assets/presentation/providers/
git commit -m "feat(assets): add asset providers (Riverpod codegen)"
```

---

## Task 10: AssetListScreen

**Files:**
- Create: `lib/features/assets/presentation/screens/asset_list_screen.dart`

- [ ] **Step 1: Create AssetListScreen**

Create `lib/features/assets/presentation/screens/asset_list_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../domain/entities/asset.dart';
import '../providers/asset_providers.dart';
import 'asset_barcode_scanner_screen.dart';
import 'asset_detail_screen.dart';

class AssetListScreen extends ConsumerStatefulWidget {
  const AssetListScreen({super.key});

  @override
  ConsumerState<AssetListScreen> createState() => _AssetListScreenState();
}

class _AssetListScreenState extends ConsumerState<AssetListScreen> {
  String? _selectedHospital;
  String _query = '';
  final _searchController = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _startSearch() => setState(() => _searching = true);

  void _stopSearch() {
    setState(() {
      _searching = false;
      _query = '';
      _searchController.clear();
    });
  }

  void _openScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => const AssetBarcodeScannerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search equipment, serial, barcode…',
                  hintStyle: TextStyle(color: Colors.white60),
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              )
            : const Text('Assets'),
        actions: [
          if (_searching)
            IconButton(
                icon: const Icon(Icons.close), onPressed: _stopSearch)
          else ...[
            IconButton(
                icon: const Icon(Icons.search), onPressed: _startSearch),
            IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: _openScanner),
          ],
        ],
      ),
      body: Column(
        children: [
          _HospitalFilterBar(
            selected: _selectedHospital,
            onSelect: (h) => setState(() => _selectedHospital = h),
          ),
          const Divider(height: 1),
          Expanded(
            child: _searching && _query.isNotEmpty
                ? _SearchResults(
                    query: _query, hospital: _selectedHospital)
                : _AssetBrowseList(hospital: _selectedHospital),
          ),
        ],
      ),
    );
  }
}

// ── Hospital filter chips ─────────────────────────────────────────────────────

class _HospitalFilterBar extends ConsumerWidget {
  const _HospitalFilterBar(
      {required this.selected, required this.onSelect});
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hospitalsAsync = ref.watch(hospitalListProvider);

    return hospitalsAsync.when(
      loading: () => const SizedBox(height: 44),
      error: (_, __) => const SizedBox(height: 44),
      data: (hospitals) {
        if (hospitals.isEmpty) return const SizedBox(height: 44);
        return SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              _FilterChip(
                  label: 'All',
                  selected: selected == null,
                  onTap: () => onSelect(null)),
              ...hospitals.map((h) => _FilterChip(
                    label: h,
                    selected: selected == h,
                    onTap: () =>
                        onSelect(selected == h ? null : h),
                  )),
            ],
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip(
      {required this.label,
      required this.selected,
      required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: brandTeal.withAlpha(40),
        checkmarkColor: brandTeal,
      ),
    );
  }
}

// ── Browse list ───────────────────────────────────────────────────────────────

class _AssetBrowseList extends ConsumerWidget {
  const _AssetBrowseList({this.hospital});
  final String? hospital;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetsAsync = ref.watch(assetsProvider(hospital: hospital));

    return assetsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ),
      data: (assets) => assets.isEmpty
          ? const Center(child: Text('No assets. Tap sync to download.'))
          : ListView.separated(
              itemCount: assets.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 16),
              itemBuilder: (_, i) =>
                  _AssetTile(asset: assets[i]),
            ),
    );
  }
}

// ── Search results ────────────────────────────────────────────────────────────

class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.query, this.hospital});
  final String query;
  final String? hospital;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync =
        ref.watch(assetSearchProvider(query, hospital: hospital));

    return resultsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (assets) => assets.isEmpty
          ? const Center(child: Text('No assets matched'))
          : ListView.separated(
              itemCount: assets.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 16),
              itemBuilder: (_, i) =>
                  _AssetTile(asset: assets[i]),
            ),
    );
  }
}

// ── Asset tile ────────────────────────────────────────────────────────────────

class _AssetTile extends StatelessWidget {
  const _AssetTile({required this.asset});
  final Asset asset;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        Icons.medical_services_outlined,
        color: asset.isProvisional
            ? const Color(0xFFF57F17)
            : asset.isCondemned
                ? brandGrey
                : brandTeal,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(asset.equipmentType,
                style: Theme.of(context).textTheme.bodyLarge),
          ),
          if (asset.isServiceDue)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                color: brandError.withAlpha(30),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: brandError),
              ),
              child: const Text(
                'SERVICE DUE',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: brandError,
                ),
              ),
            ),
          if (asset.isCondemned)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                color: brandGrey.withAlpha(30),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: brandGrey),
              ),
              child: const Text(
                'CONDEMNED',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: brandGrey,
                ),
              ),
            ),
          if (asset.isProvisional)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF57F17).withAlpha(30),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFF57F17)),
              ),
              child: const Text(
                'PROV',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFF57F17),
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        _subtitle(asset),
        style: Theme.of(context).textTheme.bodySmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () {
        if (asset.assetId != null) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                AssetDetailScreen(assetId: asset.assetId!, localAsset: asset),
          ));
        }
      },
    );
  }

  String _subtitle(Asset a) {
    final parts = <String>[];
    if (a.manufacturer != null) parts.add(a.manufacturer!);
    if (a.serialNumber != null) parts.add('S/N: ${a.serialNumber}');
    if (a.hospital != null) parts.add(a.hospital!);
    if (a.location != null) parts.add(a.location!);
    if (a.nextServiceDate != null) {
      parts.add(
          'Next svc: ${DateFormat('dd MMM yyyy').format(a.nextServiceDate!)}');
    }
    return parts.join(' · ');
  }
}
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/features/assets/presentation/screens/asset_list_screen.dart
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/assets/presentation/screens/asset_list_screen.dart
git commit -m "feat(assets): add AssetListScreen with hospital filter chips + search"
```

---

## Task 11: Barcode Scanner Screen

**Files:**
- Create: `lib/features/assets/presentation/screens/asset_barcode_scanner_screen.dart`

- [ ] **Step 1: Create barcode scanner screen**

Create `lib/features/assets/presentation/screens/asset_barcode_scanner_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../work_orders/presentation/providers/work_order_providers.dart';
import 'asset_detail_screen.dart';

class AssetBarcodeScannerScreen extends ConsumerStatefulWidget {
  const AssetBarcodeScannerScreen({super.key});

  @override
  ConsumerState<AssetBarcodeScannerScreen> createState() =>
      _AssetBarcodeScannerScreenState();
}

class _AssetBarcodeScannerScreenState
    extends ConsumerState<AssetBarcodeScannerScreen> {
  bool _handled = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode == null || barcode.isEmpty) return;

    _handled = true;

    final ds = ref.read(assetLocalDataSourceProvider);
    final asset = await ds.getAssetByBarcode(barcode);

    if (!mounted) return;

    if (asset != null && asset.assetId != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AssetDetailScreen(
              assetId: asset.assetId!, localAsset: asset),
        ),
      );
    } else {
      // Asset not found — prompt for provisional registration.
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Asset Not Found'),
          content: Text(
              'No asset with barcode "$barcode" in local database.\n\n'
              'Register as a provisional asset?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Register Provisional'),
            ),
          ],
        ),
      );

      if (mounted) {
        if (confirmed == true) {
          Navigator.of(context).pop(); // Back to list — picker handles form
        } else {
          setState(() => _handled = false); // Allow next scan
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Asset Barcode')),
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetect),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Point camera at asset barcode',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/features/assets/presentation/screens/asset_barcode_scanner_screen.dart
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/assets/presentation/screens/asset_barcode_scanner_screen.dart
git commit -m "feat(assets): add barcode scanner screen using mobile_scanner"
```

---

## Task 12: AssetDetailScreen

**Files:**
- Create: `lib/features/assets/presentation/screens/asset_detail_screen.dart`

- [ ] **Step 1: Create AssetDetailScreen**

Create `lib/features/assets/presentation/screens/asset_detail_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../domain/entities/asset.dart';
import '../../domain/entities/asset_detail.dart';
import '../providers/asset_providers.dart';

class AssetDetailScreen extends ConsumerWidget {
  const AssetDetailScreen({
    super.key,
    required this.assetId,
    required this.localAsset,
  });

  final int assetId;
  final Asset localAsset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(assetDetailProvider(assetId));

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Asset $assetId'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Service'),
              Tab(text: 'Warranty'),
            ],
          ),
        ),
        body: Column(
          children: [
            _HeaderCard(asset: localAsset),
            Expanded(
              child: detailAsync.when(
                loading: () => const _SkeletonBody(),
                error: (e, _) => const _OfflineBody(),
                data: (detail) => _TabBody(detail: detail),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header card (from local slim record) ─────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.asset});
  final Asset asset;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.medical_services_outlined,
                    color: brandTeal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    asset.equipmentType,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (asset.model != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(asset.model!,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            const SizedBox(height: 8),
            _InfoRow(
                icon: Icons.factory_outlined,
                text: asset.manufacturer ?? '—'),
            if (asset.serialNumber != null)
              _InfoRow(
                  icon: Icons.tag, text: 'S/N: ${asset.serialNumber}'),
            if (asset.barcode != null)
              _InfoRow(
                  icon: Icons.qr_code,
                  text: 'Barcode: ${asset.barcode}'),
            if (asset.hospital != null)
              _InfoRow(
                  icon: Icons.local_hospital_outlined,
                  text: asset.hospital!),
            if (asset.location != null)
              _InfoRow(
                  icon: Icons.location_on_outlined,
                  text: asset.location!),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: brandGrey),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

// ── Tab body ──────────────────────────────────────────────────────────────────

class _TabBody extends StatelessWidget {
  const _TabBody({required this.detail});
  final AssetDetail detail;

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      children: [
        _OverviewTab(detail: detail),
        _ServiceTab(detail: detail),
        _WarrantyTab(detail: detail),
      ],
    );
  }
}

// ── Overview tab ──────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.detail});
  final AssetDetail detail;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _DetailRow(label: 'Condition', value: detail.condition ?? '—'),
        _DetailRow(label: 'Risk Level', value: detail.riskLabel),
        _DetailRow(
          label: 'Status',
          value: detail.isCondemned
              ? 'Condemned'
              : detail.isActive
                  ? 'Active'
                  : 'Inactive',
        ),
        _DetailRow(
            label: 'Loan Unit',
            value: detail.isLoan ? 'Yes' : 'No'),
        _DetailRow(
            label: 'Demo Unit',
            value: detail.isDemo ? 'Yes' : 'No'),
        if (detail.softwareVersion != null)
          _DetailRow(
              label: 'Software Version',
              value: detail.softwareVersion!),
        if (detail.accessories != null)
          _DetailRow(
              label: 'Accessories', value: detail.accessories!),
        if (detail.notes != null) ...[
          const Divider(),
          Text('Notes', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(detail.notes!,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}

// ── Service tab ───────────────────────────────────────────────────────────────

class _ServiceTab extends StatelessWidget {
  const _ServiceTab({required this.detail});
  final AssetDetail detail;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _DetailRow(
          label: 'Last Service Date',
          value: detail.lastServiceDate != null
              ? fmt.format(detail.lastServiceDate!)
              : '—',
        ),
        _DetailRow(
          label: 'Next Service Date',
          value: detail.nextServiceDate != null
              ? fmt.format(detail.nextServiceDate!)
              : '—',
          valueColor: (detail.nextServiceDate != null &&
                  detail.nextServiceDate!
                      .isBefore(DateTime.now().add(const Duration(days: 30))))
              ? brandError
              : null,
        ),
        _DetailRow(
            label: 'Operating Hours',
            value: detail.hours?.toString() ?? '—'),
        const Divider(),
        _DetailRow(
          label: 'Service Plan',
          value: detail.hasServicePlan ? 'Active' : 'None',
        ),
        if (detail.hasServicePlan) ...[
          _DetailRow(
            label: 'Plan Start',
            value: detail.servicePlanStartDate != null
                ? fmt.format(detail.servicePlanStartDate!)
                : '—',
          ),
          _DetailRow(
            label: 'Plan Expiry',
            value: detail.servicePlanExpDate != null
                ? fmt.format(detail.servicePlanExpDate!)
                : '—',
          ),
          if (detail.servicePlanValue != null)
            _DetailRow(
              label: 'Plan Value',
              value:
                  'R ${detail.servicePlanValue!.toStringAsFixed(2)}',
            ),
        ],
      ],
    );
  }
}

// ── Warranty tab ──────────────────────────────────────────────────────────────

class _WarrantyTab extends StatelessWidget {
  const _WarrantyTab({required this.detail});
  final AssetDetail detail;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _DetailRow(
          label: 'Warranty Status',
          value: detail.isUnderWarranty ? 'Under Warranty' : 'Expired',
          valueColor: detail.isUnderWarranty ? Colors.green : null,
        ),
        _DetailRow(
          label: 'Type',
          value: detail.assetType == 1 ? 'Warranty' : 'Non-warranty',
        ),
        _DetailRow(
          label: 'Warranty Start',
          value: detail.warrantyDateStart != null
              ? fmt.format(detail.warrantyDateStart!)
              : '—',
        ),
        _DetailRow(
          label: 'Warranty End',
          value: detail.warrantyEndDate != null
              ? fmt.format(detail.warrantyEndDate!)
              : '—',
        ),
        if (detail.warrantyPeriod != null)
          _DetailRow(
              label: 'Period',
              value: '${detail.warrantyPeriod} months'),
        const Divider(),
        _DetailRow(
          label: 'Manufacture Date',
          value: detail.manufactureDate != null
              ? fmt.format(detail.manufactureDate!)
              : '—',
        ),
        _DetailRow(
          label: 'Delivery Date',
          value: detail.deliverDate != null
              ? fmt.format(detail.deliverDate!)
              : '—',
        ),
        _DetailRow(
          label: 'Commission Date',
          value: detail.commissionDate != null
              ? fmt.format(detail.commissionDate!)
              : '—',
        ),
      ],
    );
  }
}

// ── Shared row widget ─────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  const _DetailRow(
      {required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: brandGrey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: valueColor,
                    fontWeight: valueColor != null ? FontWeight.w600 : null,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

class _SkeletonBody extends StatelessWidget {
  const _SkeletonBody();

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      children: List.generate(
        3,
        (_) => ListView(
          padding: const EdgeInsets.all(16),
          children: List.generate(
            5,
            (_) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Container(
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(40),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Offline state ─────────────────────────────────────────────────────────────

class _OfflineBody extends StatelessWidget {
  const _OfflineBody();

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      children: List.generate(
        3,
        (_) => const Center(
          child: Text('Connect to view full details'),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/features/assets/presentation/screens/asset_detail_screen.dart
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/assets/presentation/screens/asset_detail_screen.dart
git commit -m "feat(assets): add AssetDetailScreen with Overview/Service/Warranty tabs"
```

---

## Task 13: Wire Dashboard + Sync Integration

Connect the Assets bottom nav tab and replace the `triggerSync()` placeholder with a real `syncAssets()` call.

**Files:**
- Update: `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
- Update: `lib/sync/sync_notifier.dart`

- [ ] **Step 1: Wire Assets tab in DashboardScreen**

In `lib/features/dashboard/presentation/screens/dashboard_screen.dart`:

1. Add the import for `AssetListScreen` at the top (after the create_work_order import):
```dart
import '../../../assets/presentation/screens/asset_list_screen.dart';
```

2. Replace the `_onNavTap` method and `body` line. Find:
```dart
  void _onNavTap(int index) {
    if (index != 0) {
      const labels = ['', 'Assets', 'Inventory', 'Meter'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${labels[index]} — coming soon')),
      );
      return;
    }
    setState(() => _navIndex = index);
  }
```

Replace with:
```dart
  void _onNavTap(int index) {
    if (index == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AssetListScreen()),
      );
      return;
    }
    if (index > 1) {
      const labels = ['', '', 'Inventory', 'Meter'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${labels[index]} — coming soon')),
      );
      return;
    }
    setState(() => _navIndex = index);
  }
```

- [ ] **Step 2: Replace sync placeholder in SyncNotifier**

In `lib/sync/sync_notifier.dart`:

1. Add imports at the top (after the existing imports):
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/assets/presentation/providers/asset_providers.dart';
```

2. Replace the `try` block inside `triggerSync()`. Find:
```dart
    try {
      // TODO(phase1): inject SyncService and call sync() once the
      // database and API layers are in place.
      await Future<void>.delayed(Duration.zero);
      state = SyncComplete(DateTime.now());
    } on Exception catch (e) {
```

Replace with:
```dart
    try {
      await ref.read(assetRepositoryProvider).syncAssets();
      state = SyncComplete(DateTime.now());
    } on Exception catch (e) {
```

- [ ] **Step 3: Verify full project**

```bash
flutter analyze lib/
```

Expected: no errors.

- [ ] **Step 4: Run all tests**

```bash
flutter test
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dashboard/presentation/screens/dashboard_screen.dart \
        lib/sync/sync_notifier.dart
git commit -m "feat(assets): wire Assets tab in Dashboard and hook syncAssets() into SyncNotifier"
```

---

## Spec Coverage Check

| Spec Requirement | Task |
|---|---|
| DB migration 002→003 (v4) | Task 2 |
| `Asset` entity (12 fields) | Task 3 |
| `AssetDetail` entity (30+ fields) | Task 4 |
| `AssetLocalDataSource` updated | Task 5 |
| `AssetRepository` interface | Task 6 |
| `AssetRemoteDataSource` | Task 7 |
| `AssetRepositoryImpl` + paginated sync | Task 8 |
| `asset_providers.dart` (Riverpod) | Task 9 |
| `AssetPickerDialog` updated | Task 5 |
| `AssetListScreen` (hospital chips, search) | Task 10 |
| Barcode scanner | Task 11 |
| `AssetDetailScreen` (3 tabs) | Task 12 |
| Dashboard nav wired | Task 13 |
| `syncAssets()` in `SyncNotifier` | Task 13 |
| `SERVICE DUE` badge (≤30 days) | Task 10 |
| `CONDEMNED` badge | Task 10 |
| `PROVISIONAL` badge | Task 10 |
| Offline tab state ("Connect to view...") | Task 12 |
| Provisionals survive migration | Task 2 — temp rescue table copies them before DROP, restores after CREATE |

---

## Phase 2 (Deferred)

- `PATCH /assets/{id}` — update condition, notes, location
- "Create Work Order" FAB on AssetDetailScreen
- Horse API endpoints implementation
