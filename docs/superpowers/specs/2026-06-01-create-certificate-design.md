# Create Certificate — Design

Date: 2026-06-01

## Summary

A "Create Certificate" flow launched from the dashboard quick action. The technician selects a certificate type, picks an asset, picks a template, fills in a test items grid, signs, and saves. The certificate is stored locally and synced to the server.

## User Flow

1. **Select type** — QA Certificate / Commission Certificate / Test Certificate (maps to `TestTemplateType` 2 / 3 / 1)
2. **Pick asset** — reuse existing `AssetPickerDialog` (hospital → equipment list)
3. **Pick template** — list from `TestTemplateName` filtered by selected type (`TestTemplateType`)
4. **Fill test grid** — items from `TestTemplate` where `TestTempCertificateNameID = TestTemplateNameID`, grouped by section (`TestTempDescriptionID`). Tech fills `TestTempActualValue` and marks Pass / Fail / NA per item.
5. **Sign** — technician signature always required; facility/customer signature if `TestTemplateCustomerSig != 0`
6. **Save** — writes to `TestCertificate` + `TestOutput` (one row per test item)

## Database Tables (Production — Stat_Trac)

### Read (on sync / at form load)
- `TestTemplateName` — template list (filter by `TestTemplateType`)
- `TestTemplate` — test item rows (filter by `TestTempCertificateNameID`)
- `Asset` — asset details
- `AssetPmTask` — service interval for the asset

### Write (on save / sync)
- `TestCertificate` — one row per issued certificate
- `TestOutput` — one row per test item result

## Local SQLite Tables (new — migration_005)

```sql
CREATE TABLE test_template_names (
  id INTEGER PRIMARY KEY,
  test_template_name TEXT,
  test_template_cert_name TEXT,
  test_template_type INTEGER,           -- 1=Test, 2=QA, 3=Commission
  test_template_customer_sig INTEGER,   -- 0=no, 1=required
  test_template_doc_no TEXT,
  test_template_note TEXT,
  last_synced_at TEXT
);

CREATE TABLE test_template_items (
  id INTEGER PRIMARY KEY,
  certificate_name_id INTEGER,          -- FK → test_template_names.id
  description_id TEXT,                  -- section name
  description_no INTEGER,               -- section sequence
  description TEXT,
  notes TEXT,
  expected_value TEXT,
  sync_status TEXT DEFAULT 'pending'
);

CREATE TABLE test_certificates (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  server_id INTEGER,                    -- NULL until synced
  asset_id INTEGER,
  test_date TEXT,
  cert_type INTEGER,                    -- 1/2/3
  template_name_id INTEGER,
  technician TEXT,
  technician_id INTEGER,
  next_service TEXT,
  wo_number INTEGER,
  jobcard_no TEXT,
  doc_no TEXT,
  service_interval TEXT,
  service_type TEXT,
  tech_signature BLOB,
  client_signature BLOB,
  client_name TEXT,
  notes TEXT,
  sync_status TEXT DEFAULT 'pending',
  created_at TEXT
);

CREATE TABLE test_outputs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  certificate_id INTEGER,               -- FK → test_certificates.id
  asset_id INTEGER,
  description_id TEXT,
  description TEXT,
  expected_value TEXT,
  actual_value TEXT,
  notes TEXT,
  pass INTEGER,
  fail INTEGER,
  na INTEGER
);
```

## File Structure

```
lib/features/certification/
  domain/
    entities/
      test_template_name.dart
      test_template_item.dart
      test_certificate.dart
      test_output.dart
    repositories/
      certificate_repository.dart
  data/
    models/
      test_template_name_model.dart
      test_template_item_model.dart
      test_certificate_model.dart
      test_output_model.dart
    datasources/
      cert_local_data_source.dart
      cert_remote_data_source.dart       -- stubs; real API built later
    repositories/
      certificate_repository_impl.dart
  presentation/
    providers/
      certificate_providers.dart + .g.dart
    screens/
      create_certificate_screen.dart     -- stepper host
    widgets/
      cert_type_selector.dart            -- 3-tile type picker
      cert_template_picker.dart          -- filtered template list
      cert_test_grid.dart                -- section-grouped test items grid
      cert_signature_step.dart           -- tech + optional customer signature
```

## Horse API (stubs for now)

- `GET /certificates/templates?type=<1|2|3>` — returns `TestTemplateName` rows
- `GET /certificates/templates/:id/items` — returns `TestTemplate` rows for template
- `POST /certificates` — creates `TestCertificate` + `TestOutput` rows server-side

## Sync

Template sync added to `SyncNotifier.triggerSync()` alongside asset sync.
Issued certificates added to `change_log` with operation `push_certificate` — pushed on next sync.
