# Stat Trac Technical — Project Memory

## IMPORTANT — Read This First

**At the start of every session, read the Nextcloud documentation files before doing anything else.** They are the authoritative reference for architecture, production database schema, Horse API endpoints, and all key decisions. CLAUDE.md is a quick-reference memory only — the full detail lives in Nextcloud.

### Nextcloud Documentation (always read at session start)

Location: `C:\Users\HomePC\Nextcloud\Stat Trac\Mobile App develepment\Stat_Trac_Technical_mobile\`

| File | Read when... |
|---|---|
| `1-Architecture-Overview.md` | Every session — system diagram, data flow, environments |
| `2-Production-Database.md` | Touching any Horse API or database work |
| `3-Horse-API.md` | Touching Horse API source files |
| `4-Flutter-App.md` | Touching Flutter code, auth, SQLite |
| `5-Decisions-Log.md` | Before making any architectural decision |

**Update these files** whenever a significant decision is made, a new table is mapped, or an endpoint changes. They are synced to Nextcloud automatically via the desktop client.

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
- **Backend API:** Delphi Horse REST API, JWT auth
- **Server database:** PostgreSQL (master Stat Trac)
- **Hosting:** Secure on-premise Windows server in South Africa (POPIA data residency)
- **Notifications:** Firebase Cloud Messaging
- **PDF generation:** FastReport VCL on the Horse API server — NOT on-device. App receives generated PDFs from the server on sync.
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
- **Provisional assets** — if a technician needs to raise a callout against an asset that is not yet in the system and no admin is available, they may capture minimum details (serial number, equipment name, manufacturer, model, facility/department) directly in the app. This creates a local asset record flagged `is_provisional = true`. The WO is created against it immediately. On next sync, the provisional asset is pushed to the master DB and lands in an admin review queue for proper registration.
- The asset picker always shows the local asset list (synced from master + any provisional records). If the list is empty, an empty-state screen prompts the user to sync. There is no free-text asset ID entry.
- `is_provisional` records are visually flagged in the asset picker and WO detail so the tech and admin are aware registration is pending.

## Key Business Rules

1. Every state transition writes an immutable audit row with actor, timestamp, GPS fix and device ID.
2. Parts consumption deducts van stock locally and reconciles server-side on sync.
3. Serial-number capture is mandatory for warranty-tracked parts.
4. PM checklist fails auto-raise a linked CM work order with failure evidence pre-populated.
5. Next PM due date = completion date + frequency (not scheduled date + frequency).
6. Certificate templates are versioned — in-flight certificates complete on the version they started on.
7. Job card and certificate PDFs are generated SERVER-SIDE by FastReport VCL in the Horse API, NOT on-device. The app submits completion data on sync, the server renders the PDF from FastReport templates, and the app downloads the result. Facility contacts receive the PDF by email from the server.
8. P1 WO assignments and assistance requests always push regardless of quiet hours.
9. Technician-created ad-hoc CMs do NOT require dispatcher approval before work begins.
10. Conflict resolution: last-write-wins for free-text/status; server-wins for financial/audit fields.
11. Dashboard top-right corner displays "Last synced: [date] [time]" in green text, updated after every successful sync cycle. ✅ Implemented.

## Database

- Local: SQLite (sqflite); SQLCipher encryption pending key-derivation implementation
- All table definitions are in §5 of the spec
- Existing master tables consumed read-only: accounts, contacts, assets, asset_usage
- All other tables (work_orders, pm_*, parts_*, certificates_*, etc.) are read-write
- Migration runner: `lib/database/database_helper.dart` — add new `migration_00N_*.dart` files and register in `_onUpgrade`
- **Current DB version: 3** — tables: `work_orders`, `work_order_status_history`, `work_order_photos`, `work_order_signatures`, `change_log`, `assets`
- `assets` table includes `is_provisional INTEGER NOT NULL DEFAULT 0` — provisional records created in the field pending admin registration in master DB

## API

- Base URL configured in `lib/core/config/app_config.dart`
- **Local dev:** `http://10.0.2.2:9000` (Android emulator → host machine)
- **Production:** update `AppConfig.baseUrl` to the real server IP/hostname before deploy
- All endpoints require JWT Bearer token in Authorization header
- Sync uses since-cursor pagination (`?since=<iso_timestamp>`)
- Binary uploads use multipart/form-data
- Full endpoint list in §6 of the spec

## Horse API Contract (auth endpoints — agreed shape)

| Method | Path | Request | Response |
|---|---|---|---|
| POST | `/auth/login` | `{ username, password }` | `{ token: { access_token, refresh_token, expires_at }, user: { id, name, email, role, technician_code } }` |
| POST | `/auth/refresh` | `{ refresh_token }` | `{ access_token, refresh_token, expires_at }` |
| POST | `/auth/logout` | — | — |

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
- `lib/features/dashboard/presentation/screens/dashboard_screen.dart` — `WidgetsBindingObserver` + `addPostFrameCallback` sync triggers; AppBar with `_SyncStatusLabel` (spinner / green tick+timestamp / red error), `Badge` on sync icon (count of unresolved errors), logout; single-screen layout (no tabs)
- `lib/features/dashboard/presentation/providers/dashboard_providers.dart` — `lastSyncedAtProvider`, `DashboardStats`, `dashboardStatsProvider` (live SQL query from WO table)
- **Top row** — two side-by-side `_TaskCountCard` tiles: "Pending Work Orders" (brandTeal) and "Pending PM Work Orders" (dark green); count + label with tinted bg/border
- **Donut chart** — `fl_chart` `PieChart`, Overdue (brandError) / Pending (amber) / WIP (brandTeal) sections with legend + percentages; grey ring when total = 0
- **KPI row** — three `_KpiTile` cards: Overdue, Pending, WIP counts in matching colours
- **Quick actions grid** — 2×2 `_QuickActionTile` grid, all brandTeal: Worklist (→ `WorkOrderListScreen`), Create Work Order, Create PM Order, Create Certificate (last three show "coming soon")
- **Bottom `NavigationBar`** — Home, Assets, Inventory, Meter; non-Home tabs show "coming soon" snackbar and keep Home selected

### Sync engine — asset sync complete ✅
- `lib/sync/sync_state.dart` — sealed `SyncIdle / SyncInProgress / SyncComplete / SyncError`
- `lib/sync/sync_notifier.dart` + `.g.dart` — `SyncNotifier.triggerSync()`: connectivity check → purge old errors → asset sync (with field-change detection) → `POST /sync/log` → mark resolved / log error; `unresolvedSyncErrorCountProvider`; `_friendlySyncError(e)`; `_buildSyncMessage` includes removed IDs and field-change summary
- `lib/sync/sync_error_log_data_source.dart` — `SyncErrorLogDataSourceImpl`: `logError`, `markResolved`, `unresolvedCount`, `purgeOldResolved`
- `lib/sync/sync_remote_data_source.dart` — `SyncRemoteDataSourceImpl`: `POST /sync/log` (failures silently swallowed)
- `lib/sync/sync_service.dart` — abstract `SyncService` interface (`sync()`, `enqueueBinaryUpload()`) — WO sync pending
- `lib/sync/change_log_entry.dart` — `ChangeLogEntry` domain model + `ChangeOperation` enum

### Database foundation
- `lib/database/database_helper.dart` — singleton, migration runner; **current DB version: 5**; `_onUpgrade` replays missing migrations for stale installs; WAL is default on API 28+ so no PRAGMA needed
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
- Provisional assets are shown with an amber "PROVISIONAL — pending admin registration" badge in the picker and WO detail

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

## Horse API Server

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

### Database tables (stat_trac)

All table and column names are PascalCase and must be double-quoted in SQL.

- `users` — username, password_hash (SHA-256 hex via pgcrypto), role, technician_code
- `"Asset"` — master asset records (read-only). Key columns: `"AssetID"` (PK), `"AssetEquipmentType"`, `"AssetManufacturer"`, `"AssetModel"`, `"AssetSerialNo"`, `"AssetBarcode"`, `"AssetHospital"`, `"AssetLocation"`, `"AssetCondition"`, `"AssetActive"` (int), `"AssetCondemned"` (int), `"AssetNextServiceDate"`, `"AssetUserDate"` (last-modified, used for since-cursor sync)
- `"Repair"` — work orders (**NOT** `work_orders`). Key columns: `"RepairTrackID"` (PK), `"RepairDate"` (date), `"RepairAssetID"` (FK → Asset), `"RepairFault"` (varchar 200, symptom), `"RepairNote"` (varchar 200, resolution), `"RepairCondition"` (varchar 200), `"RepairStatus"` (int), `"RepairType"` (int), `"RepairPriority"` (int), `"RepairTechID"` (int), `"RepairHospital"` (varchar 20), `"RepairLocation"` (varchar 30)
- `"RepairProgress"` — work order status history (**NOT** `work_order_status_history`). Key columns: `"ProgressID"` (PK), `"ProgessTrackID"` (FK → Repair — **note: DB typo, missing 'r'**), `"ProgressAssetID"`, `"ProgressDate"`, `"ProgressWorkDone"`, `"ProgressHrs"`, `"ProgressTech"`, `"ProgressStatus"` (int), `"ProgressTechID"`

**Integer mappings for `"Repair"` columns:**

`RepairStatus` → Flutter `WoStatus` string: 1=`created`, 2=`assigned`, 3=`completed`, 4=`in_progress`, 5=`awaiting_parts`, 6=`awaiting_parts`, 7=`closed`, 8=`cancelled`, 9=`reviewed`

`RepairType` → Flutter `WoType` string: 1=`CM`, 2=`PM`, 3=`INS`, 4=`INST`, 5=`CM`, 6=`DEC`, 7=`UPG`

`RepairPriority` → Flutter `WoPriority` string: 0=`P3` (default), 1=`P1` (High), 2=`P2` (Medium), 3=`P3` (Low)

### Test user
- username: `tech1`, password: `Test1234!`, role: `technician`

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

## Sync Error Logging (requirement)

Every sync cycle must persist errors to a local `sync_error_log` SQLite table so failures are not silently swallowed. Schema:

| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PK AUTOINCREMENT | — |
| `occurred_at` | TEXT | ISO-8601 UTC |
| `operation` | TEXT | e.g. `push_change_log`, `pull_work_orders`, `upload_photo` |
| `entity_table` | TEXT NULLABLE | e.g. `work_orders`, `assets` |
| `entity_id` | TEXT NULLABLE | local row id or change-log id |
| `error_message` | TEXT | human-readable error |
| `stack_trace` | TEXT NULLABLE | Dart stack trace string |
| `resolved` | INTEGER | 0 = unresolved, 1 = resolved on later sync |

Rules:
- Write a row on every caught sync exception before retrying or giving up.
- Mark `resolved = 1` when the same entity syncs successfully on a subsequent cycle.
- The sync icon in the AppBar should show a warning badge when unresolved errors exist (query count of `resolved = 0` rows).
- Rows older than 30 days with `resolved = 1` are purged on app launch.
- Never log personal information (patient data, contact details) in `error_message` or `stack_trace`.

## Immediate Next Steps (Phase 1 continuation)

1. Assets module — read-only list screen (§3.5, §5, §6.6): browse all assets per hospital, view asset detail, link to WO history
2. Wire real user ID into WO repository (from `authNotifierProvider`)
3. Implement `syncFromRemote()` in WO repository (since-cursor pagination)
4. Service Reports scaffold (§3.6): attach service notes + photos to a completed WO
5. Signatures: capture technician + customer signature on WO completion

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
