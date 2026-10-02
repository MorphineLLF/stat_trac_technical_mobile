# Work order — view and email the job card PDF

**Date:** 2026-10-02 · **Go requirements:** `docs/go-requirements-work-order-email.md`

## What

On a **synced** captured work order, the technician can open the job card PDF
and email it to the client — the same two buttons, and the same email box, a
certificate has. The document is the server's work order sheet; the phone
renders nothing.

Decided with the user:

- **Job card PDF**, nothing else.
- **Detail screen only.** No email offer at Save, no queued emails. A job
  that has not synced has no number and cannot be emailed yet.

## Screen

`WorkOrderDetailScreen` app bar gets **View PDF** and **Email** icon buttons.

- Synced (`trackId != null`): enabled.
- Queued: disabled, tooltip "Sync first".

## Server client

`lib/features/work_orders/data/work_order_document_client.dart` —
`WorkOrderDocumentClient`, a copy of `CertDocumentClient` in shape:

- `GET  /{company}/work-order/{id}/print.pdf` — bytes
- `GET  /{company}/work-order/{id}/email` — the box's defaults
- `POST /{company}/work-order/{id}/email` — send

Device token as Bearer, `validateStatus` accepts everything, every outcome a
result, never an exception. No signal → unavailable. A 403 from a server
without the Go work → refused, with the server's message shown.

## Shared pieces move to `lib/core/documents/`

Features never import each other, so what both need moves to core, renamed
neutrally, and the certificate code points at it. **Certificate behaviour does
not change.**

- the result types in `cert_document_result.dart` (`CertPdfResult`,
  `CertEmailResult`, `CertEmailDefaults`, `certEmailFields`, the response
  parsers) → `document_result.dart`, `Doc*` names
- the `_EmailDialog` in `certificate_detail_screen.dart` →
  `email_document_dialog.dart`, public, with a `title` ("Email Certificate" /
  "Email Work Order") and the two callbacks it already takes (load defaults,
  send)
- the open-from-cache PDF code, if it moves cleanly; otherwise each screen
  keeps its own

## PDF cache

`{cacheDir}/work_orders/wo_{id}.pdf`, opened as certificates are. A cached
file opens without signal.

## Tests

- `WorkOrderDocumentClient`: 200 bytes, 403 refusal with message, 404, no
  signal; email 200, 422 refusal with field, defaults.
- Widget (real `appTheme`): buttons enabled on a synced work order, disabled
  on a queued one.
- The existing certificate document and email tests pass unchanged apart from
  imports and names.

## Not in this

Emailing at Save; a queued email; the request or progress documents; a
customer email column (there is none — the address is typed, as for
certificates).
