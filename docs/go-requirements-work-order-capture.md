# Stat Trac Go — what the phone needs for work-order capture

**For:** a Stat Trac Go session in `E:\Stat_Trac_Go`.
**From:** the Flutter app (`Stat_Trac-Technical-app`), 2026-10-01.
**Flutter design:** `docs/superpowers/specs/2026-10-01-work-orders-capture-design.md` in the app repo.

The phone will raise work orders the way the desktop's **capture on site** does
(`CaptureWorkOrderWithCard`, `internal/stats/workorder_capture.go`). **Capture
only — booking in stays on the desktop.** The phone shows only the Work Order
tab (the job card); it never shows or edits WO Request or WO Progress. Every
job is captured offline-first, queued on the phone, and sent through the
existing `POST /{company}/sync/upload` as one batch.

A plain row op on `Repair` / `RepairDetail` would skip the four checks, the
history lines and the completion — the same trap as a certificate marked issued
by writing a column. So the phone needs two **actions**, built the way `issue`
and `sign` were for `TestCertificate`.

---

## 1. `action: "capture"` on `Repair`

```json
{"table":"Repair","mobile_id":"<uuid v4>","action":"capture",
 "data":{"asset_id":1234,
         "work_type":1,
         "date_in":"2026-10-01","time_in":"08:15",
         "date_out":"2026-10-01","time_out":"10:40",
         "fault":"...","work":"...","note":"...",
         "equip_hrs":5120,"nop":1,
         "client_name":"...","job_card_no":"..."}}
```

- Runs `CaptureWorkOrderWithCard` — scope, active, not on loan, no open repair
  work order; raises the work order assigned to the caller; writes the job card
  (`RepairDetailType = 3`); writes the two progress lines; saves the card, which
  completes the work order.
- **The technician comes from the token.** There is no field for it and the
  phone will never send one — the same rule as `TestTech` on certificates.
- **Priority is Medium.** The phone does not show priority.
- `work_type` is one of the repair module's types (1, 2, 3, 4, 6). Never 5 (PM).
- Dates `YYYY-MM-DD`, times `HH:MM`, the same date format as `next_service`.
  `equip_hrs` and `nop` are integers and may be absent. Text fields may be
  empty or absent.
- **Go decides:** the phone has one *Fault* field. Whether it fills
  `BookInInput.Fault`, `JobCardInput.Fault`, or both, is the server's call.
- Writes the uuid to `RepairMobileID` (migration 023) and returns it in
  `assigned`: `{"<uuid>": <RepairTrackID>}`.
- Unknown fields in `data` are refused (400), as on `issue`.

### Replay must create nothing

The phone resends a batch whenever it cannot be sure the last one landed — the
server applied it and the reply was lost. **If a `Repair` with that
`RepairMobileID` already exists, `capture` runs nothing and answers with that
work order's number in `assigned`.** Without this a resend raises a second work
order on the same machine — or, worse, is refused as `open_work_order` against
itself and the phone parks a job that actually landed.

### Refusals — 422, the existing shape

`{"table":"Repair","mobile_id":"...","reason":"...","message":"..."}`, one
refusal refuses the batch, as today.

| reason | when |
|---|---|
| `not_found` | asset unknown **or out of scope** (the existing convention) |
| `asset_inactive` | `AssetActive <> 1` |
| `asset_on_loan` | `notOnLoan` refuses |
| `open_work_order` | `noOpenWorkOrder` refuses — **include `track_id`**, the open work order's number, so the phone can name it |
| `invalid` | `JobCardInput.Validate` / `BookInInput.Validate` — **include `field`** |

Please return the `ValidationError` field names as `field` unchanged; the phone
maps them to its form.

---

## 2. `action: "sign"` on `Repair` — the job card pair

```json
{"table":"Repair","mobile_id":"<the same uuid>","action":"sign",
 "data":{"which":"tech","png":"<base64, standard, padded>"}}
{"table":"Repair","mobile_id":"<the same uuid>","action":"sign",
 "data":{"which":"client","png":"...","client_name":"..."}}
```

- Runs `SaveJobSignature` → `RepairDetailTechSignature` /
  `RepairDetailClientSignature`. **The job card's pair, not the request's**
  (`SaveRequestSignature` is not wanted — the phone has no request).
- Resolves the work order by `RepairMobileID`, **including one raised by a
  `capture` earlier in the same batch** — so `capture` must apply before `sign`
  within a batch, as rows apply before `issue` today.
- `client_name` required on `client`, refused on `tech` — the same as the
  certificate `sign` op.
- **Both signatures are always present.** The phone will not save a job without
  both, so every batch is exactly: capture, sign tech, sign client.

### Replay must not refuse

On a replay (§1: `capture` found the mobile id already there), a signature side
that is already set **is treated as applied, not refused as `already_signed`.**
Otherwise a resend of a batch that fully landed is refused, the phone parks it,
and the technician is told a completed job failed. The CLAUDE.md rule stands
the other way round too: `already_signed` on a batch that carries work and is
**not** a replay means nothing landed, and must stay a refusal.

---

## 3. `enforces`: add `capture_action` and `job_sign_action`

`SyncEnforces` gets two new keys — added, not repurposed. **The phone will not
send a work-order batch until both are in the server's `enforces` list.** Until
then the job stays queued with "Server not ready for work orders". This is the
lesson of the 46 orphaned readings: a stale binary silently drops what it does
not know.

---

## 4. Already confirmed — no change expected

- `Repair` and `RepairDetail` stream in `by_hospital`. The phone filters to the
  signed-in technician (`RepairTechID`) and to captured jobs
  (`RepairDetailType = 3`). Both columns are in the generated schema.
- "Open", answered by the Go session 2026-10-01: a repair work order
  (`RepairRequest = 1`) on the asset whose `coalesce(RepairStatus, 0) <> 9`
  (`workorder_write.go:348`). The phone applies the same test to its synced rows
  as a warning only; the server decides.
- Signatures still do not come down (`bytea`). The phone shows its own copy and
  says "signed on another device" otherwise. Nothing needed now.

---

## 5. Write it into the contract

Add the two shapes, the reason codes and the replay rules to
`docs/sync-client-handover.md` beside `issue` and `sign`, and say which Go
commit enforces them. Then redeploy to `demo` — the phone is tested there with
Athi (user 31), the only `demo` login that can sync.

## Done when

- [ ] `capture` applies, returns `assigned`, and the work order reads on the
      desktop as captured, assigned to the token's user, completed, with both
      progress lines
- [ ] replaying the identical batch creates nothing and is not refused
- [ ] each refusal in §1 returns its reason (and `track_id` / `field`)
- [ ] `sign` on a work order raised earlier in the same batch lands on the job
      card
- [ ] `enforces` lists `capture_action` and `job_sign_action`
- [ ] the handover doc updated and the build deployed to `demo`
