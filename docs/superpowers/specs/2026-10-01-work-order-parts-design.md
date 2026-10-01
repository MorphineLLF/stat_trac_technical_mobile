# Work Orders — parts used (design)

**Date:** 2026-10-01
**Status:** approved in conversation ("will change after if needed")
**Builds on:** `2026-10-01-work-orders-capture-design.md`
**Go side:** `docs/go-requirements-work-order-parts.md` — the user's Go session.

## Intent

A technician capturing a work order records the parts used on it. The user's
rules: **pick from the register, or type the line if it is not there**; **no
pricing on the phone**. This is "Parts" on the desktop's Work Order tab
(`RepairPart`), **not Spares** (part requests) and **not the Inventory
screen** — the dashboard's Inventory button is untouched.

## Screens

**Job card (step 2) gains a "Parts used" section**, below the existing fields:

- A list of lines: number / description, quantity, a remove button.
- **Add part** → a picker over the synced `Part` register (parts only), searched
  by number or description, sorted by number. **"Type it instead"** opens two
  boxes, item code and description (one or the other required).
- Then **quantity**: > 0, decimals allowed.
- No prices anywhere.

Fix and resend keeps the lines. The detail screen lists the parts: from the
queued payload for a job on the phone, from synced `RepairPart` for a synced
one (no joins; fetched separately with a timeout, degrading to "parts not
loaded").

## Data and upload

- `WorkOrderJob` gains `parts: List<PartUsed>` (`partId?`, `partNo`,
  `description`, `qty`). `toWire()` adds `"parts": [...]` only when non-empty:
  `{"part_id", "qty"}` for a picked line, `{"part_no", "description", "qty"}`
  for a typed one.
- Validation mirrors the server: a line needs a part id, or a code or a
  description; `qty > 0`. Code ≤ 50, description ≤ 100 characters.
- **Gate:** a `WorkOrderUpload` whose capture carries parts is sent only when
  `enforces` lists `capture_parts` (same probe-per-drain rule as the existing
  gate). A job without parts is unaffected.
- No new local tables. `Part` and `RepairPart` come from the regenerated
  `lib/sync/powersync_schema.dart` (copied from the Go repo, not hand-edited).

## Out of scope

Prices, stock levels, Spares / part requests, the Inventory screen, editing
parts after Save, barcode scanning of parts.

## Testing

`flutter test` / `flutter analyze` clean. Unit: wire shape for picked and typed
lines, no `parts` key when empty, validation messages, the `capture_parts`
gate for jobs with and without parts. Data source: the picker's search SQL and
the `RepairPart` read against plain SQLite tables of the same names. Widget
(real `appTheme`, 384 dp): add a picked line, add a typed line, remove a line,
quantity refused at 0. Phone check by the user after the Go deploy.

## Order

The Go change first (it also supplies the regenerated schema the phone needs
for the picker). The phone can build the form, wire and gate before that, but
the picker and the detail list wait on the schema.
