# Flutter Technician App — PowerSync Migration Design

**Date:** 2026-09-05 (rewritten same day, see *Revision note*)
**Status:** Design — scoped to this repository only
**Supersedes:** the Delphi Horse REST API architecture for this app

---

## Authority

**The backend, schema, tenancy, sync rules and conflict policy are decided in the
Go repository, not here:**

> `C:\Delphi\GitHub_Stat_Trac_Go\docs\sync-design.md`

That document is authoritative and current. This spec covers **only the Flutter
technician application** — the work that lives in this repository. Where the two
disagree, `sync-design.md` wins.

### Revision note

An earlier version of this document proposed a greenfield snake_case schema,
single-database tenancy with `company_id`, RLS-based read scoping, GoTrue
authentication and last-write-wins conflict resolution. **All five were wrong.**
The Go repository already holds 84 PascalCase tables, 18 migrations and live
data; it already runs database-per-company; and its conflict policy deliberately
rejects last-write-wins. The implementation plan written against those
assumptions is retained but marked superseded:
`docs/superpowers/plans/2026-09-05-powersync-schema-sync-rules.md`.

---

## 1. What is already decided (summary — do not re-litigate)

Taken from `sync-design.md`, recorded here so this app's work can be planned
against it. **Nothing in this section is this repository's to change.**

| | |
|---|---|
| **Sync engine** | PowerSync. `journeyapps/powersync-service:1.24.0`, already running in production on the same box for Metria, against plain Postgres, with no Supabase anywhere. |
| **Database** | Plain `postgres:17.11`. `wal_level=logical`, `max_replication_slots=10`, `max_slot_wal_keep_size=2GB`, bound to `127.0.0.1:5445`. Databases `demo` and `safeline`, owned by the `stattrac` role. |
| **Schema** | **The existing Stat Trac schema continues** — 84 PascalCase tables. There is no legacy-vs-new split and no greenfield schema. Delphi, UniGUI and Horse (the *applications*) are retired; the *database* stays. |
| **Tenancy** | Database per company. The connection *is* the tenant boundary. `Stat_Trac` serves local testing and Windows production; `safeline` and `demo` are company databases on the VPS. The Go app connects to exactly one. |
| **No write-back layer** | Because Delphi is retired, there is no second system to reconcile with. Go writes the company database directly. No mirror job, no outbox, no id reconciliation. |
| **Identity** | The Go API issues ninety-day device tokens and serves its own JWKS. PowerSync verifies client JWTs against it. No GoTrue. |
| **Read scope** | PowerSync sync rules. RLS is explicitly *not* used — PowerSync reads as a privileged replication user, so RLS would be a third home for scope that nothing consults. |
| **Sync configuration** | **One configuration serves both applications** — the reps' handsets and this technician app. Not two rule sets. |
| **Supabase** | Installed, proved and removed on 2026-09-05. It is not a sync engine. Do not reintroduce it. |

### Conflict policy — this drives real UI work here

**A conflict notifies the person and leaves the record open.** Not
last-write-wins, and not a silent merge. When a device uploads a change to a row
that has moved underneath it, the upload is refused, the local change stays in
the queue, and the person is told. Nothing is discarded and nothing is
overwritten by a machine.

The rationale is specific to this domain: a test certificate is evidence, and two
technicians disagreeing about one is a question for a human, not a timestamp
comparison.

**This supersedes §BR-10 in CLAUDE.md** ("last-write-wins for free-text/status"),
which no longer describes the system.

Detection is **optimistic concurrency** using timestamp columns the schema
already carries (`SalesVisitUpdatedAt`, `AccountUpdatedAt`,
`IssueReport."UpdatedAt"`, `UsageUpdatedAt`). A device uploads the value it last
saw; the server refuses the write if it no longer matches. No new column, no
version counter.

`sync-design.md` names the consequence directly: *"It costs a screen on the
device that does not exist yet — 'this record changed while you were away' — and
that screen is part of the work."* **That screen is a deliverable of this
repository.**

### Operational hazard to be aware of

A replication slot whose consumer stops retains WAL indefinitely and fills the
disk — the usual way a deployment like this takes a server down, and this box
also runs Metria and Nextcloud. `max_slot_wal_keep_size=2GB` is set so a dead
slot breaks the sync client (recoverable) rather than the host, and
`/usr/local/sbin/stattrac-slot-check.sh` runs every fifteen minutes.

This matters to app development because **a device left unsynced for a long
period is a normal condition, not an error** — the field app must tolerate a
broken slot and resync cleanly rather than assuming continuity.

---

## 2. Scope of this repository

**In scope:** the Flutter technician application's migration from the Horse REST
API to PowerSync.

**Out of scope** (owned by the Go repository): the schema, migrations, sync
rules, the Go API's endpoints and token issuance, PowerSync service deployment,
replication-slot monitoring, and anything concerning the reps' handset
application.

---

## 3. Current state of this app

Verified 2026-09-05: `flutter analyze` clean, `flutter test` 13/13 passing, local
schema at v15 across 14 migration files.

**Clean Architecture contains this change well.** Repositories depend on
interfaces rather than on Dio, so the domain and presentation layers — including
every Riverpod provider — are unaffected in shape.

### What is replaced

| Area | Files | Note |
|---|---|---|
| HTTP client | `lib/api/dio_client.dart`, `lib/api/auth_interceptor.dart` | Removed entirely |
| Remote data sources | `asset_`, `auth_`, `cert_`, `wo_`, `sync_remote_data_source.dart` | Five files; the seam that makes this tractable |
| Sync engine | `lib/sync/` — `sync_notifier.dart`, `change_log_entry.dart`, `sync_error_log_data_source.dart`, `sync_remote_data_source.dart` | PowerSync replaces this wholesale |
| Local database | `lib/database/database_helper.dart` + 14 migrations + every local data source | **Largest single piece of work.** PowerSync owns the device SQLite database. |

Thirteen files reference Dio today. The count is manageable; the local-database
rewrite is what carries the risk.

### What is written new

1. **`uploadData()`** — maps each queued local mutation to the Go API's write
   endpoints. `sync-design.md` warns plainly: *"Most sync bugs live here."*
2. **Idempotency on retry** — a retried upload must not duplicate a row.
3. **The conflict screen** — "this record changed while you were away", per the
   conflict policy above. New UI with no current equivalent.
4. **Sync status UI rebinding** — the dashboard's `_SyncStatusLabel` and error
   sheet currently read `SyncNotifier` state and the `sync_error_log` table. They
   rebind to PowerSync's connection state and upload-queue depth.

### What survives unchanged

The offline-first rule, the domain layer, all Riverpod providers, the theme, and
every screen except those touching sync status.

---

## 4. Certificate module — sequencing

Certification is this app's most complete module (~4,600 lines) and the one with
the most recent work. It is also the natural first module through PowerSync,
because completed certificates are immutable records: once written they are not
edited, so the conflict path is exercised least there while the mechanics are
proved.

Work orders are the harder case — dispatchers and technicians can touch the same
row — and should follow.

### Local artefacts to retire

The current cert code carries workarounds that exist only because identity was
server-assigned: `server_id` alongside local `id`, the `cert_name` backfill, and
`getMaxServerId()` cursor logic. Whether these disappear depends on how identity
is assigned under PowerSync, which is an open question below — **not** an
assumption to build on.

---

## 5. Open questions — this repository's to answer

> **Answered 2026-09-05 and written up for the Go thread:**
> `docs/sync-client-handover.md` — the table set, the client-identity finding,
> the conflict-payload requirement and the signature-BLOB question.

1. **Client-generated identity for this app's entities.** `sync-design.md` raises
   collision-safety for `SalesVisitID` in the *reps'* application, which per
   CLAUDE.md is a separate codebase. The equivalent question for certificates and
   work orders created offline in *this* app has not been asked yet, and must be
   before `uploadData()` is designed.
2. **Which tables this app syncs.** `sync_entities.go` lists what the reps'
   handsets read. The technician app's set — assets, templates, certificates, PM
   tasks, work orders — differs and is not yet recorded anywhere. Since one sync
   configuration serves both applications, this list is an input the Go
   repository needs from here.
3. **Binary artefacts.** Photos and signatures queue separately today. How they
   travel under PowerSync is undecided.
4. **PDF generation.** FastReport VCL is retired with Delphi. The replacement is
   not this repository's to choose, but this app consumes the result.

---

## 6. Constraints carried forward

- **Offline-first is non-negotiable** — strengthened, not weakened, by PowerSync
- **POPIA data residency** — self-hosted, no managed cloud holds personal information
- **Never log personal information** to Crashlytics or Sentry
- **No production schema changes from this repository** — the schema belongs to
  the Go repository

---

## References

- `C:\Delphi\GitHub_Stat_Trac_Go\docs\sync-design.md` — **authoritative**
- `C:\Delphi\GitHub_Stat_Trac_Go\docs\android-supabase-design.md` — the Supabase
  episode, superseded, kept for its reasoning
- [PowerSync self-hosted configuration](https://docs.powersync.com/configuration/powersync-service/self-hosted-instances)
- [PowerSync JWKS example](https://github.com/powersync-ja/powersync-jwks-example)
