# Certificate List & Detail Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a read-only certificate list screen (accessible from the dashboard) and a certificate detail screen showing test item results.

**Architecture:** New `CertificateSummary` read model joins `test_certificates` + `test_template_names` + `assets` in a single SQLite rawQuery. Two new screens follow the Work Orders screen pattern. A new dashboard quick action tile provides entry.

**Tech Stack:** Flutter, Riverpod 3 (riverpod_annotation ^4), sqflite rawQuery, intl for date formatting.

---

## File Map

| File | Action | Purpose |
|---|---|---|
| `lib/features/certification/data/models/certificate_summary.dart` | Create | Read model for list + detail header |
| `lib/features/certification/data/datasources/cert_local_data_source.dart` | Modify | Add getCertificates() and getCertificateById(int) |
| `lib/features/certification/presentation/providers/certificate_providers.dart` | Modify | Add certificateListProvider + certificateSummaryProvider |
| `lib/features/certification/presentation/providers/certificate_providers.g.dart` | Regenerate | build_runner output |
| `lib/features/certification/presentation/screens/certificate_list_screen.dart` | Create | List of all certs, newest first |
| `lib/features/certification/presentation/screens/certificate_detail_screen.dart` | Create | Cert header + test outputs, read-only |
| `lib/features/dashboard/presentation/screens/dashboard_screen.dart` | Modify | Add "View Certificates" 5th quick action tile |

---

## Task 1: CertificateSummary Model

**Files:**
- Create: `lib/features/certification/data/models/certificate_summary.dart`

- [ ] **Step 1: Create the model**

```dart
// lib/features/certification/data/models/certificate_summary.dart
import 'package:flutter/foundation.dart';

@immutable
class CertificateSummary {
  const CertificateSummary({
    required this.id,
    required this.certType,
    required this.syncStatus,
    required this.createdAt,
    this.certName,
    this.equipmentType,
  });

  final int id;
  final int certType;           // 1=Test, 2=QA, 3=Commission
  final String syncStatus;      // 'pending' | 'synced'
  final DateTime createdAt;
  final String? certName;       // test_template_names.test_template_cert_name
  final String? equipmentType;  // assets.equipment_type

  String get typeLabel {
    switch (certType) {
      case 2: return 'QA';
      case 3: return 'CS';
      default: return 'TEST';
    }
  }

  bool get isPending => syncStatus == 'pending';

  factory CertificateSummary.fromMap(Map<String, dynamic> m) =>
      CertificateSummary(
        id: m['id'] as int,
        certType: m['cert_type'] as int? ?? 1,
        syncStatus: m['sync_status'] as String? ?? 'pending',
        createdAt: DateTime.parse(m['created_at'] as String),
        certName: m['cert_name'] as String?,
        equipmentType: m['equipment_type'] as String?,
      );
}
```

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze lib/features/certification/data/models/certificate_summary.dart`
Expected: No issues found.

- [ ] **Step 3: Commit**

```
git add lib/features/certification/data/models/certificate_summary.dart
git commit -m "feat(cert): CertificateSummary read model — joined cert + template + asset fields"
```

---

## Task 2: Add getCertificates() and getCertificateById() to CertLocalDataSource

**Files:**
- Modify: `lib/features/certification/data/datasources/cert_local_data_source.dart`

The SQL joins `test_certificates` with `test_template_names` (for cert name) and `assets` (for equipment type). Both joins are LEFT JOIN so certs without a matching template or asset still appear.

- [ ] **Step 1: Add the import for CertificateSummary**

At the top of `lib/features/certification/data/datasources/cert_local_data_source.dart`, add:

```dart
import '../models/certificate_summary.dart';
```

- [ ] **Step 2: Add methods to the interface**

In the `abstract interface class CertLocalDataSource` block, add after `updateSignatures`:

```dart
  Future<List<CertificateSummary>> getCertificates();
  Future<CertificateSummary?> getCertificateById(int id);
```

- [ ] **Step 3: Add implementations to CertLocalDataSourceImpl**

Add these two methods at the end of `CertLocalDataSourceImpl`, before the closing `}`:

```dart
  static const _certSummarySelect = '''
    SELECT
      tc.id,
      tc.cert_type,
      tc.sync_status,
      tc.created_at,
      tn.test_template_cert_name AS cert_name,
      a.equipment_type
    FROM test_certificates tc
    LEFT JOIN test_template_names tn ON tn.id = tc.template_name_id
    LEFT JOIN assets a ON a.asset_id = tc.asset_id
  ''';

  @override
  Future<List<CertificateSummary>> getCertificates() async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '$_certSummarySelect ORDER BY tc.created_at DESC',
    );
    return rows.map(CertificateSummary.fromMap).toList();
  }

  @override
  Future<CertificateSummary?> getCertificateById(int id) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '$_certSummarySelect WHERE tc.id = ?',
      [id],
    );
    return rows.isEmpty ? null : CertificateSummary.fromMap(rows.first);
  }
```

- [ ] **Step 4: Run flutter analyze**

Run: `flutter analyze lib/features/certification/data/datasources/cert_local_data_source.dart`
Expected: No issues found.

- [ ] **Step 5: Commit**

```
git add lib/features/certification/data/datasources/cert_local_data_source.dart
git commit -m "feat(cert): add getCertificates() and getCertificateById() to CertLocalDataSource"
```

---

## Task 3: Add Riverpod Providers

**Files:**
- Modify: `lib/features/certification/presentation/providers/certificate_providers.dart`
- Regenerate: `lib/features/certification/presentation/providers/certificate_providers.g.dart`

- [ ] **Step 1: Add import for CertificateSummary**

At the top of `certificate_providers.dart`, add:

```dart
import '../../data/models/certificate_summary.dart';
```

- [ ] **Step 2: Add two new providers**

Append after the last existing provider (`templateItems`):

```dart
@riverpod
Future<List<CertificateSummary>> certificateList(Ref ref) =>
    ref.watch(certLocalDataSourceProvider).getCertificates();

@riverpod
Future<CertificateSummary?> certificateSummary(Ref ref, int id) =>
    ref.watch(certLocalDataSourceProvider).getCertificateById(id);
```

- [ ] **Step 3: Run code generation**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `certificate_providers.g.dart` updated, no errors.

- [ ] **Step 4: Run flutter analyze**

Run: `flutter analyze lib/features/certification/presentation/providers/`
Expected: No issues found.

- [ ] **Step 5: Commit**

```
git add lib/features/certification/presentation/providers/
git commit -m "feat(cert): certificateListProvider and certificateSummaryProvider"
```

---

## Task 4: Certificate List Screen

**Files:**
- Create: `lib/features/certification/presentation/screens/certificate_list_screen.dart`

- [ ] **Step 1: Create the screen**

```dart
// lib/features/certification/presentation/screens/certificate_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../data/models/certificate_summary.dart';
import '../providers/certificate_providers.dart';
import 'certificate_detail_screen.dart';

class CertificateListScreen extends ConsumerWidget {
  const CertificateListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final certsAsync = ref.watch(certificateListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Certificates')),
      body: certsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
        data: (certs) => certs.isEmpty
            ? const _EmptyView()
            : ListView.builder(
                itemCount: certs.length,
                itemBuilder: (_, i) => _CertTile(cert: certs[i]),
              ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_outlined, size: 64, color: brandGrey),
          const SizedBox(height: 16),
          Text('No certificates yet',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Tap Create Certificate to get started',
            style: TextStyle(color: brandGrey),
          ),
        ],
      ),
    );
  }
}

// ── List tile ─────────────────────────────────────────────────────────────────

class _CertTile extends StatelessWidget {
  const _CertTile({required this.cert});
  final CertificateSummary cert;

  Color get _typeColor {
    switch (cert.certType) {
      case 2: return Colors.amber[700]!;
      case 3: return Colors.green[700]!;
      default: return brandTeal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('dd MMM yyyy').format(cert.createdAt.toLocal());

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _typeColor.withAlpha(20),
            border: Border.all(color: _typeColor),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            cert.typeLabel,
            style: TextStyle(
              color: _typeColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        title: Text(
          cert.certName ?? 'Unknown template',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (cert.equipmentType != null)
              Text(cert.equipmentType!,
                  style: TextStyle(color: brandGrey)),
            Row(
              children: [
                Text(dateStr,
                    style: Theme.of(context).textTheme.bodySmall),
                if (cert.isPending) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'PENDING',
                      style: TextStyle(
                        color: Colors.amber[800],
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CertificateDetailScreen(certId: cert.id),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze lib/features/certification/presentation/screens/certificate_list_screen.dart`
Expected: No issues found.

- [ ] **Step 3: Commit**

```
git add lib/features/certification/presentation/screens/certificate_list_screen.dart
git commit -m "feat(cert): CertificateListScreen — all certs newest first, type chip, pending badge"
```

---

## Task 5: Certificate Detail Screen

**Files:**
- Create: `lib/features/certification/presentation/screens/certificate_detail_screen.dart`

- [ ] **Step 1: Create the screen**

```dart
// lib/features/certification/presentation/screens/certificate_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../data/models/certificate_summary.dart';
import '../../domain/entities/test_output.dart';
import '../providers/certificate_providers.dart';

class CertificateDetailScreen extends ConsumerWidget {
  const CertificateDetailScreen({super.key, required this.certId});
  final int certId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(certificateSummaryProvider(certId));
    final outputsAsync = ref.watch(certOutputsProvider(certId));

    return Scaffold(
      appBar: AppBar(
        title: summaryAsync.when(
          data: (s) => Text(s?.certName ?? 'Certificate'),
          loading: () => const Text('Certificate'),
          error: (_, __) => const Text('Certificate'),
        ),
      ),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (summary) => summary == null
            ? const Center(child: Text('Certificate not found'))
            : _DetailBody(summary: summary, outputsAsync: outputsAsync),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.summary, required this.outputsAsync});
  final CertificateSummary summary;
  final AsyncValue<List<TestOutput>> outputsAsync;

  Color get _typeColor {
    switch (summary.certType) {
      case 2: return Colors.amber[700]!;
      case 3: return Colors.green[700]!;
      default: return brandTeal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _HeaderCard(summary: summary, typeColor: _typeColor),
        const SizedBox(height: 8),
        outputsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              Center(child: Text('Error loading results: $e')),
          data: (outputs) => outputs.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No test results recorded.',
                      style: TextStyle(color: brandGrey)),
                )
              : _OutputsSection(outputs: outputs),
        ),
      ],
    );
  }
}

// ── Header card ───────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.summary, required this.typeColor});
  final CertificateSummary summary;
  final Color typeColor;

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('dd MMM yyyy').format(summary.createdAt.toLocal());

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor.withAlpha(20),
                    border: Border.all(color: typeColor),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    summary.typeLabel,
                    style: TextStyle(
                      color: typeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: summary.isPending
                        ? Colors.amber[50]
                        : Colors.green[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    summary.isPending ? 'Pending sync' : 'Synced',
                    style: TextStyle(
                      color: summary.isPending
                          ? Colors.amber[800]
                          : Colors.green[700],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (summary.certName != null)
              Text(summary.certName!,
                  style: Theme.of(context).textTheme.titleLarge),
            if (summary.equipmentType != null) ...[
              const SizedBox(height: 4),
              Text(summary.equipmentType!,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: brandGrey)),
            ],
            const SizedBox(height: 8),
            Text(dateStr,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

// ── Test outputs ──────────────────────────────────────────────────────────────

class _OutputsSection extends StatelessWidget {
  const _OutputsSection({required this.outputs});
  final List<TestOutput> outputs;

  @override
  Widget build(BuildContext context) {
    // Group by section.
    final sections = <String, List<TestOutput>>{};
    for (final o in outputs) {
      final section = o.descriptionId ?? 'General';
      sections.putIfAbsent(section, () => []).add(o);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in sections.entries) ...[
          _SectionHeader(title: entry.key),
          for (final output in entry.value) _OutputRow(output: output),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: brandTeal.withAlpha(20),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: brandTeal,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _OutputRow extends StatelessWidget {
  const _OutputRow({required this.output});
  final TestOutput output;

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
                child: Text(output.description ?? '',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Text(
                  output.expectedValue ?? '',
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
                child: Text(
                  output.actualValue ?? '—',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _ResultChip(label: 'P', color: Colors.green, selected: output.pass),
              const SizedBox(width: 4),
              _ResultChip(label: 'F', color: brandError, selected: output.fail),
              const SizedBox(width: 4),
              _ResultChip(label: 'N/A', color: brandGrey, selected: output.na),
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
  });
  final String label;
  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}
```

- [ ] **Step 2: The detail screen uses `certOutputsProvider` — add it to providers**

Open `lib/features/certification/presentation/providers/certificate_providers.dart`.

Add this import at the top:
```dart
import '../../domain/entities/test_output.dart';
```

Add this provider after `certificateSummary`:
```dart
@riverpod
Future<List<TestOutput>> certOutputs(Ref ref, int certId) =>
    ref.watch(certLocalDataSourceProvider).getOutputsByCertId(certId);
```

Then regenerate: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 3: Run flutter analyze**

Run: `flutter analyze lib/features/certification/presentation/screens/certificate_detail_screen.dart`
Expected: No issues found.

- [ ] **Step 4: Commit**

```
git add lib/features/certification/presentation/screens/certificate_detail_screen.dart lib/features/certification/presentation/providers/
git commit -m "feat(cert): CertificateDetailScreen — read-only cert header + grouped test results"
```

---

## Task 6: Wire Dashboard Quick Action

**Files:**
- Modify: `lib/features/dashboard/presentation/screens/dashboard_screen.dart`

- [ ] **Step 1: Add import**

At the top of `dashboard_screen.dart`, add:
```dart
import '../../../certification/presentation/screens/certificate_list_screen.dart';
```

- [ ] **Step 2: Add the fifth quick action tile**

Find the quick actions children list. After the existing `_QuickActionTile` for "Create Certificate", add:

```dart
        _QuickActionTile(
          icon: Icons.workspace_premium_outlined,
          label: 'View Certificates',
          color: brandTeal,
          destination: (_) => const CertificateListScreen(),
        ),
```

The full children list should now have 5 tiles (the grid naturally expands to a third row).

- [ ] **Step 3: Run flutter test and analyze**

Run: `flutter test`
Expected: All 13 tests pass.

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 4: Commit**

```
git add lib/features/dashboard/presentation/screens/dashboard_screen.dart
git commit -m "feat(cert): wire 'View Certificates' dashboard tile to CertificateListScreen"
```
