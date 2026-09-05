# Stat Trac Technical — Project Memory

> ## ⚠️ ARCHITECTURE CHANGED — 2026-09-05
>
> **The Delphi Horse REST API is retired. The backend is now a Go application
> with PowerSync for offline sync, over plain PostgreSQL. Supabase was trialled
> and removed on the same day — it is not a sync engine. Do not reintroduce it.**
>
> The authoritative backend design lives in the **Go repository**, not here:
> `C:\Delphi\GitHub_Stat_Trac_Go\docs\sync-design.md`
>
> **Delphi, UniGUI and Horse — the applications — are retired. The `Stat_Trac`
> database is not.** The existing Stat Trac schema (84 PascalCase tables)
> continues; Go replaces the application layer on top of it. There is no
> greenfield schema and no legacy-vs-new split, so no mirror job or write-back
> outbox is needed.
>
> The Go repository owns that schema (18 migrations), database-per-company
> tenancy (`Stat_Trac` for local testing and Windows production; `safeline` and
> `demo` on the VPS), sync rules, token issuance and PowerSync deployment.
> **This repository owns the Flutter app only.**
>
> **Start here next session:** `docs/STATE-2026-09-05.md` — what works, what is
> next, and the four decisions waiting on the user.
>
> This app's migration design: `docs/superpowers/specs/2026-09-05-powersync-migration-design.md`
> Contract with the Go side: `docs/sync-client-handover.md`
>
> Sections below still describing the Horse API are marked SUPERSEDED and kept
> for historical reference. Anything not so marked (theme, module inventory,
> business rules other than BR-7 and BR-10, Flutter conventions) remains current.

## ⚠️ MANDATORY — Do This Before Anything Else

**Invoke the superpowers skill at the very start of every session, before any other action:**

```
Skill("superpowers:using-superpowers")
```

This is non-negotiable. Do not read files, ask questions, or take any action until this skill has been invoked.

## IMPORTANT — Read This First

**At the start of every session, read the Nextcloud documentation files before doing anything else.** They are the authoritative reference for architecture, production database schema, Horse API endpoints, and all key decisions. CLAUDE.md is a quick-reference memory only — the full detail lives in Nextcloud.

### Nextcloud Documentation (always read at session start)

Location: `C:\Users\HomePC\Nextcloud\Stat Trac\Mobile App develepment\Stat_Trac_Technical_mobile\`

| File | Read when... |
|---|---|
| `1-Architecture-Overview.md` | Every session — system diagram, data flow, environments (updated 2026-09-05 for PowerSync) |
| `2-Production-Database.md` | Touching any Horse API or database work |
| `3-Horse-API.md` | ⚠️ SUPERSEDED — Horse retired 2026-09-05. Backend design is now in the Go repo. |
| `4-Flutter-App.md` | Touching Flutter code, auth, SQLite |
| `5-Decisions-Log.md` | Before making any architectural decision |
| `6-Security.md` | Before any auth, storage, network, or pre-production work |

**Update these files** whenever a significant decision is made, a new table is mapped, or an endpoint changes. They are synced to Nextcloud automatically via the desktop client.

### Superpowers Plans

Implementation plans live in `docs/superpowers/plans/`. Check this folder at session start — any open plan should be executed using the `superpowers:executing-plans` skill before starting new work.

| Plan | Status |
|---|---|
| `2026-06-01-sync-certificates-from-master-db.md` | ✅ Complete — implemented 2026-06-02 (plus Option B deletion detection, cert_name backfill, pagination) |
| `2026-06-02-cert-sync-option-b-display-pagination.md` | ✅ Complete — Option B pull, cert_name backfill, pagination, display fixes, security doc |
| `2026-06-03-cert-details-step.md` | ✅ Complete — CertDetailsStep integrated into certificate creation wizard |
| `2026-06-03-certificate-pdf-design.md` | ✅ Complete — FastReport PDF generation working for all cert IDs; View PDF + Email buttons in cert detail screen |
| `2026-06-05-pm-task-equipment-picker.md` | ✅ Complete — PM task selector in cert wizard; equipment type + "Next Cal" + EXPIRED badge in picker; `asset_pm_tasks` sync; DB v12 |
| `2026-09-05-powersync-schema-sync-rules.md` | ⛔ SUPERSEDED before execution — written against an assumed greenfield schema that does not exist. Do not run. |

## What This Is

Android field service technician app for Proteus Medical Technologies. Technicians execute PM, CM, inspections, installations and decommissioning work against medical equipment tracked in the Stat Trac CMMS. All master data (assets, accounts, contacts, PM templates, certificate templates) comes from the master Stat Trac PostgreSQL database (`Stat_Trac`) via a Delphi Horse REST API.

This is a **standalone app** — it does NOT share code or packages with Stat Trac Mobile (Sales).

## Specification

The full technical specification lives at `docs/Stat_Trac_Technical_Specification_v1.3.docx`. Reference it section-by-section — do NOT try to load the entire spec in one pass.

Key sections:
- §3 — Core modules and features (11 modules)
- §5 — Database schema (all tables and columns)
- §6 — API endpoints (Horse REST)
- §8 — Offline-first sync architecture
- §12 — Phased delivery plan

## Tech Stack

- **Frontend:** Flutter/Dart, Android-first (min API 28), tablet-optimised
- **State management:** Riverpod 3 with code-generated providers (`riverpod_annotation ^4`, `riverpod_generator ^4`)
- **Connectivity:** `connectivity_plus ^6` — used in sync notifier to skip sync when offline
- **Local database:** SQLite via sqflite (offline-first); SQLCipher encryption to be wired once Android Keystore key derivation is implemented — swap `openDatabase` for `sqflite_sqlcipher` in `database_helper.dart`
- **Backend API:** Go application (repo: `C:\Delphi\GitHub_Stat_Trac_Go`), device-token auth + JWKS
- **Offline sync:** PowerSync (`journeyapps/powersync-service:1.24.0`), self-hosted against plain Postgres
- **Server database:** PostgreSQL 17.11, plain (no Supabase), `wal_level=logical`, database-per-company
- **Hosting:** Secure on-premise Windows server in South Africa (POPIA data residency)
- **Notifications:** Firebase Cloud Messaging
- **PDF generation:** SUPERSEDED — FastReport VCL retires with Delphi. Replacement owned by the Go repository; this app consumes the result.
- **Barcode scanning:** mobile_scanner
- **Signatures:** signature package (vector PNG)
- **Geolocation:** geolocator, google_maps_flutter
- **Crash reporting:** Firebase Crashlytics + Sentry

## Architecture Rules

### Offline-first — this is non-negotiable
- SQLite is the primary data store. The UI always reads from local. Never block on network.
- All mutations write to local tables AND append a change-log entry.
- Sync worker replays the change log against the Horse API on connectivity events, foreground resume, and a 5-minute schedule.
- Binary artefacts (photos, signatures) queue separately with exponential backoff.
- PDFs (job cards, PM certificates, service certificates) are generated server-side by FastReport after sync. The app downloads and caches the resulting PDF for offline viewing.

### Clean Architecture
```
lib/
  core/                    # App-wide: theme, constants, errors, extensions
    config/
      app_config.dart      # baseUrl placeholder — set to real server before first deploy
  features/
    auth/
      data/                # Repositories, data sources, DTOs
      domain/              # Entities, repository interfaces, use cases
      presentation/        # Screens, widgets, Riverpod providers
    dashboard/
    work_orders/
    preventive_maintenance/
    assets/
    service_reports/
    parts/
    certification/
    documents/
    time_travel_expenses/
    notifications/
  sync/                    # Sync engine, change log, conflict resolution
  database/                # SQLite schema, migrations, DAOs
  api/                     # Horse API client, interceptors, JWT handling
```

### Naming Conventions
- Files: `snake_case.dart`
- Classes: `PascalCase`
- Providers: `camelCaseProvider` (e.g. `workOrderListProvider`)
- Database tables: `snake_case` matching the PostgreSQL schema in §5
- API endpoints: match §6 exactly

### State Management
- One provider file per feature screen or logical unit
- Use `AsyncNotifier` for data that loads from repository
- Use `Notifier` for UI-only state
- Providers are feature-scoped — never import a provider from another feature; extract shared logic to `core/` or `domain/`

### Repository Pattern
- Every data access goes through a repository interface in `domain/`
- Implementation in `data/` decides local vs remote
- Tests swap implementations freely

## Work Order Lifecycle States

```
Created → Assigned → Accepted → En route → On-site → In progress
  ↓                                                      ↓
  Cancelled    Rejected → (back to Assigned)    Paused / Awaiting parts
                                                         ↓
                                              Completed → Reviewed → Closed
                                                  ↑           ↓
                                                  └── Reopened ┘
```

For technician-created ad-hoc CMs: Created → In progress (skips Assigned/Accepted/En route/On-site).

## Asset Rules

- Assets are **master data** — read-only, sourced from the Stat Trac PostgreSQL DB via Horse API sync.
- The field app cannot create real assets. Asset registration is a back-office function.
- ~~**Provisional assets**~~ — **REMOVED 2026-09-05 by the user: technicians CANNOT create assets. Registration is the office admin's, full stop.** This rule previously said a technician could capture minimum details in the field and push them to an admin review queue. It was wrong, and it was implemented across 13 files before anyone questioned it. The code is still present and is dead; `is_provisional` is never set by anything the user sanctions. Assets are read-only from the device with **no exception**.
- The asset picker always shows the local asset list (synced from master + any provisional records). If the list is empty, an empty-state screen prompts the user to sync. There is no free-text asset ID entry.
- `is_provisional` records are visually flagged in the asset picker and WO detail so the tech and admin are aware registration is pending.

## Key Business Rules

1. Every state transition writes an immutable audit row with actor, timestamp, GPS fix and device ID.
2. Parts consumption deducts van stock locally and reconciles server-side on sync.
3. Serial-number capture is mandatory for warranty-tracked parts.
4. PM checklist fails auto-raise a linked CM work order with failure evidence pre-populated.
5. Next PM due date = completion date + frequency (not scheduled date + frequency).
6. Certificate templates are versioned — in-flight certificates complete on the version they started on.
7. Job card and certificate PDFs are generated SERVER-SIDE, NOT on-device. (SUPERSEDED in detail: FastReport VCL retires with Delphi; the replacement renderer is owned by the Go repository. The principle — server renders, app downloads and caches — is unchanged.)
8. P1 WO assignments and assistance requests always push regardless of quiet hours.
9. Technician-created ad-hoc CMs do NOT require dispatcher approval before work begins.
10. **Conflict resolution (REVISED 2026-09-05): a conflict notifies the person and leaves the record open.** Not last-write-wins, not a silent merge. When a device uploads a change to a row that has moved underneath it, the upload is refused, the local change stays queued, and the person is told. A test certificate is evidence — two technicians disagreeing about one is a question for a human, not a timestamp comparison. Detection is optimistic concurrency on existing `UpdatedAt` columns. This requires a "this record changed while you were away" screen that does not yet exist; that screen is part of the work.
11. Dashboard top-right corner displays "Last synced: [date] [time]" in green text, updated after every successful sync cycle. ✅ Implemented.

## Database

- Local: SQLite (sqflite); SQLCipher encryption pending key-derivation implementation
- All table definitions are in §5 of the spec
- Existing master tables consumed read-only: accounts, contacts, assets, asset_usage
- All other tables (work_orders, pm_*, parts_*, certificates_*, etc.) are read-write
- Migration runner: `lib/database/database_helper.dart` — add new `migration_00N_*.dart` files and register in `_onUpgrade`
- **Current DB version: 15** — tables below
- `assets` table includes `is_provisional INTEGER NOT NULL DEFAULT 0` — provisional records created in the field pending admin registration in master DB

| Migration | DB version | Tables / changes |
|---|---|---|
| 001 | 1 | `work_orders`, `work_order_status_history`, `work_order_photos`, `work_order_signatures`, `change_log` |
| 002 | 2 | `assets` (original — superseded by 003) |
| 003 | 3 | `assets` rebuilt with correct schema (`asset_id UNIQUE`, barcode/hospital indexes, provisional rescue) |
| 004 | 4 | `sync_error_log` |
| 005 → v6 | 6 | `test_template_names`, `test_template_items`, `test_certificates`, `test_outputs` |
| 007 → v7 | 7 | `test_template_items` — adds `actual_value_template TEXT` column (maps `TestTempActualValue`; value `'-'` means no actual reading required, exposed via `noActualRequired` getter on `TestTemplateItem`) |
| 008 → v8 | 8 | `test_certificates` — adds `patient_safe INTEGER` (compliance status) |
| 009 → v9 | 9 | `sync_metadata` — key/value store |
| 010 → v10 | 10 | `test_certificates` — adds `cert_name TEXT` (template cert name stored at pull time) |
| 011 → v11 | 11 | `test_cert_details` step tables (CertDetailsStep wizard) |
| 012 → v12 | 12 | NEW `asset_pm_tasks` (id, pm_task_id UNIQUE, asset_id, description, schedule_date, active); ALTER `test_certificates` + `pm_task_description TEXT`; ALTER `test_equipment_assets` + `equipment_type TEXT`; ALTER `test_cert_equipment` + `equipment_type TEXT` |
| 013 → v13 | 13 | `asset_pm_tasks` — adds `interval TEXT`, `interval_type TEXT` |
| 014 → v14 | 14 | `test_certificates` — adds `service_id INTEGER` (FK to AssetPmTask.pm_task_id; maps `TestServiceID`) |
| 015 → v15 | 15 | `test_certificates` — adds `test_type INTEGER` (1 = client signature required, NULL otherwise; maps `TestType`) |

## API — SUPERSEDED (Horse REST, retired 2026-09-05)

> Kept for reference while the PowerSync migration is planned. The Go API's
> contract lives in the Go repository. Reads no longer travel over REST at all —
> PowerSync streams Postgres into the device's local SQLite.

- Base URL configured in `lib/core/config/app_config.dart`
- **Local dev:** `http://10.0.2.2:9000` (Android emulator → host machine)
- **Production:** update `AppConfig.baseUrl` to the real server IP/hostname before deploy
- All endpoints require JWT Bearer token in Authorization header
- Sync uses since-cursor pagination (`?since=<iso_timestamp>`)
- Binary uploads use multipart/form-data
- Full endpoint list in §6 of the spec

## Horse API Contract — SUPERSEDED (retired 2026-09-05)

| Method | Path | Request | Response |
|---|---|---|---|
| POST | `/auth/login` | `{ username, password, db, app_version, device_os }` | `{ token: { access_token, refresh_token, expires_at }, user: { id, name, email, role, technician_code } }` |
| POST | `/auth/refresh` | `{ refresh_token }` | `{ access_token, refresh_token, expires_at }` |
| POST | `/auth/logout` | — | 204 |
| GET | `/assets?page=N&page_size=N` | — | `{ data: [...] }` paginated asset list |
| POST | `/sync/log` | `{ operation, entity, row_count, status, message }` | 204 |
| GET | `/certificates/templates?type=<1\|2\|3>` | — | `{ data: [...] }` template headers |
| GET | `/certificates/templates/:id/items` | — | `{ data: [...] }` test items for template |
| POST | `/certificates` | cert + outputs payload | `{ id: <TestCertificateID> }` |
| GET | `/certificates/ids?technician_id=<id>` | — | `{ ids: [...] }` all TestCertificateID values for technician (Option B deletion detection) |
| GET | `/certificates/history?technician_id=<id>&after_id=<cursor>&page_size=<n>` | — | `{ data: [...] }` certs + embedded outputs, paginated (default 100, max 500); loop advancing after_id until page < page_size |
| GET | `/certificates/:id/pdf` | — | `{ pdf_b64: "..." }` base64-encoded PDF; Horse API proxies to Stat Trac `GET /cert/pdf/:id?db=<db>` which generates via FastReport |
| GET | `/assets/pm-tasks` | — | `{ data: [{ pm_task_id, asset_id, description, schedule_date, active }] }` — full list of active PM tasks (full-pull, no cursor) |
| POST | `/certificates/:id/email` | `{ to: "email@..." }` | 204 — server-side SMTP send (not yet implemented in Horse API) |

## Testing

- Unit tests on domain layer and repositories (target 80%+ coverage)
- Widget tests on key screens (dashboard, WO detail, PM checklist)
- Integration tests on the offline → sync → reconcile path
- Run: `flutter test`
- Analyse: `flutter analyze`
- Format: `dart format .`

## Build & Deploy

- CI: GitHub Actions — format/analyse/test on every PR
- Signed APK on merge to main → Play Console internal track
- Promotion to closed/production via release-gate approvals
- Firebase App Distribution for ad-hoc testing builds

## POPIA Compliance

- All data hosted on a secure on-premise Windows server in South Africa
- Personal information fields (ID numbers, cellphone numbers, emails) encrypted at rest
- Consent records for automated communications
- Never log personal information to Crashlytics or Sentry

## Development Phases

Work in this order. Each phase builds on the previous.

1. **Phase 1 — Core WO + Offline:** Auth ✅, Dashboard ✅, Work Orders (CM) 🔄, Assets (read), Service Reports, Parts consumption, Sync engine 🔄, Signatures, Server-side job card PDF (FastReport), Notifications (core push + in-app).
2. **Phase 2 — PM + Certification:** PM templates/execution/certificates, Service Certification, Documents, Time/travel/expenses, Notification preferences.
3. **Phase 3 — QA + Decommission:** QA review loop, Decommissioning, Certificate template depth, Van stock replenishment, Certificate expiry notifications.
4. **Phase 4 — Polish + Integrations:** Route optimisation, Accounting export, Manufacturer parts catalogues, Reporting, Email notifications.

## What Has Been Built

### Auth module — complete scaffold + DB name first-login field ✅
- `lib/features/auth/domain/entities/` — `User`, `AuthToken`, `UserRole`
- `lib/features/auth/domain/repositories/auth_repository.dart` — abstract interface; `login()` accepts `(username, password, dbName)`
- `lib/features/auth/data/models/` — `UserModel`, `AuthTokenModel` (JSON DTOs)
- `lib/features/auth/data/datasources/auth_remote_data_source.dart` — Dio (login/logout/refresh); `login()` sends `db` from `dbName` param (not hardcoded)
- `lib/features/auth/data/datasources/auth_local_data_source.dart` — FlutterSecureStorage: token + user + db_name (`saveDbName` / `readDbName` / `clearDbName`)
- `lib/features/auth/data/repositories/auth_repository_impl.dart` — saves `db_name` on login; clears `db_name` on logout
- `lib/features/auth/presentation/providers/auth_providers.dart` + `.g.dart` — `@riverpod` infra + `AuthNotifier`; `login()` accepts `dbName`
- `lib/features/auth/presentation/providers/auth_state.dart` — sealed `AuthInitial / AuthAuthenticated / AuthUnauthenticated`
- `lib/features/auth/presentation/screens/login_screen.dart` — DB Name field shown on first login only (hidden once `db_name` stored); username/password form; error banner; loading state

### Dashboard — complete ✅
- `lib/features/dashboard/presentation/screens/dashboard_screen.dart` — `WidgetsBindingObserver` + `addPostFrameCallback` sync triggers; AppBar with `_SyncStatusLabel` (dual-ring progress circle / green tick+timestamp / red error), `Badge` on sync icon (count of unresolved errors, tappable → `_SyncErrorSheet`), logout; single-screen layout (no tabs)
- `lib/features/dashboard/presentation/providers/dashboard_providers.dart` — `lastSyncedAtProvider`, `DashboardStats`, `dashboardStatsProvider` (live SQL query from WO table)
- **Top row** — two side-by-side `_TaskCountCard` tiles: "Pending Work Orders" (brandTeal) and "Pending PM Work Orders" (dark green)
- **Donut chart** — `fl_chart` `PieChart`, Overdue (brandError) / Pending (amber) / WIP (brandTeal) sections with legend + percentages; grey ring when total = 0
- **KPI row** — three `_KpiTile` cards: Overdue, Pending, WIP counts in matching colours
- **Quick actions grid** — 5-tile 2-column grid (`childAspectRatio: 1.8`), all brandTeal: Worklist (→ `WorkOrderListScreen`), Create Work Order (→ `CreateWorkOrderScreen`), Create PM Order (coming soon), Create Certificate (→ `CreateCertificateScreen`), View Certificates (→ `CertificateListScreen`)
- **Bottom `NavigationBar`** — Home, Assets, Inventory, Meter; Assets tab → `AssetListScreen`; others show "coming soon"

### Sync engine ✅
- `lib/sync/sync_state.dart` — sealed `SyncIdle / SyncInProgress(progress, message) / SyncComplete / SyncError`; `SyncInProgress` carries `progress` (0.0–1.0) and a step label string
- `lib/sync/sync_notifier.dart` + `.g.dart` — `SyncNotifier.triggerSync()` sequential pipeline:
  1. Connectivity check (skip if offline)
  2. Purge old resolved errors + deduplicate unresolved rows (1 per operation)
  3. Asset sync with page-level `onPage` callback → updates progress 5%–60%
  4. POST `/sync/log` (success and failures)
  5. Template sync (cert templates types 1/2/3 + their items) → 65%
  6. Push pending certificates → 80%
  7. Pull certificates from server (cursor = MAX server_id) → 90%
  8. `SyncComplete`
- `unresolvedSyncErrorCountProvider` — count of `resolved = 0` rows, invalidated at start + end of each cycle
- `unresolvedSyncErrorsProvider` — list of `SyncErrorEntry` objects for the error detail sheet
- `lib/sync/sync_error_log_data_source.dart` — `SyncErrorLogDataSourceImpl`: `logError` (delete-before-insert per operation), `markResolved`, `unresolvedCount`, `getUnresolvedErrors`, `purgeOldResolved` (also deduplicates unresolved rows)
- `lib/sync/sync_remote_data_source.dart` — `postSyncLog(operation, entity, rowCount, status, message)`: posts **both successes and failures** to server `AppSyncLog`
- `lib/sync/sync_service.dart` — abstract `SyncService` interface — WO sync pending
- `lib/sync/change_log_entry.dart` — `ChangeLogEntry` domain model + `ChangeOperation` enum

**Sync progress UI (dashboard AppBar):**
- `SyncInProgress` → dual-ring circle: outer deterministic ring fills to `progress`%, inner thin ring always spins; shows % text; tooltip shows step label
- `SyncComplete` → green tick + `dd MMM HH:mm` timestamp
- `SyncError` → red error icon + "Sync failed · timestamp"
- Badge on sync icon → count of unresolved errors; **tap opens `_SyncErrorSheet`** (human-readable operation labels, error message, time ago, Retry button); tapping sync icon with no errors triggers sync directly

### Database foundation
- `lib/database/database_helper.dart` — singleton, migration runner; **current DB version: 10**; `_onUpgrade` replays missing migrations for stale installs; WAL is default on API 28+ so no PRAGMA needed
- `lib/database/migrations/migration_001_work_orders.dart` — §5.1 tables + `change_log`
- `lib/database/migrations/migration_002_assets.dart` — original `assets` table (superseded by migration_003)
- `lib/database/migrations/migration_003_assets_v2.dart` — rebuilds `assets` with correct schema (`asset_id UNIQUE`, barcode/hospital indexes, provisional rescue)
- `lib/database/migrations/migration_004_sync_error_log.dart` — `sync_error_log` table

### Assets — domain + data + picker widget (read-only so far)
- `lib/features/assets/domain/entities/asset.dart` — `Asset` entity; `isProvisional`, `displayName` getter
- `lib/features/assets/data/models/asset_model.dart` — `AssetModel extends Asset` with `fromMap`/`toMap`
- `lib/features/assets/data/datasources/asset_local_data_source.dart` — interface + impl; `upsertAll`, `getAssets`, `searchAssets`, `getAssetById`, `getAssetByBarcode`, `getHospitals`, `getStats`, `createProvisional`, `getByAssetIds(ids)` (pre-upsert fetch for change detection), `deleteNotIn(serverIds)` (chunks of 900)
- `lib/features/assets/presentation/widgets/asset_picker_dialog.dart` — **two-step picker**: page 1 selects hospital (account), page 2 shows filtered equipment with search; scoped Riverpod providers with `dependencies:` declarations; provisional asset bottom-sheet form; empty-state sync prompt

**Provisional asset rules** (add to DB migration notes):
- Assets table includes `is_provisional INTEGER NOT NULL DEFAULT 0`
- When a tech creates a provisional asset: `is_provisional = 1`, `server_id = NULL`
- On sync, the server registers the asset and returns a `server_id`; app patches `is_provisional = 0` and `server_id`
- ~~Provisional asset badge~~ — dead, see the removed rule above. Nothing sets `is_provisional` any more.

### Work Orders — domain + data + list + detail + create screens
- `lib/features/work_orders/domain/entities/work_order_enums.dart` — `WoType`, `WoPriority`, `WoStatus`, `WoOrigin`, `WoOutcome`, `BillingFlag`, `PhotoStage`, `SignerRole`
- `lib/features/work_orders/domain/entities/work_order.dart` — `WorkOrder`, `WorkOrderStatusHistory`
- `lib/features/work_orders/domain/repositories/work_order_repository.dart`
- `lib/features/work_orders/data/models/work_order_model.dart` — SQLite map ↔ entity DTO
- `lib/features/work_orders/data/datasources/wo_local_data_source.dart` — sqflite CRUD, today's query, `getStatusHistory(workOrderId)`, change-log writes
- `lib/features/work_orders/data/datasources/wo_remote_data_source.dart` — Dio stubs for all §6.1 endpoints
- `lib/features/work_orders/data/repositories/work_order_repository_impl.dart` — wires local + remote, writes status history + change log on every mutation
- `lib/features/work_orders/presentation/providers/work_order_providers.dart` + `.g.dart` — `TodaysWorkOrders`, `workOrderDetailProvider(id)`, `workOrderStatusHistoryProvider(id)`, `WorkOrderActions` notifier
- `lib/features/work_orders/presentation/screens/work_order_list_screen.dart` — priority-grouped list, SLA countdown, type/status chips; taps navigate to detail
- `lib/features/work_orders/presentation/screens/work_order_detail_screen.dart` — header card (type/priority/WO#/asset/SLA), description, timing, resolution narrative, status history timeline, `_TransitionBar` with contextual buttons per status
- `lib/features/work_orders/presentation/screens/create_work_order_screen.dart` — "New Work Order"; 6-type grid selector (CM/PM/INS/INST/DEC/UPG) with icons; P1–P4 priority chips; two-step asset picker; description field; type-aware info banner; "Create & Start Work" (CM) or "Submit Work Order" (others)

**WO creation business rule** (§BR-9):
- CM created by technician: `initialStatus = WoStatus.inProgress`, `startedAt = now` (no dispatcher approval)
- All other types: `initialStatus = WoStatus.created` (goes to dispatcher queue)

### Certification module ✅

**SQLite tables (migration_005):** `test_template_names`, `test_template_items`, `test_certificates`, `test_outputs`

**Domain:** `lib/features/certification/domain/` — `TestTemplateName`, `TestTemplateItem`, `TestCertificate`, `TestOutput` entities; `CertificateRepository` interface. `TestTemplateItem` has `actualValueTemplate` (maps `TestTempActualValue`) and `noActualRequired` getter — returns `true` when the server value is `'-'`, hiding the Actual field in the test grid.

**Data layer:**
- `cert_local_data_source.dart` — template CRUD, cert save/load, `getMaxServerId()`, `insertCertificateFromServer()`, `insertOutputsForCert()`, `getSyncedServerIds()` (returns all non-null server_ids for Option B diff), `deleteCertificateByServerId()`
- `cert_remote_data_source.dart` — `fetchTemplates(type)`, `fetchTemplateItems(id)`, `pushCertificate(payload)`, `fetchCertificateHistory(technicianId, afterId, {pageSize=100})`, `fetchCertificateIds(technicianId)`
- `certificate_repository_impl.dart` — `syncTemplatesFromRemote()`, `pushPendingCertificates()`, `pullCertificatesFromRemote(technicianId)` → returns `({List<int> deletedIds, int added})`
- **Option B pull logic:** fetch all server IDs → diff → delete orphans → paginated history pull (100/page) advancing cursor per page
- `hasCertsWithNullCertName()` triggers cursor=0 (full re-pull) for one-time cert_name backfill
- `insertCertificateFromServer` updates `cert_name` for existing certs missing it; skips re-inserting cert + outputs
- `pullCertificatesFromRemote` success logged to `AppSyncLog` with deleted IDs and added count
- **`cert_name` column** (`test_certificates`) — resolved template cert name from Horse API; avoids broken JOIN on historical certs where `TestType=0`

**Presentation:**
- `create_certificate_screen.dart` — multi-step wizard: type → asset → template → test items → signature
- `certificate_list_screen.dart` — all certs newest first, type chip, pending badge; reads from local SQLite
- `certificate_detail_screen.dart` — read-only cert header + grouped test results by `description_id`; AppBar has **View PDF** and **Email** action buttons (enabled only when `cert.serverId != null`). View PDF downloads via `GET /certificates/:id/pdf`, caches to `{cacheDir}/certs/cert_{id}.pdf`, opens with `open_file`. Email opens a dialog for recipient address then calls `POST /certificates/:id/email`.
- `certificate_providers.dart` — `certificateListProvider`, `certificateSummaryProvider`, `certOutputsProvider`, `templatesByTypeProvider`, `templateItemsProvider`

**Android FileProvider** (required by `open_file` to share internal cache files with PDF viewer apps):
- `android/app/src/main/AndroidManifest.xml` — `<provider>` declared with authority `${applicationId}.file_provider`
- `android/app/src/main/res/xml/file_paths.xml` — exposes `cache-path` to FileProvider

**Horse API PostgreSQL tables:**
- `"TestTemplateName"` — 62 templates; key: `TestTemplateNameID`, `TestTemplateType` (1=Test/OVP, 2=QA, 3=Commission)
- `"TestTemplate"` — 1773 items; FK: `TestTempCertificateNameID`
- `"TestCertificate"` — completed certs; key: `TestCertificateID`, `TestTechID`, `TestCertType` (template FK), `TestType` (cert category)
- `"TestOutput"` — test result rows; FK: `TestOutputCertID`; notes column is `"TestNote"` (singular) — **NOT** `"TestNotes"` (a separate column that exists for a different purpose)

### Infrastructure
- `lib/api/auth_interceptor.dart` — JWT injection, auto-refresh on 401
- `lib/api/dio_client.dart` — Dio factory for non-auth feature data sources
- `lib/core/config/app_config.dart` — base URL + timeout constants
- `lib/core/theme/app_theme.dart` — brand colour constants + full Material3 `ThemeData`
- `lib/main.dart` — `WidgetsFlutterBinding.ensureInitialized()`, `ProviderScope`, `_AuthGate`, references `appTheme`
- `assets/images/logo.png` — company logo (registered in `pubspec.yaml`)
- `android/app/src/main/AndroidManifest.xml` — `USE_BIOMETRIC` + `USE_FINGERPRINT` permissions
- `android/app/build.gradle.kts` — `minSdk = 28`

### Theme
Brand colour constants in `lib/core/theme/app_theme.dart`:

| Constant | Hex | Role |
|---|---|---|
| `brandTeal` | `#1B7EA6` | Primary — buttons, icons, active states |
| `brandDark` | `#0D2B3E` | AppBar background, primary text |
| `brandGrey` | `#8A9BAE` | Secondary text, icons, borders |
| `brandBackground` | `#F5F7FA` | Scaffold background |
| `brandError` | `#C62828` | Errors, destructive actions |

Full `ThemeData` overrides in `app_theme.dart`:
- `filledButtonTheme` — brandTeal bg, white text, 10px radius, 48px min height
- `elevatedButtonTheme` — brandTeal bg, white text, 10px radius, 48px min height
- `outlinedButtonTheme` — brandTeal border + text, 10px radius, 48px min height
- `floatingActionButtonTheme` — brandTeal bg, white fg
- `appBarTheme` — brandDark bg, white fg, no elevation
- `iconTheme` — brandGrey (general/content icons)
- `inputDecorationTheme` — 8px rounded, brandGrey labels/prefix icons, brandTeal focused border
- `cardTheme` — white bg, 12px radius, `#DDE3EA` border, no elevation
- `textTheme` — headlineSmall, titleLarge, titleMedium, titleSmall, bodyLarge, bodyMedium, bodySmall, labelLarge

Dashboard module card colours (per-tile, hardcoded in `_ModuleGrid`):
- Work Orders — `#1B7EA6` (brandTeal)
- Assets — `#2E7D32` (dark green)
- Service Reports — `#E65100` (deep orange)
- Parts — `#6A1B9A` (deep purple)
- Certification — `#00838F` (cyan-teal)
- Notifications — `#F57F17` (amber)

Each card uses: background = color.withAlpha(20), border = color.withAlpha(60), icon + label = solid color.

Supporting inline colours (not yet named constants):
- `#DDE3EA` — card/input borders, dividers
- `#E65100` — Fair condition, Due Soon, manual entry badge
- `#2E7D32` — Good condition, Up to Date, physically verified
- `#1B5E20` — Excellent condition
- `#B71C1C` — Poor condition
- `#7B0000` — Critical condition
- `#FFB300` — Manual entry icon/text
- `#FFF8E1` — Manual entry field background
- `#FF5252` — Overdue maintenance

## Horse API Server — SUPERSEDED (retired 2026-09-05)

> The Delphi Horse server is no longer used. Retained below only because the
> PostgreSQL table and column reference (`Repair`, `Admin`, integer enum
> mappings) is still accurate and still needed for data mapping.

Local dev server lives at `C:\Delphi\StatTracTechAPI\`. Built with RAD Studio 12, Delphi Horse framework, UniDAC for PostgreSQL.

### Setup
- Install Boss: `C:\Tools\Boss\boss.exe`
- Packages: `horse`, `horse-jwt`, `horse-cors`, `jhonson` (all in `modules\`)
- PostgreSQL 12 local, database: `stat_trac`, user: `postgres`
- Run: open `StatTracTechAPI.dproj` in RAD Studio → F9
- Listens on port 9000

### Source files
- `src\Database.Connection.pas` — UniDAC PostgreSQL connection factory
- `src\Auth.Routes.pas` — POST `/auth/login`, `/auth/refresh`, `/auth/logout`
- `src\WorkOrders.Routes.pas` — GET/POST `/workorders`, POST `/workorders/:id/transition`
- `src\Assets.Routes.pas` — GET `/assets?since=`
- `src\Certificates.Routes.pas` — GET `/certificates/templates`, GET `/certificates/templates/:id/items`, POST `/certificates`, GET `/certificates/history`
- `src\PDF.Routes.pas` — GET `/certificates/:id/pdf` (proxy to Stat Trac `/cert/pdf/:id?db=<db>`); JWT required
- `src\Sync.Routes.pas` — POST `/sync/log`
- `src\SyncLog.pas` — `WriteSyncLog` shared procedure
- `src\Contacts.Routes.pas`, `src\Facilities.Routes.pas`, `src\Issues.Routes.pas`, `src\Visits.Routes.pas` — supplementary endpoints

### Database tables (stat_trac)

All table and column names are PascalCase and must be double-quoted in SQL.

- `"Admin"` — user accounts. Key columns: `"UserID"` (PK), `"UserName"` (login username), `"UserPassword"` (plain-text), `"UserContactName"`, `"UserEmail"`, `"UserTechnician"` (1=tech, 2=customer, else=admin), `"UserActive"` (1=active). **No `users` table exists.**
- `"Asset"` — master asset records (read-only). Key columns: `"AssetID"` (PK), `"AssetEquipmentType"`, `"AssetManufacturer"`, `"AssetModel"`, `"AssetSerialNo"`, `"AssetBarcode"`, `"AssetHospital"`, `"AssetLocation"`, `"AssetCondition"`, `"AssetActive"` (int), `"AssetCondemned"` (int), `"AssetNextServiceDate"`, `"AssetUserDate"` (last-modified, used for since-cursor sync)
- `"Repair"` — work orders (**NOT** `work_orders`). Key columns: `"RepairTrackID"` (PK), `"RepairDate"` (date), `"RepairAssetID"` (FK → Asset), `"RepairFault"` (varchar 200, symptom), `"RepairNote"` (varchar 200, resolution), `"RepairCondition"` (varchar 200), `"RepairStatus"` (int), `"RepairType"` (int), `"RepairPriority"` (int), `"RepairTechID"` (int), `"RepairHospital"` (varchar 20), `"RepairLocation"` (varchar 30)
- `"RepairProgress"` — work order status history (**NOT** `work_order_status_history`). Key columns: `"ProgressID"` (PK), `"ProgessTrackID"` (FK → Repair — **note: DB typo, missing 'r'**), `"ProgressAssetID"`, `"ProgressDate"`, `"ProgressWorkDone"`, `"ProgressHrs"`, `"ProgressTech"`, `"ProgressStatus"` (int), `"ProgressTechID"`

**Integer mappings for `"Repair"` columns:**

`RepairStatus` → Flutter `WoStatus` string: 1=`created`, 2=`assigned`, 3=`completed`, 4=`in_progress`, 5=`awaiting_parts`, 6=`awaiting_parts`, 7=`closed`, 8=`cancelled`, 9=`reviewed`

`RepairType` → Flutter `WoType` string: 1=`CM`, 2=`PM`, 3=`INS`, 4=`INST`, 5=`CM`, 6=`DEC`, 7=`UPG`

`RepairPriority` → Flutter `WoPriority` string: 0=`P3` (default), 1=`P1` (High), 2=`P2` (Medium), 3=`P3` (Low)

### Users

Login authenticates against the `"Admin"` table (NOT a `users` table — that does not exist). Password is stored plain-text in `"Admin"."UserPassword"`. Active technicians (`UserTechnician = 1`, `UserActive = 1`):

| UserID | UserName | Name |
|---|---|---|
| 35 | fritz | Mauritz Britz |
| 39 | absorne | Absorne Mabena |
| 30 | deon | Deon Rossouw |
| 28 | 2 | Vaughn Sweeney |
| 16 | 1 | Chris Potgieter |

### JWT
- Algorithm: HS256, secret in `Auth.Routes.pas` const `JWT_SECRET`
- Access token: 60 min, Refresh token: 30 days
- **Change `JWT_SECRET` before production**

### Android network config
- `android/app/src/main/res/xml/network_security_config.xml` — allows cleartext HTTP to `10.0.2.2` (emulator only)
- Remove or restrict this config before production build

## Known TODOs (Phase 1)

### Sync engine (asset sync complete ✅ — WO sync pending)
- `work_order_repository_impl.dart` — implement `syncFromRemote()` with since-cursor pagination
- `sync_service.dart` — implement concrete `SyncServiceImpl` for work order push/pull once Horse API WO sync endpoints exist

### Auth
- `auth_providers.dart` — replace `_unknownUser` placeholder with real user from login response (already in `response.data['user']`)
- `auth_repository_impl.dart` — implement `getCurrentUser()` once `/auth/me` endpoint is in spec §6

### Work orders
- `work_order_repository_impl.dart` — inject real current user ID from auth state (currently hardcoded `0`)
- `wo_local_data_source.dart` — inject real device ID (currently hardcoded `'device'`)
- `work_order_repository_impl.dart` — implement `syncFromRemote()` with since-cursor

### Infrastructure
- `database_helper.dart` — swap `openDatabase` for `sqflite_sqlcipher` once Android Keystore key derivation is wired
- `app_theme.dart` — extract inline supporting colours (condition/maintenance/manual entry) into named constants if desired
- `dashboard_providers.dart` — PM Work Order count is hardcoded `0`; wire real query once PM tables exist (Phase 2)
- `android/build.gradle.kts` — remove `isar_flutter_libs` AGP 8.x namespace patch once `offline_sync_kit` upgrades past `isar_flutter_libs 3.1.0+1`

## Sync Error Logging ✅ — TO BE RETIRED

> PowerSync replaces this engine. `change_log`, `sync_error_log` and the
> hand-rolled push/pull pipeline are retired as part of the migration; the
> dashboard's sync status label and error sheet rebind to PowerSync's connection
> state and upload-queue depth. Documented below as the current (pre-migration)
> behaviour.

Every sync failure writes to **two places**:
1. **Device SQLite `sync_error_log`** — powers the badge count and `_SyncErrorSheet` in the app
2. **Server PostgreSQL `AppSyncLog`** — visible to admins in the back-office (via `POST /sync/log` with `status: 'error'`)

Rules:
- `logError` deletes the existing unresolved row for the same `operation` before inserting — always 1 row per operation, never accumulates
- `purgeOldResolved()` also deduplicates any legacy stale rows
- `markResolved(operation)` called on next successful sync of that operation
- Rows older than 30 days with `resolved = 1` are purged each sync cycle
- Never log personal information in `error_message` or `stack_trace`
- Operations tracked: `sync_assets`, `sync_templates`, `push_certificates`, `pull_certificates`

## Immediate Next Steps (revised 2026-09-05)

**The PowerSync migration reorders this.** Do not build new features on the Horse
API or extend the hand-rolled sync engine — both are being replaced.

1. Answer the open questions in `docs/superpowers/specs/2026-09-05-powersync-migration-design.md` §5 — chiefly client-generated identity for certificates and work orders created offline, and which tables this app syncs (an input the Go repository needs from here)
2. Plan the Flutter PowerSync migration, certification module first (completed certs are immutable, so the conflict path is exercised least while the mechanics are proved)
3. Build the "this record changed while you were away" conflict screen — required by the revised BR-10, no current equivalent
4. Then resume feature work: Service Reports, signatures on WO completion

Superseded by the above: implementing `syncFromRemote()` with since-cursor
pagination — that endpoint's architecture no longer exists.

## How to Prompt Me (Claude Code)

### CRITICAL: Always ask before doing anything.
Before writing code, creating files, or making any changes, describe what you plan to do and wait for confirmation. Never assume — always confirm.

### SQLite tables are built incrementally.
Only generate the SQLite CREATE TABLE statements for the module currently being worked on. Do NOT dump the entire §5 schema in one go. As each module is developed, add only the tables that module needs.

### Reference the spec by section number:

```
Read §3.3 from docs/Stat_Trac_Technical_Specification_v1.3.docx.
Implement the Work Orders data model, SQLite tables, and repository layer.
```

```
Read §5.1 from the spec. Generate the SQLite CREATE TABLE statements
for work_orders, work_order_status_history, work_order_photos, and
work_order_signatures.
```

```
Read §6.1 from the spec. Generate the Dart API client class for
work order endpoints using Dio.
```

Do NOT dump the entire spec in one prompt. Work module by module, phase by phase.

### build_runner
Run after adding any new `@riverpod` annotated file:
```
dart run build_runner build --delete-conflicting-outputs
```
The SDK version warning (`3.11.0 > analyzer 3.9.0`) is harmless — ignore it.

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **Stat_Trac-Technical-app** (841 symbols, 1588 relationships, 4 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> If any GitNexus tool warns the index is stale, run `npx gitnexus analyze` in terminal first.

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `gitnexus_impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `gitnexus_detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `gitnexus_query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `gitnexus_context({name: "symbolName"})`.

## Never Do

- NEVER edit a function, class, or method without first running `gitnexus_impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `gitnexus_rename` which understands the call graph.
- NEVER commit changes without running `gitnexus_detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/Stat_Trac-Technical-app/context` | Codebase overview, check index freshness |
| `gitnexus://repo/Stat_Trac-Technical-app/clusters` | All functional areas |
| `gitnexus://repo/Stat_Trac-Technical-app/processes` | All execution flows |
| `gitnexus://repo/Stat_Trac-Technical-app/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
