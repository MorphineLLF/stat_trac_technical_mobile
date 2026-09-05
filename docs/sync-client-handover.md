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

> ## ⛔ NEVER USE THE HORSE-ERA MAPPING FOR ANYTHING
>
> **Do not read, consult, copy or "check against" the retired Horse code when
> deciding what a field means.** Not the old models, not the old data sources,
> not the old local tables, not `*_model.dart` `fromJson` factories written for
> the Horse API. They describe an API that no longer exists, and treating them
> as a reference reintroduces decisions that were already retired.
>
> **The only authorities are:**
>
> 1. `lib/sync/powersync_schema.dart` — generated from the live database
> 2. The Go repository — `C:\Delphi\GitHub_Stat_Trac_Go`
> 3. `docs/sync-client-handover.md` — the agreed contract with the Go side
>
> If a field's meaning is unclear, ask the Go session or read the Go source.
> Do not infer it from Horse-era code, and do not cite Horse-era code as
> evidence for anything.

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

## 9. Provenance

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

---

## 7. TestOutput — contract details confirmed 2026-09-05

Measured server-side across 152,884 rows. These shape how certificate rendering
must be written.

**`TestDescriptionID` is a free-text section heading, not an identifier.**
102 distinct values, **zero** of them numeric — e.g. "ELECTRICAL SAFETY TESTS",
"POWER ON SELF TEST / CONFIGURATION", "SET-UP". The name is the trap: a column
ending in `ID` that is neither a key nor a foreign key. There is no lookup table
and looking for one is wasted time. It also is **not unique within a
certificate** — 21,131 (cert, section) pairs hold more than one row — so it
groups sections containing lines and can never serve as a row key.

Note this means the numeric-as-text trap does *not* apply to it. It does apply
to `TestValue` and `TestActualValue` (both varchar), and `TestPass` / `TestFail`
/ `TestNA` are booleans arriving as 0/1 — the `psNum` / `psBool` seams cover
those.

**Nothing in the table orders lines within a section.** There is no sequence or
position column. The only stable ordering available is `TestOutPutID` ascending.

> **Live defect in this app.** `CertLocalDataSourceImpl.getOutputsByCertId`
> issues its query with **no `orderBy` clause**, so SQLite returns rows in
> unspecified order. A certificate is evidence, and rendering its measurement
> lines in a different order from the office copy undermines exactly that. Must
> order by the key ascending when the reads move to PowerSync.

**`TestOutPutID` ascending is already the server's contract, not a suggestion.**
Every Go query reading multiple rows orders by it — `certificate.go:593`
(`TestLinesFor`), `certificate_chart.go:201` (chart series) — the latter
commented *"The certificate's own rows, in the order it lists them"*. The
desktop, the PDF and the printed certificate all render in that order today, so
adding the `orderBy` makes the tablet match the office copy exactly. For
evidence, that match is the whole point.

**Residual risk neither side can fix in a query.** Nothing in the schema
enforces the order — there is no position column. `certificate_write.go:1059`
does `delete from "TestOutput" where "TestOutputCertID" = $1` and re-inserts, so
an edited certificate gets freshly allocated ids. After an edit, both
implementations will agree with each other and both will differ from what the
certificate looked like before. That is a schema-level gap, recorded on both
sides.

**8,850 orphaned lines.** They point at 238 distinct certificate ids, ~37 lines
each, all inside the live id range, with **zero** rows carrying
`TestOutputCertID = 0` — so there is no benign unattached state. 238
certificates were deleted and their lines left behind. A records question for
the business, not a bug to script around.

### If this app ever surfaces missing or unbucketed rows

**One condition per table, cleared by the count returning to zero — never one
alert per row.** An orphan is a row sync will never select, so a per-row alert
can never clear: the count only climbs and a badge that cannot reach zero trains
a technician to ignore the next real failure. The rep app shipped exactly this
and needed a data-only migration to undo it on devices already carrying it.

### The rule, stated generally

> **An indicator must be able to reach every state reality can reach, including
> the good one.**

Three instances of this defect surfaced on 2026-09-05, in three codebases, none
of which knew about the others:

| Codebase | The indicator could not... |
|---|---|
| This app | go **green** — sticky `downloadError` after a recovered blip |
| Rep app | go to **zero** — per-row orphan alerts that can never clear |
| Server | go **loud** at all — a row in no bucket is silent, forever |

Noise that cannot stop and silence that cannot start are the same defect. Both
end with a person who has learned the signal carries no information, which is
worse than shipping no signal at all.

---

## 8. Place-of-test — a missing column, not a missing decision

Raised by the Go session 2026-09-05. Migration 020 added a trigger that
re-resolves `SyncHospital` from the asset's **current** hospital on any insert
or update, across `Repair`, `RepairDetail`, `RepairProgress`, `TestCertificate`
and `AssetPmTask`. So moving an asset between hospitals and then editing any
historical row silently moves that row between technicians' devices, with
nothing recording that it happened.

### What this app believes, from the code

- `test_certificates` has **no hospital column**. Never stored, never sent —
  hospital is absent from the cert push payload entirely.
- The certificate detail screen displays **no hospital at all**.
- The create wizard shows `selectedAsset.hospital` read live off the asset,
  purely as a confirmation aid while picking equipment. It is not captured.
- The asset picker is hospital-first, so the technician's mental model is
  "find the machine where it is now".

The app therefore assumes *follows-the-machine* by **omission** rather than by
decision. It asserts nothing, so it cannot contradict the database — there is no
second defect hiding under the trigger.

### The asymmetry that matters

```
Repair           RepairHospital + RepairLocation + SyncHospital
RepairDetail     SyncHospital only
TestCertificate  SyncHospital only
```

`Repair` carries a business location field **separate** from the routing column,
so for work orders the two goals never conflict: the record of where work
happened survives while routing re-resolves. The trigger touches only
`SyncHospital`, leaving the evidential field alone.

**`TestCertificate` has no such field**, so `SyncHospital` is doing double duty —
routing key *and* the only trace of where the test happened. That is the defect,
and it sits *underneath* the trigger rather than being caused by it. Both
available behaviours lose something:

| | |
|---|---|
| Re-resolve | routing correct; destroys the only record of where the test was performed |
| Insert-only | preserves that record by overloading a sync column with evidential meaning; the certificate then never reaches the technician now holding the machine |

The requirements are not in conflict. **The column is.** A certificate needs what
`Repair` already has: a location captured at test time, separate from the
routing key — after which `SyncHospital` can re-resolve freely.

This module records the technician, the date, the analyser with its calibration
date and serial, and the client signature. A test is a measurement on a machine,
at a place, on a date — and only two of those three currently survive.

**`AssetPmTask` is different and separable:** it wants follows-the-machine
unconditionally and needs no new column. A PM schedule concerns the machine's
future, not its past, so there is no historical claim to preserve.

Adding a column is a migration, and therefore the user's decision — as is
whether the trigger should exist at all, given this project's no-triggers rule
that migration 020 broke.

---

## 10. REQUEST: the certificate upload endpoint

**This is the single blocker for the write half, and it is server-side.**
Recorded here 2026-09-05 as a formal request rather than a discussion point.

### Why it is urgent

Reads are done. The app now shows assets, certificates, measurement lines, PM
tasks, templates and test equipment from PowerSync, all verified on a device.
**A completed certificate, however, is silently lost** — it writes to the
retired local table, nothing pushes it, and the certificate list reads
PowerSync so it does not even appear. A technician finishes a job and the
record vanishes.

Until the endpoint exists, this build must not be used for real work.

### What exists already

`internal/stats/certificate_write.go` has the entire lifecycle — `StartTest`,
`SaveTestLine`, `IssueCertificate`, `VoidCertificate`, `SaveSignature`. What is
missing is a route a handset can post to: `sync_push.go` covers accounts,
visits and issues, and not certificates or work orders.

### What the app can supply

Everything in `IssueInput` except the parts it has no UI for yet:

| Field | App today |
|---|---|
| `Verdict` | ✅ sent as `patient_safe` |
| `Notes` | ✅ sent |
| `NextService` | ❌ no UI |
| `CompletePmWorkOrder` | ❌ no UI |
| `CompletePmJobCard` | ❌ no UI |

Plus the certificate header, its measurement lines, the equipment selections
and both signatures.

**The three missing inputs are this repository's work and will be built** — but
the endpoint's shape decides what a queued certificate contains, so it comes
first. Building the UI against a guessed contract would mean building it twice.

### Two things that must come with it

1. **Idempotency on `TestMobileID`.** Migration 023 added the column; the app
   does not yet generate one and has no `uuid` package. Both sides need to
   agree the value is a canonical UUIDv4 written by the device, matched with
   `ON CONFLICT ("TestMobileID") DO UPDATE`. A technician walking out of signal
   mid-upload is the normal case, not an edge case.
2. **A conflict rejection the app can render.** Per the agreed policy the write
   is refused, the local change stays queued, and the person is told. That needs
   entity, row, the differing fields and the server's current values — enough to
   build the "this record changed while you were away" screen without a second
   round trip.

### Signatures are a separate problem, and they gate validity

`bytea` does not cross the sync stream — 3,796 exist server-side and the
captured stream carried none. `SaveSignature` proves the desktop can store
them, so what is missing is transport from a handset. **A certificate is not
valid without its signatures**, so an upload path that carries everything else
still does not produce a usable certificate. Worth solving alongside rather
than after.

---

## 11. The upload contract — RESOLVED 2026-09-05, correcting §10

**§10 was wrong on its central claim.** It said the endpoint did not exist and
"what is missing is the doorway, not the logic". Both halves were wrong, and
the second one mattered.

The mistake: `sync_push.go` is in **`C:\Users\HomePC\stat_trac_api_go`** — the
**rep API** on :9000, which serves the sales handsets. The technician upload
path is in `C:\Delphi\GitHub_Stat_Trac_Go`, the same server that mints the
device token. Two Go codebases; I read a filename and assumed one.

### The route — it exists and has since 2026-09-05

```
POST /{company}/sync/upload        Bearer device token (a cookie gets 403)
{"ops":[
  {"table":"TestCertificate","mobile_id":"<uuid v4>","seen_at":null,
   "data":{"TestAssetID":9304,"TestDate":"...", ...}},
  {"table":"TestOutput","mobile_id":"<uuid v4>",
   "data":{"TestOutputCertID":123, ...}}
]}

200 -> {"applied":n,"assigned":{"<mobile_id>":<server pk>}}
409 -> nothing applied, conflicts listed
400 -> a client bug; the message says which
```

Verified in the Go repo: `cmd/stattrac/main.go:298`, `cmd/stattrac/syncupload.go`,
`internal/stats/syncupload.go`. Max 500 ops, 1 MB body.

Writable: `Repair`, `RepairDetail`, `RepairProgress`, `TestCertificate`,
`TestOutput`. **`AssetPmTask` is deliberately not writable.** Columns are
allowlisted and an unlisted column is **dropped silently, not refused**, so a
schema skew still uploads what the server understands. `SyncHospital` and
`SyncUpdatedAt` are never writable — the server sets them by trigger.

`TestMobileID` idempotency is built: `on conflict ("TestMobileID") do update`,
partial unique index, and the pk returned with `(xmax = 0)` to distinguish an
insert from a retry. Generate canonical UUIDv4 on the device.

### WARNING — the endpoint does NOT issue the certificate

Confirmed by grep: `syncupload.go` never calls `IssueCertificate`,
`setPmScheduleFromCertificate` or `CertPmEffect`, and `TestTotalTest`,
`TestTotalDone` and `TestNextService` are not in the writable column list.

It is a generic allowlisted upsert. A certificate uploaded through it lands as
a **row**, not as an issued certificate:

- the completeness checks never run (`ErrIncompleteTests` / `ErrIncompleteValues`)
- `TestNextService` is not set
- the PM schedule does not move, no PM work order is completed, no job card is
  written — every rule in §8 and in `certificate_nextservice.go` is on the
  desktop path only
- the void / already-issued refusals do not apply

In the Go session's words: *"a document that looks complete on your screen and
is evidence of nothing on the server."*

**So the contract still being waited on is not the route — it is whether a
`TestCertificate` op carries an issue intent that runs `IssueCertificate`'s
transaction.** Their proposal, with the user: a separate op kind in the same
batch, applied after the rows, carrying verdict / notes / next_service /
complete_pm_work_order / complete_pm_job_card. One doorway, one transaction,
one all-or-nothing rule.

### What can be built today

Point `uploadData()` at the route and send the certificate with its
`TestOutput` lines in one batch. **That stops the silent data loss** — the
record reaches the server, gets a pk, gets its hospital by trigger, gets audit
rows, and comes back down through PowerSync so the list shows it. Nothing built
now is wasted when the issue op lands.

The wizard's Save must then say what actually happened: the record is safely on
the server but is **not yet a valid certificate**.

### The 409 conflict payload — built, and how to consume it

```json
{"applied":0,
 "conflicts":[{"table":"TestCertificate","mobile_id":"9ba75859...",
   "seen_at":"2020-01-01T00:00:00Z","server_at":"2026-09-05T12:44:27Z",
   "fields":[
     {"field":"TestDate","mine":"2026-09-05","server":"2026-01-31","differs":true},
     {"field":"TestTech","mine":"A Tech","server":"A Tech","differs":false}]}]}
```

Every column the op set is listed, **not only the differing ones** — someone
choosing between two versions of a certificate needs to see the readings that
agree as well as the one that does not.

Two rules for consuming it, both load-bearing:

1. **Trust `differs`; never re-derive it.** It is PostgreSQL's answer —
   `"TestDate" is distinct from $2` with the device's value bound as a
   parameter, so the database coerces it exactly as the insert would. This
   matters specifically because the app sends JSON: an integer column arrives
   as `float64` and a date as a string, so a text comparison would call `9304`
   and `9304.0` different and show a technician a conflict that does not exist.
2. **`mine` and `server` are both text — render them, do not parse.** `server`
   is PostgreSQL's own `::text` rendering, empty for null. Parsing it back into
   a typed value and comparing is the exact mistake `differs` exists to prevent.

`fields` is purely additive; the rest of the body is unchanged.

**Not verified end to end:** a real 409 over HTTP. The service layer is tested
against the real database and the handler encodes the struct directly, but
producing one needs a committed row carrying a mobile id, which is a write to
demo and the user's call to authorise.

---

## 12. Issuing a certificate — the contract is FIXED, 2026-09-05

`"action":"issue"` on the same `POST /{company}/sync/upload`. This is the
contract the wizard UI was being held for. It is settled; build against it.

### One batch

Row ops apply first regardless of arrival order, so the readings are on the
certificate before it is issued.

```json
{"ops":[
  {"table":"TestCertificate","mobile_id":"<cert uuid>","data":{ }},
  {"table":"TestOutput","mobile_id":"<line uuid>","data":{ }},
  {"table":"TestCertificate","mobile_id":"<cert uuid>","action":"issue",
   "data":{"verdict":1,"notes":"...","next_service":"2027-09-05",
           "complete_pm_work_order":true,"complete_pm_job_card":false}}
]}
```

The issue op names its certificate by the **same `mobile_id`** as the row op.
Resolved from the batch first, from `TestMobileID` otherwise — so a certificate
uploaded last week can be issued today. `200` gains `"issued":["<cert uuid>"]`;
`applied` still counts row ops only. Omitting `action` is unchanged behaviour.

**It calls `IssueCertificate`.** Not a reimplementation — the completeness
rules, the totals, `TestNextService`, `setPmScheduleFromCertificate` and the
work order all run exactly as they do at a desk. Everything in §8 and
`certificate_nextservice.go` applies.

### Four things that will catch a skim-read

1. **`verdict` is required and never defaulted.** `0` is Non-Compliant — the
   most serious verdict there is — so a missing verdict is *rejected* rather
   than read as a failure. **Make the technician choose.** It is a pointer
   server-side specifically so this cannot go wrong silently.
2. **Unknown fields are REFUSED, not dropped.** This is the opposite of the
   column allowlist on row ops, and deliberately so: a dropped column is a
   field the office fills in anyway, but a dropped `complete_pm_work_order` is
   a work order left open that everybody believes is closed. Spell the five
   exactly — there is a server test that `complete_pm_workorder` is rejected.
3. **`next_service` is conditional on the template's design.** Where Next
   Service Due is ticked it is required and refused if missing; where it is not,
   one sent is ignored. When kept it writes `TestNextService` **and** the PM
   task's schedule date — including no computed date for a meter task
   (`isMeterBased`, already on `AssetPmTask`) and no date move while a work
   order is open unless it is being completed.
4. **The test date is not in this payload.** It is whatever is on the
   certificate from when the test started. Issuing does not ask twice.

### 422 is a new status and it is not 400

```json
{"applied":0,
 "rejections":[{"table":"TestCertificate","mobile_id":"...",
                "reason":"incomplete_tests",
                "message":"not every test has been marked pass, fail or N/A"}]}
```

**`400` means the app is broken and the fix is in the app. `422` means the
request was understood perfectly and the answer is no** — that is a sentence
for the technician, and retrying the same batch will never help.

Switch on `reason`; display `message` (wording may improve, the code will not):
`incomplete_tests`, `incomplete_values`, `already_issued`, `void`, `not_found`,
`invalid` (with `field`).

**`not_found` also means out of scope.** A person who may not see a certificate
is not told it exists — the same convention as everywhere else here.

**One rejection refuses the whole batch**, exactly as one conflict does. Keep
the queue, show the message, fix it on the device, send again.

### Verified / not verified

Verified server-side: twelve new tests, ten against the real database — the
happy path asserting `TestTotalTest` and `TestTotalDone` equal the actual line
count (the thing a row op could never produce), a chosen `0` accepted, a
missing verdict refused, an unanswered line rejected, already-issued, void,
unknown mobile id, unknown field, a bad date, and the scope bound. Nothing
committed; every test rolls back.

**Not verified:** a real 200 or 422 over HTTP. Needs a device token and a
committed row, which is a write to demo and the user's call.

---

## 13. Decisions that closed themselves, 2026-09-05

**Test equipment global bucket — BUILT.** `deploy/powersync/sync-rules.yaml`
line 84. Analysers live at the company depot; bucketing them `by_hospital`
reached only 5 of 7 technicians on demo and 2 of 4 on safeline, and an empty
analyser picker blocks issuing a certificate entirely. A row can sit in two
buckets under one id, so an analyser that is also somebody's asset keeps its
`by_hospital` copy and nothing duplicates. **Nothing for this app to wait on.**

**`AssetMobileID` — not a live question.** Migration 025 was withdrawn and
reversed the same day on the user's instruction, and the column was dropped.
`Asset` is back to 63 columns, verified. Raised on a premise that was never
true (see §8's note on the provisional-asset rule) and now fully unwound.

**Still open, and now the only thing between a handset and a complete
certificate: signatures.** `bytea` crosses neither the sync stream nor the
write allowlist. A certificate is not valid without them.

---

## 14. CORRECTION — a line names its certificate by mobile id

Sent 2026-09-05, an hour after §12, and it is the difference between the
endpoint working and not.

**A measurement line carries `TestOutputCertMobileID`, not `TestOutputCertID`.**
The earlier example showed `"TestOutputCertID":0`, and that was wrong in the
way the register already suffers from: a device creating a certificate offline
cannot know its server key — that is the whole premise of a mobile id — so
every reading on a new certificate had nothing to point at. A `0` there is not
a certificate reference, it is **an orphan with a plausible-looking field**,
and the register holds 8,850 of exactly that.

```json
{"ops":[
  {"table":"TestCertificate","mobile_id":"<cert uuid>","data":{ }},
  {"table":"TestOutput","mobile_id":"<line uuid>",
   "data":{"TestOutputCertMobileID":"<cert uuid>",
           "TestDescription":"Earth continuity","TestValue":"0.08","TestPass":true}},
  {"table":"TestCertificate","mobile_id":"<cert uuid>","action":"issue",
   "data":{"verdict":1,"next_service":"2027-09-05","complete_pm_work_order":true}}
]}
```

The line carries the **certificate's** mobile id; its own is the `mobile_id` at
the top of the op. Resolved from the batch first and from `TestMobileID`
otherwise, so lines sent tomorrow for a certificate uploaded today still link.
It is not a column and never reaches the row — `TestOutputCertID` is written
from it.

### Four rules around it

1. **Certificates are written before every other row op**, whatever order the
   batch arrives in. No need to sort the queue.
2. **A line naming a certificate the server does not have is refused, not
   written.** Writing it would make one more orphan, and an orphan is silent —
   in no bucket, reaching no device, nothing saying so.
3. **Sending both `TestOutputCertMobileID` and `TestOutputCertID` is refused,
   not reconciled.** A device that can set both can make them disagree, and the
   disagreement is invisible.
4. **A line against a certificate the server already has may still send
   `TestOutputCertID` alone.** That path is unchanged.

### How this app enforces it

`SyncUploadOp.certificateLine(lineMobileId:, certificateMobileId:, data:)`
is the only way this app builds a line for a new certificate. It sets
`TestOutputCertMobileID` itself and **throws** if `data` also carries
`TestOutputCertID` — including a `0`. The rule is in the type rather than in a
comment, because this is precisely the mistake that produces a silent orphan.

Everything else in §12 stands: the issue op, the verdict rule, refused unknown
fields, the 422 codes. Only the line-to-certificate link changed.
