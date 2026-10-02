# Stat Trac Go — a line on `capture` can say it is a charged rate

**For:** a Stat Trac Go session in `E:\Stat_Trac_Go`.
**From:** the Flutter app, 2026-10-02. Builds on `capture_parts`
(`docs/go-requirements-work-order-parts.md`).

The phone's job card now has two sections, as the desktop's Inventory does:
**Parts** (`PartType` 1) and **Charged rates** (`PartType` 2). Both let the
technician pick from the register or type a line.

Today a typed line has no register row, so `fromRegister` files it under
`PartTypeParts`. A typed charged rate therefore lands in Parts. **No prices
are involved**: a typed line still arrives at nought for the office to price.

## 1. `syncCapturePart` accepts `kind`

```json
{"part_no": "", "description": "Travel 40 km", "qty": 1, "kind": 2}
```

- Optional, integer. Absent means 1, exactly as today.
- **Typed line** (no `part_id`): the line is written with `RepairPartType =
  kind`, not `PartTypeParts`. Pass it as the fallback to `fromRegister`.
- **Picked line**: the register's `PartType` still wins. `kind` is only the
  fallback for a part that has left the register since the phone synced, so
  that line keeps its group.
- Accept 1 to 5 (the column's own comment). Anything else → 422 `invalid`,
  field `parts[<index>].kind`.

The phone sends `kind` only when it is not 1.

## 2. `enforces`: add `capture_part_kind`

A job carrying any line with `kind` is sent only when `enforces` lists
`capture_part_kind`. Jobs without it keep going as today.

## Done when

- [ ] a typed line with `"kind": 2` is written as `RepairPartType` 2, at cost 0
- [ ] a picked line's type is still the register's, whatever `kind` says
- [ ] a picked line whose part has left the register keeps `kind` as its type
- [ ] `kind` 0 or 6 is refused with `parts[<index>].kind`
- [ ] `capture_part_kind` in `enforces`, deployed to `demo`
