# Stat Trac Go — parts used on a captured work order

**For:** a Stat Trac Go session in `E:\Stat_Trac_Go`.
**From:** the Flutter app, 2026-10-01. Builds on `capture` (`docs/go-requirements-work-order-capture.md`).
**Flutter design:** `docs/superpowers/specs/2026-10-01-work-order-parts-design.md` in the app repo.

The phone adds **parts used** (`RepairPart`, the Work Order tab's Parts grid —
not Spares) to a captured work order. **No pricing on the phone**: cost is 0,
the office prices it.

## 1. Sync the `Part` register down — global bucket

Parts only (`coalesce("PartType", 1) = 1`), these columns only — no stock, no
cost, no selling price:

`PartID`, `PartNumber`, `PartDescription`, `PartType`.

## 2. Sync `RepairPart` down — by hospital, like `Repair`

So the phone can show the parts on a synced work order. Columns:
`RepairPartSerialID` (key), `RepairPartTrackID`, `RepairPartNo`,
`RepairPartDescription`, `RepairPartQty`, `RepairPartType`, `RepairPartID`.
No cost or total columns.

Regenerate `docs/flutter-sync-schema.dart` so the phone can copy it.

## 3. `capture` accepts `parts`

```json
{"table":"Repair","mobile_id":"<uuid>","action":"capture",
 "data":{ ...the existing capture fields...,
          "parts":[
            {"part_id":412,"qty":2},
            {"part_no":"FUSE-5A","description":"Fuse 5A","qty":1.5}
          ]}}
```

- Each line goes through `AddPartUsed` **in the same transaction as the
  capture**, with `Cost = 0`.
- `part_id` given → a picked line; the register's number, description and
  bucket win (as `AddPartUsed` already does). No `part_id` → a typed line,
  `part_no` and/or `description` required.
- `qty` > 0, decimals allowed.
- `parts` absent or empty → exactly today's capture.
- Refusals: 422 `invalid` with `field` `parts[<index>].<name>` (e.g.
  `parts[1].qty`); an unknown `part_id` → `invalid`, `field` `parts[<index>].part_id`.
- **Replay** (mobile id already raised) runs nothing, parts included.
- **No pricing fields** — `cost` / `total` sent by a device are refused.

## 4. `enforces`: add `capture_parts`

The phone sends a job that carries parts only when `enforces` lists
`capture_parts`. Jobs without parts keep going as today.

## Done when

- [ ] `Part` (4 columns, parts only) and `RepairPart` (7 columns) on the sync stream, schema regenerated
- [ ] a capture with picked and typed lines writes `RepairPart` rows at cost 0, in one transaction
- [ ] a refused line refuses the whole batch with its `field`
- [ ] a replay adds no second set of parts
- [ ] `enforces` lists `capture_parts`; handover doc updated; deployed to `demo`
