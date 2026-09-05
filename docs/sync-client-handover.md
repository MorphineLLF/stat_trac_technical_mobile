# Sync Client Handover — Technician App

**From:** the Flutter technician application (`Stat_Trac-Technical-app`)
**To:** the Go application / sync layer (`C:\Delphi\GitHub_Stat_Trac_Go`)
**Date:** 2026-09-05
**Status:** Input document. Nothing here is built.

---

## Why this exists

`sync-design.md` records the decision that **one sync configuration serves both
applications** — the reps' handsets and this technician app. Sync rules therefore
need to know what *this* app syncs, and that has never been written down
anywhere.

`sync_entities.go` names the eight tables the reps' handsets read. This
application's set is different. This document supplies it, plus the requirements
the sync layer has to satisfy for this client.

**Everything here was read out of the code and migrations, not inferred from
table names.** Provenance is at the end.

---

## 1. What this application is

An Android field-service app for technicians: preventive maintenance,
corrective maintenance, inspections and **test certificates**. Offline-first is
non-negotiable — technicians work in hospital basements with no signal.

Current state: `flutter analyze` clean, 13/13 tests passing, local schema v15
across 14 migrations. It talks to the retired Horse API today.

**The certification module is the substantial one** (~4,600 lines) and carries
all recent work. Work orders exist but have **never synced in either
direction** — `syncFromRemote()` was always a stub.

---

## 2. The sync surface

### 2.1 Pulled — master data, read-only on the device

| Local table | Contents | Notes |
|---|---|---|
| `assets` | Equipment register | Filtered by hospital in the UI. Also holds **provisional** records — see §3.4. |
| `test_template_names` | Certificate template headers | Types 1=Test/OVP, 2=QA, 3=Commission |
| `test_template_items` | Test line items per template | Carries `actual_value_template`; the literal value `'-'` means "no actual reading required" and **must survive verbatim** — the app's `noActualRequired` getter depends on that exact string |
| `asset_pm_tasks` | PM tasks per asset | Drives the PM-task selector in the certificate wizard |
| `test_equipment_assets` | Calibrated test instruments | The picker sorts available before expired using the calibration date |

### 2.2 Pushed — created in the field

| Local table | Contents | Notes |
|---|---|---|
| `test_certificates` | Certificate header | Includes **two signature BLOBs** — see §3.3 |
| `test_outputs` | One row per test line | `pass` / `fail` / `na` as three separate integer flags |
| `test_cert_equipment` | Which instruments were used for this certificate | Join row |

### 2.3 Device-only — must never appear in sync rules

`change_log`, `sync_error_log`, `sync_metadata`, `assets_prov_rescue`

`sync_error_log`, `sync_metadata` and `assets_prov_rescue` are the hand-rolled
engine's machinery and retire with it.

**`change_log` does NOT retire — corrected 2026-09-05.** Per the Go thread's
handover §6b, because primary keys stay server-assigned the synced tables are
read-only on the device and writes go through this outbox, which `uploadData()`
drives. It stays local-only and must never appear in sync rules, but it is kept,
not replaced.

### 2.4 Not synced today, in any direction

`work_orders`, `work_order_status_history`, `work_order_photos`,
`work_order_signatures`

Work orders are created and transitioned entirely locally right now. They are
the harder case for conflicts — dispatchers and technicians can touch the same
row — and should follow certification rather than lead it.

---

## 3. Requirements on the sync layer

### 3.1 Client-generated identity — ✅ SETTLED 2026-09-05

> **Resolved by the Go thread's handover §6b.** Migration 023 added
> `TestMobileID`, `TestOutputMobileID`, `RepairMobileID`,
> `RepairDetailMobileID` and `ProgressMobileID` — nullable, each with a partial
> unique index — applied to local, demo and safeline.
>
> The `MobileIssueID` convention proposed below turns out to **already be** a
> canonical UUIDv4 in a unique-indexed column beside the integer primary key
> (`54fbb81e-e162-49bb-ad14-9f7a0d56b538`). So: generate UUIDv4 on the device,
> write it to the `*MobileID` column, keep the integer primary keys. The Go side
> reconciles with `ON CONFLICT ("…MobileID") DO UPDATE`, which is what makes a
> retried upload update rather than duplicate.
>
> **`AssetPmTask` deliberately gets none** — a technician never creates a PM
> task; the schedule is the office's.
>
> **This app's remaining work:** add a `uuid` package (none in `pubspec.yaml`)
> and generate on create. Original analysis retained below.

**This application currently has no client-generated identity at all.**

```sql
test_certificates : id INTEGER PRIMARY KEY AUTOINCREMENT, server_id INTEGER
work_orders       : id INTEGER PRIMARY KEY AUTOINCREMENT
```

There is no `uuid` package in `pubspec.yaml` and no random-id generation
anywhere in `lib/`. Identity is assigned by the server: `POST /certificates`
returns the real id, which is stored into the nullable `server_id`.

That is safe today **only because the local `id` never leaves the device.** Under
PowerSync the local row *is* the synced row, so two technicians working offline
would both mint `id = 1, 2, 3…` and collide by construction.

**Proposed fix — follow the convention that already exists in this system.** The
reps' app solved exactly this with a client-generated column *alongside* the
server's integer primary key: `MobileIssueID`, `AccountMobileID`,
`IssueReportHistoryMobileID`, `AuditMobileID`, `ItemMobileID`.

Certificates and work orders need the equivalent. This keeps the Stat Trac
integer primary keys intact and matches a pattern the Go side already handles,
rather than introducing UUID primary keys into an 84-table schema.

**What this app needs decided:** the column name, the generation scheme, and
whether it is collision-safe across devices. The generator will live here; the
scheme should not be invented independently on both sides.

> Related open question in `sync-design.md`: whether `SalesVisitID` is
> collision-safe. That generator is in the **reps'** Flutter codebase, which per
> CLAUDE.md is a separate repository and is not this one.

### 3.2 A conflict signal this app can render

The agreed policy is that a conflict refuses the upload, keeps the local change
queued, and tells the person. `sync-design.md` notes the cost: *"a screen on the
device that does not exist yet."*

**That screen is this repository's to build, and it needs the sync layer to
supply, per rejected upload:** which entity and row was refused, which fields
differ, and the server's current values — enough to show a technician what
changed while they were away without a second round trip.

A bare rejection is not sufficient. The certificate the technician is holding
may be the only record of a four-hour job.

### 3.3 Signatures are BLOBs inside the synced row

```sql
tech_signature   BLOB
client_signature BLOB
```

Both live in `test_certificates` itself, not as separate files or paths. Every
certificate therefore carries two embedded images through the sync path.

**This needs a decision before certification syncs.** Options are to keep them
inline, or move to a path/reference model as `IssueReport` does with its photo
path column. It is flagged rather than decided here because the storage choice
belongs to the Go side. Note the interaction with the WAL/replication-slot
hazard: fat rows make a stalled slot fill the disk faster.

### 3.4 Provisional assets are written by the device

`assets` is master data and read-only **with one exception**. When a technician
finds equipment not yet registered, they capture minimum details in the field.
The record is created locally with `is_provisional = 1` and no server id, and
lands in an admin review queue on sync.

So `assets` is not purely a download table for this client. Any sync rule
treating it as read-only will break provisional capture.

---

## 4. What this app does not need

- **Realtime notifications** — PowerSync's stream is the mechanism; nothing here
  polls for change events.
- **A REST read path** — reads come from local SQLite. The app must never block
  on the network for a read.
- **The `Support*` tables** — per `internal/stats/support.go:18` they belong to
  the Delphi application. Not used here.
- **The reps' entities** — `SalesAccount`, `SalesVisit`, `HospitalUsage` and the
  `*Deleted` tombstones are the handsets' concern, not this app's.

---

## 5. What this app is waiting on

| # | Item | Owner | Status |
|---|---|---|---|
| 1 | Client-generated id scheme (§3.1) | Go + this repo | ✅ Settled — migration 023 |
| 2 | Conflict rejection payload shape (§3.2) | Go | ⛔ Blocked — upload endpoint for work orders and certificates does not exist yet; `sync_push.go` covers rep entities only |
| 3 | Signature BLOB storage decision (§3.3) | Go | 🔄 Open — confirmed as `bytea` server-side, not synced |
| 4 | PDF generation replacement | Go | 🔄 Open |
| 5 | Confirmation `test_equipment_assets` / `asset_pm_tasks` map to real tables | Go | 🔄 Open |

**Unblocked and worth doing first, per the Go handover §8:** `AppConfig.baseUrl`
is still `http://10.0.2.2:9000` — an emulator route to the *retired* Horse port,
which is now the **rep API**, a live Go service that took the port deliberately.
The technician app is therefore pointing at something that cannot answer it.
Repointing at `https://demo.stattrac.net` and wiring the device-token → sync-token
→ `fetchCredentials()` chain proves the whole auth path on a real device and is
finished on the server side.

---

## 6. Answers to the Go handover's §9 questions

**"Which of the sixteen local tables must be on the device, and for whom?"**
§2 above. In short: `assets`, `test_template_names`, `test_template_items`,
`asset_pm_tasks`, `test_equipment_assets` down; `test_certificates`,
`test_outputs`, `test_cert_equipment` up. `change_log` stays local-only but is
**kept**. `sync_error_log`, `sync_metadata`, `assets_prov_rescue` retire. Work
order tables do not sync today at all.

**"Is a work order scoped by the technician it is assigned to, by its asset's
hospital, or both?"**
Hospital scope matches this app's UI, which filters by hospital throughout — the
asset picker is hospital-first. But the legacy schema carries
`Admin.UserAssignedWO` ("1 = user can only view their own assigned WOs"), so
*both* rules exist in the old system and the per-user one is a real setting.
**Recommend hospital scope, with `UserAssignedWO` as a narrowing filter applied
in the app rather than in sync rules** — a technician covering a site needs to
see its work, and re-syncing on reassignment is worse than filtering locally.

**"How should photographs and signatures reach a device?"**
Reference plus separate fetch. Signatures are currently `BLOB` columns inside
`test_certificates`, so certificates would otherwise drag two images each through
the stream — and the busiest site already carries ~21,400 `TestOutput` rows
before any binaries. Fat rows also make a stalled replication slot fill the disk
faster, which is a hazard already being monitored.

**"Which of its writes are the server's to refuse on conflict, and which can
never conflict by construction?"**

| Entity | Can conflict? |
|---|---|
| `test_certificates` / `test_outputs` | **Never, by construction.** A certificate is created once by one technician and not edited afterwards. |
| Provisional `assets` | **Never.** Only ever created on the device, never edited server-side before review. |
| `work_orders` | **Yes.** Dispatchers reassign and change status while a technician holds the record. This is the only genuine conflict surface. |

That is the strongest argument for sequencing certification first: it exercises
the whole upload path with the conflict case switched off.

---

## 6. Provenance

Derived on 2026-09-05 from:

- `lib/database/migrations/` — all 14 files, for the authoritative table and
  column list (not the CLAUDE.md summary, which was stale on the DB version)
- `lib/sync/sync_notifier.dart` — the live sync pipeline, for direction per table
- `lib/features/certification/data/` — for what is written versus read
- `pubspec.yaml` — confirming no uuid/nanoid dependency exists

Cross-referenced against `C:\Delphi\GitHub_Stat_Trac_Go\docs\sync-design.md`,
which is authoritative for every backend decision. Where this document and that
one disagree, that one wins.

This app's own migration design:
`docs/superpowers/specs/2026-09-05-powersync-migration-design.md`.
