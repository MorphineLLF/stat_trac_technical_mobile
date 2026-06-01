# Create Certificate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a "Create Certificate" flow launched from the dashboard that lets a technician select a certificate type, pick an asset, pick a template, fill in a test items grid, sign, and save locally — ready to sync to the server.

**Architecture:** Clean Architecture matching the Work Orders module. Four new SQLite tables (migration_005) store templates and issued certs locally. Domain entities → data models → local/remote data sources → repository → Riverpod providers → 4 screens/widgets composed into a single stepper screen.

**Tech Stack:** Flutter, Riverpod 3 (riverpod_annotation ^4), sqflite, signature package (already in pubspec), Dio stubs for remote.

---

## File Map

| File | Action | Purpose |
|---|---|---|
| `lib/database/migrations/migration_005_certificates.dart` | Create | 4 new SQLite tables |
| `lib/database/database_helper.dart` | Modify | Register migration, bump version to 6 |
| `lib/features/certification/domain/entities/test_template_name.dart` | Create | Template header entity |
| `lib/features/certification/domain/entities/test_template_item.dart` | Create | Template line-item entity |
| `lib/features/certification/domain/entities/test_certificate.dart` | Create | Issued certificate entity |
| `lib/features/certification/domain/entities/test_output.dart` | Create | Test result line-item entity |
| `lib/features/certification/domain/repositories/certificate_repository.dart` | Create | Abstract interface |
| `lib/features/certification/data/models/test_template_name_model.dart` | Create | fromMap/toMap for SQLite |
| `lib/features/certification/data/models/test_template_item_model.dart` | Create | fromMap/toMap for SQLite |
| `lib/features/certification/data/models/test_certificate_model.dart` | Create | fromMap/toMap for SQLite |
| `lib/features/certification/data/models/test_output_model.dart` | Create | fromMap/toMap for SQLite |
| `lib/features/certification/data/datasources/cert_local_data_source.dart` | Create | SQLite CRUD interface + impl |
| `lib/features/certification/data/datasources/cert_remote_data_source.dart` | Create | Dio stub interface + impl |
| `lib/features/certification/data/repositories/certificate_repository_impl.dart` | Create | Wires local + remote |
| `lib/features/certification/presentation/providers/certificate_providers.dart` | Create | Riverpod providers |
| `lib/features/certification/presentation/providers/certificate_providers.g.dart` | Generate | build_runner output |
| `lib/features/certification/presentation/screens/create_certificate_screen.dart` | Create | Stepper host screen |
| `lib/features/certification/presentation/widgets/cert_type_selector.dart` | Create | 3-tile type picker |
| `lib/features/certification/presentation/widgets/cert_template_picker.dart` | Create | Filtered template list |
| `lib/features/certification/presentation/widgets/cert_test_grid.dart` | Create | Section-grouped test items |
| `lib/features/certification/presentation/widgets/cert_signature_step.dart` | Create | Tech + optional customer signature |
| `lib/features/dashboard/presentation/screens/dashboard_screen.dart` | Modify | Wire "Create Certificate" tile |

---

## Task 1: SQLite Migration — 4 Certificate Tables

**Files:**
- Create: `lib/database/migrations/migration_005_certificates.dart`
- Modify: `lib/database/database_helper.dart`

- [ ] **Step 1: Create the migration file**

```dart
// lib/database/migrations/migration_005_certificates.dart
import 'package:sqflite/sqflite.dart';

Future<void> migration005Certificates(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS test_template_names (
      id                        INTEGER PRIMARY KEY,
      test_template_name        TEXT,
      test_template_cert_name   TEXT,
      test_template_type        INTEGER,
      test_template_customer_sig INTEGER DEFAULT 0,
      test_template_doc_no      TEXT,
      test_template_note        TEXT,
      last_synced_at            TEXT
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS test_template_items (
      id                  INTEGER PRIMARY KEY,
      certificate_name_id INTEGER NOT NULL,
      description_id      TEXT,
      description_no      INTEGER,
      description         TEXT,
      notes               TEXT,
      expected_value      TEXT
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS test_certificates (
      id               INTEGER PRIMARY KEY AUTOINCREMENT,
      server_id        INTEGER,
      asset_id         INTEGER,
      test_date        TEXT,
      cert_type        INTEGER,
      template_name_id INTEGER,
      technician       TEXT,
      technician_id    INTEGER,
      next_service     TEXT,
      wo_number        INTEGER,
      jobcard_no       TEXT,
      doc_no           TEXT,
      service_interval TEXT,
      service_type     TEXT,
      tech_signature   BLOB,
      client_signature BLOB,
      client_name      TEXT,
      notes            TEXT,
      sync_status      TEXT NOT NULL DEFAULT 'pending',
      created_at       TEXT NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS test_outputs (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      certificate_id  INTEGER NOT NULL,
      asset_id        INTEGER,
      description_id  TEXT,
      description     TEXT,
      expected_value  TEXT,
      actual_value    TEXT,
      notes           TEXT,
      pass            INTEGER DEFAULT 0,
      fail            INTEGER DEFAULT 0,
      na              INTEGER DEFAULT 0
    )
  ''');
}
```

- [ ] **Step 2: Register migration and bump DB version**

Open `lib/database/database_helper.dart`. Make these changes:

```dart
import 'migrations/migration_001_work_orders.dart';
import 'migrations/migration_003_assets_v2.dart';
import 'migrations/migration_004_sync_error_log.dart';
import 'migrations/migration_005_certificates.dart';  // ADD THIS

class DatabaseHelper {
  // ...
  static const _dbVersion = 6;  // WAS 5

  Future<void> _onCreate(Database db, int version) async {
    await migration001WorkOrders(db);
    await migration003AssetsV2(db);
    await migration004SyncErrorLog(db);
    await migration005Certificates(db);  // ADD THIS
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await migration001WorkOrders(db);
    if (oldVersion < 4) await migration003AssetsV2(db);
    if (oldVersion < 5) await migration004SyncErrorLog(db);
    if (oldVersion < 6) await migration005Certificates(db);  // ADD THIS
  }
```

- [ ] **Step 3: Verify the app still launches with no crash**

Run: `flutter run`
Expected: App launches on dashboard, no migration errors in console.

- [ ] **Step 4: Commit**

```
git add lib/database/migrations/migration_005_certificates.dart lib/database/database_helper.dart
git commit -m "feat(cert): migration_005 — add test_template_names, test_template_items, test_certificates, test_outputs tables"
```

---

## Task 2: Domain Entities

**Files:**
- Create: `lib/features/certification/domain/entities/test_template_name.dart`
- Create: `lib/features/certification/domain/entities/test_template_item.dart`
- Create: `lib/features/certification/domain/entities/test_certificate.dart`
- Create: `lib/features/certification/domain/entities/test_output.dart`

- [ ] **Step 1: Create `TestTemplateName` entity**

```dart
// lib/features/certification/domain/entities/test_template_name.dart
import 'package:flutter/foundation.dart';

enum CertType { test, qa, commission }

@immutable
class TestTemplateName {
  const TestTemplateName({
    required this.id,
    required this.certType,
    this.templateName,
    this.certName,
    this.customerSigRequired = false,
    this.docNo,
    this.note,
    this.lastSyncedAt,
  });

  final int id;
  final CertType certType;
  final String? templateName;
  final String? certName;
  final bool customerSigRequired;
  final String? docNo;
  final String? note;
  final DateTime? lastSyncedAt;

  String get displayName => certName ?? templateName ?? 'Template $id';

  static CertType typeFromInt(int? v) {
    switch (v) {
      case 2: return CertType.qa;
      case 3: return CertType.commission;
      default: return CertType.test;
    }
  }

  static int typeToInt(CertType t) {
    switch (t) {
      case CertType.qa: return 2;
      case CertType.commission: return 3;
      case CertType.test: return 1;
    }
  }
}
```

- [ ] **Step 2: Create `TestTemplateItem` entity**

```dart
// lib/features/certification/domain/entities/test_template_item.dart
import 'package:flutter/foundation.dart';

@immutable
class TestTemplateItem {
  const TestTemplateItem({
    required this.id,
    required this.certificateNameId,
    this.descriptionId,
    this.descriptionNo,
    this.description,
    this.notes,
    this.expectedValue,
  });

  final int id;
  final int certificateNameId;
  final String? descriptionId;   // section name e.g. "SET-UP"
  final int? descriptionNo;      // section sequence
  final String? description;     // test item label
  final String? notes;
  final String? expectedValue;
}
```

- [ ] **Step 3: Create `TestCertificate` entity**

```dart
// lib/features/certification/domain/entities/test_certificate.dart
import 'package:flutter/foundation.dart';

@immutable
class TestCertificate {
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
  });

  final int id;
  final int? serverId;
  final int? assetId;
  final DateTime? testDate;
  final int certType;
  final int? templateNameId;
  final String? technician;
  final int? technicianId;
  final DateTime? nextService;
  final int? woNumber;
  final String? jobcardNo;
  final String? docNo;
  final String? serviceInterval;
  final String? serviceType;
  final List<int>? techSignature;    // PNG bytes
  final List<int>? clientSignature;  // PNG bytes
  final String? clientName;
  final String? notes;
  final String syncStatus;           // 'pending' | 'synced' | 'error'
  final DateTime createdAt;
}
```

- [ ] **Step 4: Create `TestOutput` entity**

```dart
// lib/features/certification/domain/entities/test_output.dart
import 'package:flutter/foundation.dart';

@immutable
class TestOutput {
  const TestOutput({
    required this.id,
    required this.certificateId,
    this.assetId,
    this.descriptionId,
    this.description,
    this.expectedValue,
    this.actualValue,
    this.notes,
    this.pass = false,
    this.fail = false,
    this.na = false,
  });

  final int id;
  final int certificateId;
  final int? assetId;
  final String? descriptionId;
  final String? description;
  final String? expectedValue;
  final String? actualValue;
  final String? notes;
  final bool pass;
  final bool fail;
  final bool na;

  TestOutput copyWith({
    String? actualValue,
    String? notes,
    bool? pass,
    bool? fail,
    bool? na,
  }) => TestOutput(
        id: id,
        certificateId: certificateId,
        assetId: assetId,
        descriptionId: descriptionId,
        description: description,
        expectedValue: expectedValue,
        actualValue: actualValue ?? this.actualValue,
        notes: notes ?? this.notes,
        pass: pass ?? this.pass,
        fail: fail ?? this.fail,
        na: na ?? this.na,
      );
}
```

- [ ] **Step 5: Commit**

```
git add lib/features/certification/domain/
git commit -m "feat(cert): domain entities — TestTemplateName, TestTemplateItem, TestCertificate, TestOutput"
```

---

## Task 3: Data Models (SQLite ↔ Entity)

**Files:**
- Create: `lib/features/certification/data/models/test_template_name_model.dart`
- Create: `lib/features/certification/data/models/test_template_item_model.dart`
- Create: `lib/features/certification/data/models/test_certificate_model.dart`
- Create: `lib/features/certification/data/models/test_output_model.dart`

- [ ] **Step 1: Create `TestTemplateNameModel`**

```dart
// lib/features/certification/data/models/test_template_name_model.dart
import '../../domain/entities/test_template_name.dart';

class TestTemplateNameModel extends TestTemplateName {
  const TestTemplateNameModel({
    required super.id,
    required super.certType,
    super.templateName,
    super.certName,
    super.customerSigRequired,
    super.docNo,
    super.note,
    super.lastSyncedAt,
  });

  factory TestTemplateNameModel.fromMap(Map<String, dynamic> m) =>
      TestTemplateNameModel(
        id: m['id'] as int,
        certType: TestTemplateName.typeFromInt(m['test_template_type'] as int?),
        templateName: m['test_template_name'] as String?,
        certName: m['test_template_cert_name'] as String?,
        customerSigRequired: (m['test_template_customer_sig'] as int? ?? 0) != 0,
        docNo: m['test_template_doc_no'] as String?,
        note: m['test_template_note'] as String?,
        lastSyncedAt: m['last_synced_at'] != null
            ? DateTime.parse(m['last_synced_at'] as String)
            : null,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'test_template_name': templateName,
        'test_template_cert_name': certName,
        'test_template_type': TestTemplateName.typeToInt(certType),
        'test_template_customer_sig': customerSigRequired ? 1 : 0,
        'test_template_doc_no': docNo,
        'test_template_note': note,
        'last_synced_at': lastSyncedAt?.toIso8601String(),
      };
}
```

- [ ] **Step 2: Create `TestTemplateItemModel`**

```dart
// lib/features/certification/data/models/test_template_item_model.dart
import '../../domain/entities/test_template_item.dart';

class TestTemplateItemModel extends TestTemplateItem {
  const TestTemplateItemModel({
    required super.id,
    required super.certificateNameId,
    super.descriptionId,
    super.descriptionNo,
    super.description,
    super.notes,
    super.expectedValue,
  });

  factory TestTemplateItemModel.fromMap(Map<String, dynamic> m) =>
      TestTemplateItemModel(
        id: m['id'] as int,
        certificateNameId: m['certificate_name_id'] as int,
        descriptionId: m['description_id'] as String?,
        descriptionNo: m['description_no'] as int?,
        description: m['description'] as String?,
        notes: m['notes'] as String?,
        expectedValue: m['expected_value'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'certificate_name_id': certificateNameId,
        'description_id': descriptionId,
        'description_no': descriptionNo,
        'description': description,
        'notes': notes,
        'expected_value': expectedValue,
      };
}
```

- [ ] **Step 3: Create `TestCertificateModel`**

```dart
// lib/features/certification/data/models/test_certificate_model.dart
import '../../domain/entities/test_certificate.dart';

class TestCertificateModel extends TestCertificate {
  const TestCertificateModel({
    required super.id,
    required super.certType,
    required super.syncStatus,
    required super.createdAt,
    super.serverId,
    super.assetId,
    super.testDate,
    super.templateNameId,
    super.technician,
    super.technicianId,
    super.nextService,
    super.woNumber,
    super.jobcardNo,
    super.docNo,
    super.serviceInterval,
    super.serviceType,
    super.techSignature,
    super.clientSignature,
    super.clientName,
    super.notes,
  });

  factory TestCertificateModel.fromMap(Map<String, dynamic> m) =>
      TestCertificateModel(
        id: m['id'] as int,
        serverId: m['server_id'] as int?,
        assetId: m['asset_id'] as int?,
        testDate: m['test_date'] != null
            ? DateTime.parse(m['test_date'] as String)
            : null,
        certType: m['cert_type'] as int? ?? 1,
        templateNameId: m['template_name_id'] as int?,
        technician: m['technician'] as String?,
        technicianId: m['technician_id'] as int?,
        nextService: m['next_service'] != null
            ? DateTime.parse(m['next_service'] as String)
            : null,
        woNumber: m['wo_number'] as int?,
        jobcardNo: m['jobcard_no'] as String?,
        docNo: m['doc_no'] as String?,
        serviceInterval: m['service_interval'] as String?,
        serviceType: m['service_type'] as String?,
        techSignature: m['tech_signature'] != null
            ? List<int>.from(m['tech_signature'] as List)
            : null,
        clientSignature: m['client_signature'] != null
            ? List<int>.from(m['client_signature'] as List)
            : null,
        clientName: m['client_name'] as String?,
        notes: m['notes'] as String?,
        syncStatus: m['sync_status'] as String? ?? 'pending',
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        if (id != 0) 'id': id,
        'server_id': serverId,
        'asset_id': assetId,
        'test_date': testDate?.toIso8601String(),
        'cert_type': certType,
        'template_name_id': templateNameId,
        'technician': technician,
        'technician_id': technicianId,
        'next_service': nextService?.toIso8601String(),
        'wo_number': woNumber,
        'jobcard_no': jobcardNo,
        'doc_no': docNo,
        'service_interval': serviceInterval,
        'service_type': serviceType,
        'tech_signature': techSignature,
        'client_signature': clientSignature,
        'client_name': clientName,
        'notes': notes,
        'sync_status': syncStatus,
        'created_at': createdAt.toIso8601String(),
      };
}
```

- [ ] **Step 4: Create `TestOutputModel`**

```dart
// lib/features/certification/data/models/test_output_model.dart
import '../../domain/entities/test_output.dart';

class TestOutputModel extends TestOutput {
  const TestOutputModel({
    required super.id,
    required super.certificateId,
    super.assetId,
    super.descriptionId,
    super.description,
    super.expectedValue,
    super.actualValue,
    super.notes,
    super.pass,
    super.fail,
    super.na,
  });

  factory TestOutputModel.fromMap(Map<String, dynamic> m) => TestOutputModel(
        id: m['id'] as int,
        certificateId: m['certificate_id'] as int,
        assetId: m['asset_id'] as int?,
        descriptionId: m['description_id'] as String?,
        description: m['description'] as String?,
        expectedValue: m['expected_value'] as String?,
        actualValue: m['actual_value'] as String?,
        notes: m['notes'] as String?,
        pass: (m['pass'] as int? ?? 0) == 1,
        fail: (m['fail'] as int? ?? 0) == 1,
        na: (m['na'] as int? ?? 0) == 1,
      );

  Map<String, dynamic> toMap() => {
        if (id != 0) 'id': id,
        'certificate_id': certificateId,
        'asset_id': assetId,
        'description_id': descriptionId,
        'description': description,
        'expected_value': expectedValue,
        'actual_value': actualValue,
        'notes': notes,
        'pass': pass ? 1 : 0,
        'fail': fail ? 1 : 0,
        'na': na ? 1 : 0,
      };
}
```

- [ ] **Step 5: Run flutter analyze to check for errors**

Run: `flutter analyze lib/features/certification/`
Expected: No errors.

- [ ] **Step 6: Commit**

```
git add lib/features/certification/data/models/
git commit -m "feat(cert): data models with fromMap/toMap for all 4 certification entities"
```

---

## Task 4: Local Data Source

**Files:**
- Create: `lib/features/certification/data/datasources/cert_local_data_source.dart`

- [ ] **Step 1: Write the interface and implementation**

```dart
// lib/features/certification/data/datasources/cert_local_data_source.dart
import '../../../../database/database_helper.dart';
import '../../domain/entities/test_template_name.dart';
import '../../domain/entities/test_template_item.dart';
import '../../domain/entities/test_certificate.dart';
import '../../domain/entities/test_output.dart';
import '../models/test_template_name_model.dart';
import '../models/test_template_item_model.dart';
import '../models/test_certificate_model.dart';
import '../models/test_output_model.dart';

abstract interface class CertLocalDataSource {
  Future<List<TestTemplateName>> getTemplatesByType(CertType type);
  Future<List<TestTemplateItem>> getTemplateItems(int templateNameId);
  Future<void> upsertTemplates(List<TestTemplateNameModel> templates);
  Future<void> upsertTemplateItems(List<TestTemplateItemModel> items);
  Future<int> saveCertificate(TestCertificateModel cert);
  Future<void> saveOutputs(List<TestOutputModel> outputs);
  Future<List<TestCertificate>> getPendingSyncCertificates();
  Future<void> markSynced(int certificateId, int serverId);
}

class CertLocalDataSourceImpl implements CertLocalDataSource {
  CertLocalDataSourceImpl(this._db);
  final DatabaseHelper _db;

  @override
  Future<List<TestTemplateName>> getTemplatesByType(CertType type) async {
    final db = await _db.database;
    final typeInt = TestTemplateName.typeToInt(type);
    final rows = await db.query(
      'test_template_names',
      where: 'test_template_type = ?',
      whereArgs: [typeInt],
      orderBy: 'test_template_cert_name ASC',
    );
    return rows.map(TestTemplateNameModel.fromMap).toList();
  }

  @override
  Future<List<TestTemplateItem>> getTemplateItems(int templateNameId) async {
    final db = await _db.database;
    final rows = await db.query(
      'test_template_items',
      where: 'certificate_name_id = ?',
      whereArgs: [templateNameId],
      orderBy: 'description_no ASC, id ASC',
    );
    return rows.map(TestTemplateItemModel.fromMap).toList();
  }

  @override
  Future<void> upsertTemplates(List<TestTemplateNameModel> templates) async {
    final db = await _db.database;
    final batch = db.batch();
    for (final t in templates) {
      batch.insert(
        'test_template_names',
        t.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> upsertTemplateItems(List<TestTemplateItemModel> items) async {
    final db = await _db.database;
    final batch = db.batch();
    for (final item in items) {
      batch.insert(
        'test_template_items',
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<int> saveCertificate(TestCertificateModel cert) async {
    final db = await _db.database;
    return db.insert('test_certificates', cert.toMap());
  }

  @override
  Future<void> saveOutputs(List<TestOutputModel> outputs) async {
    final db = await _db.database;
    final batch = db.batch();
    for (final o in outputs) {
      batch.insert('test_outputs', o.toMap());
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<List<TestCertificate>> getPendingSyncCertificates() async {
    final db = await _db.database;
    final rows = await db.query(
      'test_certificates',
      where: 'sync_status = ?',
      whereArgs: ['pending'],
    );
    return rows.map(TestCertificateModel.fromMap).toList();
  }

  @override
  Future<void> markSynced(int certificateId, int serverId) async {
    final db = await _db.database;
    await db.update(
      'test_certificates',
      {'sync_status': 'synced', 'server_id': serverId},
      where: 'id = ?',
      whereArgs: [certificateId],
    );
  }
}
```

- [ ] **Step 2: Add missing sqflite import**

The file needs `ConflictAlgorithm` from sqflite. Add to the top of the file:

```dart
import 'package:sqflite/sqflite.dart';
```

- [ ] **Step 3: Run flutter analyze**

Run: `flutter analyze lib/features/certification/data/datasources/cert_local_data_source.dart`
Expected: No errors.

- [ ] **Step 4: Commit**

```
git add lib/features/certification/data/datasources/cert_local_data_source.dart
git commit -m "feat(cert): CertLocalDataSource — SQLite CRUD for templates, items, certificates, outputs"
```

---

## Task 5: Remote Data Source (Stub)

**Files:**
- Create: `lib/features/certification/data/datasources/cert_remote_data_source.dart`

- [ ] **Step 1: Create the stub**

```dart
// lib/features/certification/data/datasources/cert_remote_data_source.dart
import '../models/test_template_name_model.dart';
import '../models/test_template_item_model.dart';

abstract interface class CertRemoteDataSource {
  /// GET /certificates/templates?type=<1|2|3>
  /// Returns [] until Horse API is implemented.
  Future<List<TestTemplateNameModel>> fetchTemplates(int type);

  /// GET /certificates/templates/:id/items
  /// Returns [] until Horse API is implemented.
  Future<List<TestTemplateItemModel>> fetchTemplateItems(int templateId);

  /// POST /certificates
  /// Returns the server-assigned ID, or throws if unavailable.
  Future<int> pushCertificate(Map<String, dynamic> payload);
}

class CertRemoteDataSourceImpl implements CertRemoteDataSource {
  @override
  Future<List<TestTemplateNameModel>> fetchTemplates(int type) async => [];

  @override
  Future<List<TestTemplateItemModel>> fetchTemplateItems(int templateId) async => [];

  @override
  Future<int> pushCertificate(Map<String, dynamic> payload) async =>
      throw UnimplementedError('Certificate sync endpoint not yet available');
}
```

- [ ] **Step 2: Commit**

```
git add lib/features/certification/data/datasources/cert_remote_data_source.dart
git commit -m "feat(cert): CertRemoteDataSource stub — Horse API endpoints wired when server is ready"
```

---

## Task 6: Repository Interface + Implementation

**Files:**
- Create: `lib/features/certification/domain/repositories/certificate_repository.dart`
- Create: `lib/features/certification/data/repositories/certificate_repository_impl.dart`

- [ ] **Step 1: Create the abstract interface**

```dart
// lib/features/certification/domain/repositories/certificate_repository.dart
import '../entities/test_template_name.dart';
import '../entities/test_template_item.dart';
import '../entities/test_certificate.dart';
import '../entities/test_output.dart';

abstract class CertificateRepository {
  Future<List<TestTemplateName>> getTemplatesByType(CertType type);
  Future<List<TestTemplateItem>> getTemplateItems(int templateNameId);
  Future<int> issueCertificate({
    required TestCertificate cert,
    required List<TestOutput> outputs,
  });
  Future<void> syncTemplatesFromRemote();
}
```

- [ ] **Step 2: Create the implementation**

```dart
// lib/features/certification/data/repositories/certificate_repository_impl.dart
import '../../domain/entities/test_certificate.dart';
import '../../domain/entities/test_output.dart';
import '../../domain/entities/test_template_item.dart';
import '../../domain/entities/test_template_name.dart';
import '../../domain/repositories/certificate_repository.dart';
import '../datasources/cert_local_data_source.dart';
import '../datasources/cert_remote_data_source.dart';
import '../models/test_certificate_model.dart';
import '../models/test_output_model.dart';

class CertificateRepositoryImpl implements CertificateRepository {
  CertificateRepositoryImpl({required this.local, required this.remote});
  final CertLocalDataSource local;
  final CertRemoteDataSource remote;

  @override
  Future<List<TestTemplateName>> getTemplatesByType(CertType type) =>
      local.getTemplatesByType(type);

  @override
  Future<List<TestTemplateItem>> getTemplateItems(int templateNameId) =>
      local.getTemplateItems(templateNameId);

  @override
  Future<int> issueCertificate({
    required TestCertificate cert,
    required List<TestOutput> outputs,
  }) async {
    final certModel = TestCertificateModel(
      id: 0,
      certType: cert.certType,
      syncStatus: 'pending',
      createdAt: cert.createdAt,
      assetId: cert.assetId,
      testDate: cert.testDate,
      templateNameId: cert.templateNameId,
      technician: cert.technician,
      technicianId: cert.technicianId,
      nextService: cert.nextService,
      woNumber: cert.woNumber,
      jobcardNo: cert.jobcardNo,
      docNo: cert.docNo,
      serviceInterval: cert.serviceInterval,
      serviceType: cert.serviceType,
      techSignature: cert.techSignature,
      clientSignature: cert.clientSignature,
      clientName: cert.clientName,
      notes: cert.notes,
    );
    final certId = await local.saveCertificate(certModel);

    final outputModels = outputs.map((o) => TestOutputModel(
          id: 0,
          certificateId: certId,
          assetId: o.assetId,
          descriptionId: o.descriptionId,
          description: o.description,
          expectedValue: o.expectedValue,
          actualValue: o.actualValue,
          notes: o.notes,
          pass: o.pass,
          fail: o.fail,
          na: o.na,
        )).toList();

    await local.saveOutputs(outputModels);
    return certId;
  }

  @override
  Future<void> syncTemplatesFromRemote() async {
    // Remote stubs return [] — no-op until Horse API is ready.
    // When the server is live, fetch all 3 types and upsert locally.
  }
}
```

- [ ] **Step 3: Commit**

```
git add lib/features/certification/domain/repositories/ lib/features/certification/data/repositories/
git commit -m "feat(cert): CertificateRepository interface and implementation"
```

---

## Task 7: Riverpod Providers

**Files:**
- Create: `lib/features/certification/presentation/providers/certificate_providers.dart`
- Generate: `lib/features/certification/presentation/providers/certificate_providers.g.dart`

- [ ] **Step 1: Write providers**

```dart
// lib/features/certification/presentation/providers/certificate_providers.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../database/database_helper.dart';
import '../../data/datasources/cert_local_data_source.dart';
import '../../data/datasources/cert_remote_data_source.dart';
import '../../data/repositories/certificate_repository_impl.dart';
import '../../domain/entities/test_template_item.dart';
import '../../domain/entities/test_template_name.dart';
import '../../domain/repositories/certificate_repository.dart';

part 'certificate_providers.g.dart';

@riverpod
DatabaseHelper certDatabaseHelper(Ref ref) => DatabaseHelper.instance;

@riverpod
CertLocalDataSource certLocalDataSource(Ref ref) =>
    CertLocalDataSourceImpl(ref.watch(certDatabaseHelperProvider));

@riverpod
CertRemoteDataSource certRemoteDataSource(Ref ref) =>
    CertRemoteDataSourceImpl();

@riverpod
CertificateRepository certificateRepository(Ref ref) =>
    CertificateRepositoryImpl(
      local: ref.watch(certLocalDataSourceProvider),
      remote: ref.watch(certRemoteDataSourceProvider),
    );

@riverpod
Future<List<TestTemplateName>> templatesByType(Ref ref, CertType type) =>
    ref.watch(certificateRepositoryProvider).getTemplatesByType(type);

@riverpod
Future<List<TestTemplateItem>> templateItems(Ref ref, int templateNameId) =>
    ref.watch(certificateRepositoryProvider).getTemplateItems(templateNameId);
```

- [ ] **Step 2: Run code generation**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `certificate_providers.g.dart` is created, no errors.

- [ ] **Step 3: Run flutter analyze**

Run: `flutter analyze lib/features/certification/`
Expected: No errors.

- [ ] **Step 4: Commit**

```
git add lib/features/certification/presentation/providers/
git commit -m "feat(cert): Riverpod providers for certificate repository, templates, and items"
```

---

## Task 8: Type Selector Widget

**Files:**
- Create: `lib/features/certification/presentation/widgets/cert_type_selector.dart`

- [ ] **Step 1: Create the 3-tile type picker**

```dart
// lib/features/certification/presentation/widgets/cert_type_selector.dart
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../domain/entities/test_template_name.dart';

class CertTypeSelector extends StatelessWidget {
  const CertTypeSelector({super.key, required this.onSelected});
  final ValueChanged<CertType> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Select Certificate Type',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        _TypeTile(
          icon: Icons.science_outlined,
          label: 'Test Certificate',
          subtitle: 'Performance verification / OVP',
          type: CertType.test,
          onSelected: onSelected,
        ),
        _TypeTile(
          icon: Icons.verified_outlined,
          label: 'QA Certificate',
          subtitle: 'Quality assurance verification',
          type: CertType.qa,
          onSelected: onSelected,
        ),
        _TypeTile(
          icon: Icons.rocket_launch_outlined,
          label: 'Commission Certificate',
          subtitle: 'Commissioning & handover',
          type: CertType.commission,
          onSelected: onSelected,
        ),
      ],
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.type,
    required this.onSelected,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final CertType type;
  final ValueChanged<CertType> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: brandTeal, size: 32),
        title: Text(label, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => onSelected(type),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```
git add lib/features/certification/presentation/widgets/cert_type_selector.dart
git commit -m "feat(cert): CertTypeSelector widget — 3-tile picker for Test/QA/Commission"
```

---

## Task 9: Template Picker Widget

**Files:**
- Create: `lib/features/certification/presentation/widgets/cert_template_picker.dart`

- [ ] **Step 1: Create the template list**

```dart
// lib/features/certification/presentation/widgets/cert_template_picker.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../domain/entities/test_template_name.dart';
import '../providers/certificate_providers.dart';

class CertTemplatePicker extends ConsumerWidget {
  const CertTemplatePicker({
    super.key,
    required this.certType,
    required this.onSelected,
  });
  final CertType certType;
  final ValueChanged<TestTemplateName> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(templatesByTypeProvider(certType));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Select Template',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        Expanded(
          child: templatesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (templates) => templates.isEmpty
                ? const _EmptyTemplates()
                : ListView.builder(
                    itemCount: templates.length,
                    itemBuilder: (_, i) => _TemplateTile(
                      template: templates[i],
                      onTap: () => onSelected(templates[i]),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({required this.template, required this.onTap});
  final TestTemplateName template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: const Icon(Icons.description_outlined, color: brandTeal),
        title: Text(template.displayName,
            style: Theme.of(context).textTheme.titleMedium),
        subtitle: template.docNo != null ? Text('Doc: ${template.docNo}') : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _EmptyTemplates extends StatelessWidget {
  const _EmptyTemplates();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_download_outlined, size: 64, color: brandGrey),
          const SizedBox(height: 16),
          Text(
            'No templates loaded',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Sync to download certificate templates',
            style: TextStyle(color: brandGrey),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```
git add lib/features/certification/presentation/widgets/cert_template_picker.dart
git commit -m "feat(cert): CertTemplatePicker widget — filtered list from local SQLite"
```

---

## Task 10: Test Items Grid Widget

**Files:**
- Create: `lib/features/certification/presentation/widgets/cert_test_grid.dart`

- [ ] **Step 1: Create the section-grouped test items grid**

```dart
// lib/features/certification/presentation/widgets/cert_test_grid.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../domain/entities/test_template_item.dart';
import '../../domain/entities/test_output.dart';
import '../providers/certificate_providers.dart';

class CertTestGrid extends ConsumerStatefulWidget {
  const CertTestGrid({
    super.key,
    required this.templateNameId,
    required this.assetId,
    required this.onOutputsChanged,
  });
  final int templateNameId;
  final int assetId;
  final ValueChanged<List<TestOutput>> onOutputsChanged;

  @override
  ConsumerState<CertTestGrid> createState() => _CertTestGridState();
}

class _CertTestGridState extends ConsumerState<CertTestGrid> {
  // Map from item id → mutable output state
  final Map<int, _OutputState> _states = {};

  void _notify(List<TestTemplateItem> items) {
    final outputs = items.map((item) {
      final s = _states[item.id] ?? _OutputState();
      return TestOutput(
        id: 0,
        certificateId: 0,
        assetId: widget.assetId,
        descriptionId: item.descriptionId,
        description: item.description,
        expectedValue: item.expectedValue,
        actualValue: s.actualValue,
        notes: s.notes,
        pass: s.pass,
        fail: s.fail,
        na: s.na,
      );
    }).toList();
    widget.onOutputsChanged(outputs);
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(templateItemsProvider(widget.templateNameId));

    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Text('No test items for this template',
                style: TextStyle(color: brandGrey)),
          );
        }

        // Group by section (descriptionId)
        final sections = <String, List<TestTemplateItem>>{};
        for (final item in items) {
          final section = item.descriptionId ?? 'General';
          sections.putIfAbsent(section, () => []).add(item);
        }

        // Initialise state for any new items
        for (final item in items) {
          _states.putIfAbsent(item.id, () => _OutputState());
        }

        return ListView(
          children: [
            for (final entry in sections.entries) ...[
              _SectionHeader(title: entry.key),
              for (final item in entry.value)
                _TestItemRow(
                  item: item,
                  state: _states[item.id]!,
                  onChanged: (s) {
                    setState(() => _states[item.id] = s);
                    _notify(items);
                  },
                ),
            ],
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

class _OutputState {
  String? actualValue;
  String? notes;
  bool pass = false;
  bool fail = false;
  bool na = false;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: brandTeal.withAlpha(20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: brandTeal, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _TestItemRow extends StatelessWidget {
  const _TestItemRow({
    required this.item,
    required this.state,
    required this.onChanged,
  });
  final TestTemplateItem item;
  final _OutputState state;
  final ValueChanged<_OutputState> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.description ?? '',
                        style: Theme.of(context).textTheme.bodyMedium),
                    if (item.notes != null)
                      Text(item.notes!,
                          style: TextStyle(color: brandGrey, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Text(
                  item.expectedValue ?? '',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: brandGrey),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: state.actualValue,
                  decoration: const InputDecoration(
                    hintText: 'Actual',
                    isDense: true,
                  ),
                  onChanged: (v) {
                    final s = _OutputState()
                      ..actualValue = v
                      ..notes = state.notes
                      ..pass = state.pass
                      ..fail = state.fail
                      ..na = state.na;
                    onChanged(s);
                  },
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _ResultChip(
                label: 'P',
                color: Colors.green,
                selected: state.pass,
                onTap: () {
                  final s = _OutputState()
                    ..actualValue = state.actualValue
                    ..notes = state.notes
                    ..pass = !state.pass
                    ..fail = false
                    ..na = false;
                  onChanged(s);
                },
              ),
              const SizedBox(width: 4),
              _ResultChip(
                label: 'F',
                color: brandError,
                selected: state.fail,
                onTap: () {
                  final s = _OutputState()
                    ..actualValue = state.actualValue
                    ..notes = state.notes
                    ..pass = false
                    ..fail = !state.fail
                    ..na = false;
                  onChanged(s);
                },
              ),
              const SizedBox(width: 4),
              _ResultChip(
                label: 'N/A',
                color: brandGrey,
                selected: state.na,
                onTap: () {
                  final s = _OutputState()
                    ..actualValue = state.actualValue
                    ..notes = state.notes
                    ..pass = false
                    ..fail = false
                    ..na = !state.na;
                  onChanged(s);
                },
              ),
            ],
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

class _ResultChip extends StatelessWidget {
  const _ResultChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color : color.withAlpha(20),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```
git add lib/features/certification/presentation/widgets/cert_test_grid.dart
git commit -m "feat(cert): CertTestGrid — section-grouped test items with actual value input and Pass/Fail/NA"
```

---

## Task 11: Signature Step Widget

**Files:**
- Create: `lib/features/certification/presentation/widgets/cert_signature_step.dart`

- [ ] **Step 1: Add signature package import check**

Verify `signature` is in `pubspec.yaml`:
```
grep -r "signature:" pubspec.yaml
```
Expected: `signature: ...` line exists.

- [ ] **Step 2: Create the signature step**

```dart
// lib/features/certification/presentation/widgets/cert_signature_step.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import '../../../../../core/theme/app_theme.dart';

class CertSignatureStep extends StatefulWidget {
  const CertSignatureStep({
    super.key,
    required this.requiresCustomerSig,
    required this.onSigned,
  });
  final bool requiresCustomerSig;
  final ValueChanged<SignatureResult> onSigned;

  @override
  State<CertSignatureStep> createState() => _CertSignatureStepState();
}

class SignatureResult {
  const SignatureResult({
    required this.techSignatureBytes,
    this.clientSignatureBytes,
    this.clientName,
  });
  final Uint8List techSignatureBytes;
  final Uint8List? clientSignatureBytes;
  final String? clientName;
}

class _CertSignatureStepState extends State<CertSignatureStep> {
  final _techController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  final _clientController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  final _clientNameController = TextEditingController();

  @override
  void dispose() {
    _techController.dispose();
    _clientController.dispose();
    _clientNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_techController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Technician signature is required')),
      );
      return;
    }
    final techBytes = await _techController.toPngBytes();
    if (techBytes == null) return;

    Uint8List? clientBytes;
    if (widget.requiresCustomerSig) {
      if (_clientController.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Facility signature is required')),
        );
        return;
      }
      clientBytes = await _clientController.toPngBytes();
    }

    widget.onSigned(SignatureResult(
      techSignatureBytes: techBytes,
      clientSignatureBytes: clientBytes,
      clientName: _clientNameController.text.trim().isEmpty
          ? null
          : _clientNameController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Technician Signature',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _SignaturePad(controller: _techController),
        const SizedBox(height: 24),
        if (widget.requiresCustomerSig) ...[
          Text('Facility Signature',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextFormField(
            controller: _clientNameController,
            decoration: const InputDecoration(
              labelText: 'Facility Contact Name',
            ),
          ),
          const SizedBox(height: 8),
          _SignaturePad(controller: _clientController),
          const SizedBox(height: 24),
        ],
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check),
          label: const Text('Issue Certificate'),
        ),
      ],
    );
  }
}

class _SignaturePad extends StatelessWidget {
  const _SignaturePad({required this.controller});
  final SignatureController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: brandGrey),
        borderRadius: BorderRadius.circular(8),
      ),
      height: 180,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Signature(controller: controller, backgroundColor: Colors.white),
      ),
    );
  }
}
```

- [ ] **Step 3: Commit**

```
git add lib/features/certification/presentation/widgets/cert_signature_step.dart
git commit -m "feat(cert): CertSignatureStep — technician + optional facility signature capture"
```

---

## Task 12: Create Certificate Screen (Stepper Host)

**Files:**
- Create: `lib/features/certification/presentation/screens/create_certificate_screen.dart`

- [ ] **Step 1: Create the stepper screen**

```dart
// lib/features/certification/presentation/screens/create_certificate_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../assets/domain/entities/asset.dart';
import '../../../assets/presentation/widgets/asset_picker_dialog.dart';
import '../../domain/entities/test_certificate.dart';
import '../../domain/entities/test_output.dart';
import '../../domain/entities/test_template_name.dart';
import '../providers/certificate_providers.dart';
import '../widgets/cert_signature_step.dart';
import '../widgets/cert_template_picker.dart';
import '../widgets/cert_test_grid.dart';
import '../widgets/cert_type_selector.dart';

class CreateCertificateScreen extends ConsumerStatefulWidget {
  const CreateCertificateScreen({super.key});

  @override
  ConsumerState<CreateCertificateScreen> createState() =>
      _CreateCertificateScreenState();
}

class _CreateCertificateScreenState
    extends ConsumerState<CreateCertificateScreen> {
  int _step = 0;
  CertType? _selectedType;
  Asset? _selectedAsset;
  TestTemplateName? _selectedTemplate;
  List<TestOutput> _outputs = [];

  void _pickAsset() async {
    final asset = await showDialog<Asset>(
      context: context,
      builder: (_) => const AssetPickerDialog(),
    );
    if (asset != null) setState(() => _selectedAsset = asset);
  }

  void _goToStep(int step) => setState(() => _step = step);

  Future<void> _issueWithSignature(SignatureResult sig) async {
    final cert = TestCertificate(
      id: 0,
      certType: TestTemplateName.typeToInt(_selectedType!),
      syncStatus: 'pending',
      createdAt: DateTime.now(),
      assetId: _selectedAsset?.assetId,
      testDate: DateTime.now(),
      templateNameId: _selectedTemplate?.id,
      docNo: _selectedTemplate?.docNo,
      techSignature: sig.techSignatureBytes.toList(),
      clientSignature: sig.clientSignatureBytes?.toList(),
      clientName: sig.clientName,
    );

    await ref
        .read(certificateRepositoryProvider)
        .issueCertificate(cert: cert, outputs: _outputs);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Certificate saved — PDF will be generated on next sync'),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Certificate'),
        leading: _step == 0
            ? null
            : BackButton(onPressed: () => _goToStep(_step - 1)),
      ),
      body: IndexedStack(
        index: _step,
        children: [
          // Step 0: type selector
          CertTypeSelector(
            onSelected: (type) {
              setState(() => _selectedType = type);
              _goToStep(1);
            },
          ),

          // Step 1: asset picker prompt
          _AssetPickStep(
            selectedAsset: _selectedAsset,
            onPickTap: _pickAsset,
            onNext: _selectedAsset != null
                ? () => _goToStep(2)
                : null,
          ),

          // Step 2: template picker
          if (_selectedType != null)
            CertTemplatePicker(
              certType: _selectedType!,
              onSelected: (t) {
                setState(() => _selectedTemplate = t);
                _goToStep(3);
              },
            )
          else
            const SizedBox.shrink(),

          // Step 3: test items grid
          if (_selectedTemplate != null && _selectedAsset != null)
            Column(
              children: [
                Expanded(
                  child: CertTestGrid(
                    templateNameId: _selectedTemplate!.id,
                    assetId: _selectedAsset!.assetId ?? 0,
                    onOutputsChanged: (outputs) => _outputs = outputs,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: () => _goToStep(4),
                    child: const Text('Proceed to Sign'),
                  ),
                ),
              ],
            )
          else
            const SizedBox.shrink(),

          // Step 4: signatures
          if (_selectedTemplate != null)
            CertSignatureStep(
              requiresCustomerSig: _selectedTemplate!.customerSigRequired,
              onSigned: _issueWithSignature,
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class _AssetPickStep extends StatelessWidget {
  const _AssetPickStep({
    required this.selectedAsset,
    required this.onPickTap,
    required this.onNext,
  });
  final Asset? selectedAsset;
  final VoidCallback onPickTap;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select Asset',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          if (selectedAsset != null)
            Card(
              child: ListTile(
                leading:
                    const Icon(Icons.medical_services_outlined, color: brandTeal),
                title: Text(selectedAsset!.equipmentType),
                subtitle: Text([
                  if (selectedAsset!.hospital != null) selectedAsset!.hospital!,
                  if (selectedAsset!.serialNumber != null)
                    'S/N: ${selectedAsset!.serialNumber!}',
                ].join(' · ')),
                trailing: TextButton(
                  onPressed: onPickTap,
                  child: const Text('Change'),
                ),
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: onPickTap,
              icon: const Icon(Icons.search),
              label: const Text('Pick Asset'),
            ),
          const Spacer(),
          if (onNext != null)
            FilledButton(
              onPressed: onNext,
              child: const Text('Next'),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze lib/features/certification/`
Expected: No errors.

- [ ] **Step 3: Commit**

```
git add lib/features/certification/presentation/screens/create_certificate_screen.dart
git commit -m "feat(cert): CreateCertificateScreen — 5-step stepper: type → asset → template → test grid → signatures"
```

---

## Task 13: Wire Dashboard Quick Action

**Files:**
- Modify: `lib/features/dashboard/presentation/screens/dashboard_screen.dart`

- [ ] **Step 1: Add import for CreateCertificateScreen**

At the top of `dashboard_screen.dart`, add:

```dart
import '../../../certification/presentation/screens/create_certificate_screen.dart';
```

- [ ] **Step 2: Replace the placeholder tile**

Find this block (around line 502):
```dart
const _QuickActionTile(
  icon: Icons.verified_outlined,
  label: 'Create Certificate',
  color: brandTeal,
),
```

Replace with:
```dart
_QuickActionTile(
  icon: Icons.verified_outlined,
  label: 'Create Certificate',
  color: brandTeal,
  destination: (_) => const CreateCertificateScreen(),
),
```

- [ ] **Step 3: Run the app and test the tap**

Run: `flutter run`
Expected: Tapping "Create Certificate" on the dashboard opens the type selector screen (3 tiles: Test Certificate, QA Certificate, Commission Certificate).

- [ ] **Step 4: Commit**

```
git add lib/features/dashboard/presentation/screens/dashboard_screen.dart
git commit -m "feat(cert): wire 'Create Certificate' dashboard tile to CreateCertificateScreen"
```

---

## Task 14: Manual Integration Test — Full Flow

This task verifies the end-to-end flow without a server (local SQLite only).

- [ ] **Step 1: Seed a test template directly in SQLite**

In the running app, open a Flutter DevTools console or add a temporary button that inserts:

```dart
final db = await DatabaseHelper.instance.database;
await db.insert('test_template_names', {
  'id': 1,
  'test_template_name': 'EVOLUTION VENTILATOR - PERFORMANCE VERIFICATION',
  'test_template_cert_name': 'EVOLUTION VENTILATOR OVP',
  'test_template_type': 1,
  'test_template_customer_sig': 0,
  'test_template_doc_no': 'TEVO001',
});
await db.insert('test_template_items', {
  'id': 1, 'certificate_name_id': 1,
  'description_id': 'ELECTRICAL SAFETY TESTS', 'description_no': 1,
  'description': 'Ground Resistance', 'notes': '', 'expected_value': '< 0.2 Ohm',
});
await db.insert('test_template_items', {
  'id': 2, 'certificate_name_id': 1,
  'description_id': 'ELECTRICAL SAFETY TESTS', 'description_no': 1,
  'description': 'Forward Current Leakage', 'notes': '', 'expected_value': '< 300 uA',
});
await db.insert('test_template_items', {
  'id': 3, 'certificate_name_id': 1,
  'description_id': 'FUNCTIONAL TESTS', 'description_no': 2,
  'description': 'Oxygen Inlet Regulator', 'notes': '', 'expected_value': '21 psi +2/-1',
});
```

- [ ] **Step 2: Walk through the full flow**

1. Dashboard → "Create Certificate"
2. Tap "Test Certificate"
3. Pick an asset (must have at least one asset synced)
4. Tap "EVOLUTION VENTILATOR OVP" template
5. Fill in actual values and mark Pass/Fail/NA on 3 items
6. Tap "Proceed to Sign"
7. Draw technician signature
8. Tap "Issue Certificate"

Expected: Snackbar "Certificate saved — PDF will be generated on next sync". App returns to dashboard.

- [ ] **Step 3: Verify SQLite rows written**

Use Flutter DevTools → SQLite viewer, or add a temporary debug query:

```dart
final certs = await db.query('test_certificates');
final outputs = await db.query('test_outputs');
print('Certs: ${certs.length}, Outputs: ${outputs.length}');
```

Expected: 1 row in `test_certificates` with `sync_status = 'pending'`, 3 rows in `test_outputs`.

- [ ] **Step 4: Final commit**

```
git add .
git commit -m "feat(cert): Create Certificate flow complete — type selector, asset picker, template picker, test grid, signatures, local save"
```
