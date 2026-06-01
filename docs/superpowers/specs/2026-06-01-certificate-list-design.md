# Certificate List & Detail — Design

Date: 2026-06-01

## Summary

A "View Certificates" quick action on the dashboard opens a read-only certificate list. Tapping any row opens a certificate detail screen showing the header and all test item results. Data is read entirely from local SQLite — offline-first, no server calls needed.

## Entry Point

New `_QuickActionTile` on the dashboard home screen: icon `workspace_premium_outlined`, label "View Certificates", colour brandTeal. Navigates to `CertificateListScreen`.

## Certificate List Screen

**Route:** Pushed from dashboard quick action.

**Data source:** `getCertificates()` — SQLite raw query joining `test_certificates`, `test_template_names`, and `assets`, sorted by `created_at DESC`.

**Each row displays:**
- Title: `test_template_names.test_template_cert_name` (e.g. "EVOLUTION VENTILATOR OVP")
- Subtitle: `assets.equipment_type` (e.g. "CPAP MACHINE") — null-safe fallback to "Unknown asset"
- Left chip: Type badge — "QA" (amber), "TEST" (brandTeal), "CS" (green) mapped from `cert_type` int (2=QA, 1=TEST, 3=CS)
- Right: formatted date from `test_certificates.created_at`
- Bottom right: "PENDING" amber badge if `sync_status = 'pending'`

**Empty state:** "No certificates yet — tap Create Certificate to get started."

**Tap action:** Navigate to `CertificateDetailScreen(certId: id)`.

## Certificate Detail Screen

**Route:** Pushed from `CertificateListScreen`.

**Data sources:**
- `getCertificateById(int id)` — single cert row with template name + asset equipment type
- `getOutputsByCertId(int id)` — already exists

**Layout:**

### Header card
- Template cert name (titleLarge)
- Asset equipment type (bodyLarge, brandGrey)
- Cert type chip (QA / TEST / CS)
- Date issued
- Sync status chip: "Synced" (green) or "Pending sync" (amber)

### Test items section
- Grouped by `description_id` section (teal-background section headers, same style as `_SectionHeader` in `cert_test_grid.dart`)
- Each item row (read-only):
  - Description + notes
  - Expected value (grey)
  - Actual value (black)
  - Result chip: P (green), F (brandError), N/A (brandGrey) — filled colour if selected, outline if not

**No edit actions** — purely read-only.

## New Data Methods

### CertLocalDataSource interface additions

```dart
Future<List<CertificateSummary>> getCertificates();
Future<CertificateSummary?> getCertificateById(int id);
```

### CertificateSummary model (new)

A lightweight read model for list + detail — avoids making the entity carry joined fields:

```dart
class CertificateSummary {
  final int id;
  final int certType;
  final String syncStatus;
  final DateTime createdAt;
  final String? certName;       // from test_template_names
  final String? equipmentType;  // from assets
}
```

### SQLite query (both methods)

```sql
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
ORDER BY tc.created_at DESC
```

For `getCertificateById`, add `WHERE tc.id = ?`.

## New Riverpod Providers

```dart
@riverpod
Future<List<CertificateSummary>> certificateList(Ref ref) =>
    ref.watch(certLocalDataSourceProvider).getCertificates();

@riverpod
Future<CertificateSummary?> certificateSummary(Ref ref, int id) =>
    ref.watch(certLocalDataSourceProvider).getCertificateById(id);
```

## File Map

| File | Action |
|---|---|
| `lib/features/certification/data/models/certificate_summary.dart` | Create — CertificateSummary class + fromMap |
| `lib/features/certification/data/datasources/cert_local_data_source.dart` | Modify — add getCertificates() and getCertificateById(int id) |
| `lib/features/certification/presentation/providers/certificate_providers.dart` | Modify — add certificateListProvider and certificateSummaryProvider |
| `lib/features/certification/presentation/providers/certificate_providers.g.dart` | Regenerate |
| `lib/features/certification/presentation/screens/certificate_list_screen.dart` | Create |
| `lib/features/certification/presentation/screens/certificate_detail_screen.dart` | Create |
| `lib/features/dashboard/presentation/screens/dashboard_screen.dart` | Modify — add "View Certificates" tile |
