# Work Orders — capture on site (design)

**Date:** 2026-10-01
**Status:** approved in conversation, section by section; awaiting review of this document
**Go side:** `docs/go-requirements-work-order-capture.md` — built by the user in a
separate Stat Trac Go session. **This repository does not touch `E:\Stat_Trac_Go`.**

## Intent

A technician on site raises a work order on a machine, records the job on the
job card, gets it signed by themselves and the client, and saves it — with or
without signal. The server raises and completes it exactly as the desktop's
**capture on site** does, and it comes back to the phone with its number.

### What the user said

- **No Horse API, and no Horse-era code as a reference.** The existing
  `lib/features/work_orders/` is deleted, not adapted.
- **Two kinds of work order exist: book-in and capture. The phone does capture
  only.** Booking in stays on the desktop.
- **Only the work order itself** — the desktop's *Work Order* tab (job card). No
  WO Request screen, no WO Progress screen.
- Sync both ways.
- Worklist: the signed-in technician's work orders only.
- Form fields as listed below, N.O.P included.
- **Both signatures, both required.**
- The Go change is stated, not built, here.

### Assumptions (from the Go source, not from the user)

- Capture = `CaptureWorkOrderWithCard` (`internal/stats/workorder_capture.go`):
  four checks, `Repair` at status 2 assigned to the caller, job card with
  `RepairDetailType = 3`, two progress lines, and saving the card **completes**
  the work order (status 9).
- The signatures are the **job card pair** (`SaveJobSignature`:
  `RepairDetailTechSignature`, `RepairDetailClientSignature`), not the request
  pair.
- "Open" = `RepairRequest = 1 AND coalesce(RepairStatus, 0) <> 9` on the asset
  (confirmed by the Go session).

### Success

1. A job captured with signal comes back with a WO number, shows in the
   Worklist, and reads on the desktop as captured, completed, both signatures.
2. A job captured with no signal shows *Waiting to sync* and sends itself when
   signal returns.
3. A job the server refuses is kept on the phone with the server's reason —
   never lost, never silently deleted.

## Out of scope

Book-in. WO Request and WO Progress. PM work orders and the Create PM Order
tile. Priority (the server sets Medium). Quote / order / invoice numbers.
Labour, travel, mileage and rates. Parts and spares. Editing a work order after
Save. Signatures coming back down from the server (`bytea` does not sync).
Work-order PDF.

## 1. Screens

### Entry

Dashboard tiles **Create Work Order** and **Worklist** are re-enabled and point
at the new screens. **Create PM Order** stays disabled.

### Create — one screen, three steps (phone layout, 384 dp reference)

**Step 1 — Machine.** `showAssetPicker` with the PowerSync asset data source,
the same as the certificate wizard (hospital, then equipment).

After a machine is picked, the synced `Repair` rows are checked:
`RepairAssetID = ? AND RepairRequest = 1 AND coalesce(RepairStatus, 0) <> 9`
over **all** synced rows, not only this technician's — a booked-in work order
blocks a capture. If one matches, an amber card:
*"Work order {n} is still open on this machine (as of last sync). The server
will refuse a second one."* It is a **warning, not a block**: the phone's copy
can be stale, and the server decides.

**Step 2 — Work Order.**

| Field | Rule |
|---|---|
| Type of work | Required. Repair 1, Warranty 2, Call-out 3, QA 4, Installation 6. **No default, never PM (5).** |
| Date in / Time in | Required. Pre-filled with now, editable. |
| Date completed / Time out | Required. Pre-filled with now, editable. |
| Technician | Shown, read-only — the signed-in user. **Never sent.** |
| Equipment hours | Optional integer, ≥ 0. Pre-filled from the asset's current reading if the synced row carries one. |
| N.O.P | Optional integer, ≥ 0. |
| Fault | Optional text. |
| Work done | Optional text. |
| Notes | Optional text. |
| Client name | Text. Required by step 3. |
| Job card no | Optional text. |

Text limits match the server's column limits (taken from the Go source when the
plan is written). The checks mirror `JobCardInput.Validate` and
`BookInInput.Validate` — **the phone is never stricter than the server**.

**Step 3 — Signatures.** Technician, then client. The client's name is
pre-filled from *Client name* and editable; editing it updates the form value.
Reuses the certificate signature pad and its export size. Messages render
inside the signature sheet, never as a `SnackBar` behind it.

**Save** is enabled only when step 2 is valid, both signatures are drawn and the
client's name is non-empty. Save enqueues, kicks a drain, and returns to the
dashboard with *"Saved — waiting to sync"* (or the existing amber *No
connection — N still queued*).

Every `FilledButton` in these screens is bounded (`Expanded` or not in a `Row`).

### Worklist

The signed-in technician's **captured** work orders, newest first, from two
sources merged in Dart:

- **Synced:** `Repair` where `RepairTechID = me`; then `RepairDetail` for those
  track ids, separately, **with a timeout**; keep only rows whose card has
  `RepairDetailType = 3`. Assets for display fetched separately and attached in
  Dart. **No joins over PowerSync tables.** If the card query times out, the
  synced part cannot be filtered to captures, so it is not shown: the list shows
  the queued entries with *"Synced work orders still loading — pull to retry"*.
  Never an endless spinner, and never book-in rows let through unfiltered.
- **On the phone:** `upload_queue` work-order entries, each *Waiting to sync*
  or *Set aside — {server's message}*.
- **No duplicates:** a queue entry whose mobile id is present as
  `RepairMobileID` in synced rows is not shown.

Row: WO number (or *Pending*), date in, machine (equipment type, serial,
hospital), type of work, status.

### Detail

Read-only: the step 2 fields and the status. Signatures shown only when this
phone holds them (it captured the job); otherwise *"Signed on another device or
at the office"*.

A set-aside job shows the server's message and:
- `invalid` → **Fix and resend**: reopens the form at the named field, keeping
  the mobile id; Save replaces the queue payload.
- anything else → stays, with **Discard** behind a confirm. Nothing deletes it
  automatically.

## 2. Data and upload

### No new local tables

A pending job lives in `upload_queue`; a synced job lives in PowerSync. The only
migration is **019**: drop `work_orders`, `work_order_status_history`,
`work_order_photos`, `work_order_signatures` (from migration 001). Those tables
were behind tiles disabled in every released build. The `change_log` table is
not touched by this work; only the work-order code that writes to it goes.

### `WorkOrderUpload`

Beside `CertificateUpload` in `lib/sync/upload/`. Holds the mobile id (uuid v4
made at Save), the step 2 values, both PNGs (padded base64) and the client's
name. `toJson` / `fromJson` for the queue payload; `toBatch()` produces exactly:

1. `SyncUploadOp.capture` — `{table: Repair, mobile_id, action: capture, data}`
2. `SyncUploadOp.sign` (Repair, tech)
3. `SyncUploadOp.sign` (Repair, client, client_name)

The existing `SyncUploadOp.sign` is certificate-only today; it gains a table.
**No technician field exists on any op.**

The queue must be able to tell a work-order payload from a certificate payload
(a `kind` in the payload); the worker dispatches on it.

### Worker

The same `UploadWorker.drain()`, one batch per job, oldest first.

- **`enforces` gate:** a work-order batch is sent only if the server's
  `enforces` contains `capture_action` and `job_sign_action`. Otherwise the
  entry stays pending with *"Server not ready for work orders"* and the drain
  continues with other entries.
- **Applied:** archive first, then delete the queue row (the 017 rule). The
  server's `assigned` gives the number; nothing is written locally — the row
  arrives through PowerSync carrying `RepairMobileID`.
- **422:** set aside with `reason`, `message`, and `field` / `track_id` when
  present. **A refusal on a batch carrying a job is never retired** — see the
  CLAUDE.md rule on refusals that lose work.
- **Network failure / 5xx:** retryable, same backoff as certificates. A resend
  is safe because the server treats a known mobile id as a replay.

## 3. Removal

Delete `lib/features/work_orders/` entirely, its tests, the dashboard's SQL over
`work_orders`, and any `change_log` writes for work orders. New code lives in
`lib/features/work_orders/` again, written fresh against PowerSync.

### Dashboard

A capture is completed the moment it is applied, so nothing synced is pending.

- **Pending Work Orders** = work-order entries in `upload_queue` (waiting or set
  aside).
- **Captured this month** = the technician's synced captured jobs with date in
  this calendar month.
- The donut and the Overdue / Pending / WIP tiles are removed.

## 4. Testing

Written test first. `flutter test` and `flutter analyze` clean.

- `WorkOrderUpload`: JSON round trip; `toBatch()` order capture → tech → client,
  one mobile id throughout, padded base64, no technician field anywhere.
- Form: each required field refuses empty with the server's wording; PM never
  offered; Save disabled until both signatures and a client name.
- `enforces` gate: either key missing → stays queued, nothing sent.
- Results: applied → archived then deleted; `invalid` → set aside with field;
  `open_work_order` / `asset_on_loan` / `asset_inactive` / `not_found` → set
  aside, never deleted; transport failure then resend → no second job.
- Worklist merge: queued + synced, no duplicates; book-in and other
  technicians excluded; card query timeout shows queued entries and the
  loading message, no book-in rows.
- Open-WO check: status 9 excluded, null status counts, `RepairRequest = 2`
  excluded.
- Widget tests pump the real `appTheme`.
- Migration 019 on a v18 database drops the four tables and leaves
  `upload_queue` / `upload_archive` intact.

**On a phone (the user), after the Go actions are on `demo`, as Athi:**

1. Capture with signal → number, Worklist, desktop shows it captured, completed,
   both signatures.
2. Capture with data off → *Waiting to sync* → sends itself on signal.
3. Capture on a machine with a booked-in WO open → warning, then set aside with
   the server's reason.

## Dependencies and order

The Flutter work can be built and unit-tested before the Go actions exist —
the `enforces` gate keeps it from sending. Phone testing waits on the Go
session's checklist in `docs/go-requirements-work-order-capture.md`.
