# Stat Trac Go — the phone views and emails a work order's job card

**For:** a Stat Trac Go session in `E:\Stat_Trac_Go`.
**From:** the Flutter app, 2026-10-02. Builds on `capture`
(`docs/go-requirements-work-order-capture.md`).

On a synced captured work order (it has a `RepairTrackID`), the technician
taps **View PDF** or **Email** — the same two buttons a certificate has. The
document is the **work order sheet** (`printWorkOrder`, `woDocSheet`), not the
request or the progress report.

**Mirror the certificate exactly.** Same auth (device token as Bearer), same
JSON shapes, same refusal body, same audit row. The phone reuses its
certificate client and email box, so any difference is a second path to keep in
step.

## 1. Let a device token reach three work order routes

Add a `workOrderDocPath` to `handsetPath` in `cmd/stattrac/module_access.go`,
shaped like `certDocPath` — anchored, id must be digits, nothing else under
`/work-order` reachable:

- `GET  /work-order/{digits}/print.pdf`
- `GET  /work-order/{digits}/email`
- `POST /work-order/{digits}/email`

The row scope (`ReadWorkOrder` with `scopeOf(r)`) still bounds what a
technician can read.

## 2. `print.pdf` answers a Bearer caller

The existing `printWorkOrder` can stay as it is for the PDF bytes. A refusal
to a Bearer caller should be the JSON refusal (`wantsJSONRefusal`), not an HTML
page — check that a 404 (out of scope / missing) reaches the phone as
something it can read.

## 3. A JSON email endpoint for one work order

`GET` and `POST /work-order/{id}/email` are today the desktop's compose form
(`emailWorkOrder`, HTML). A Bearer caller needs what `cert_email.go` gives
certificates. Either branch on Bearer inside the existing routes or keep the
desktop handler for cookies — your call; the phone only needs the shapes below.

**GET** — the box's defaults, for the person the token names:

```json
{"cc": "...", "reply_to": "...", "signature": "..."}
```

**POST** — body, unknown fields refused:

```json
{"to": "a@b.co.za", "cc": "...", "reply_to": "...", "subject": "...", "body": "..."}
```

`cc` and `body` left out vs sent empty mean what they mean for certificates
(`fromSender`, `senderCC`).

- Attachment: the **same render `print.pdf` serves** (`ui.WorkOrderSheet…`
  with the same footer) — one work order is one document however it leaves.
- From: the company's; Reply-To: the sender (as certificates).
- Default subject: whatever the desktop's work order email uses today.
- **200:** `{"sent": true, "work_order": <id>, "to": [...]}`
- **Refusals:** the certificate's body and codes — `bad_request`,
  `no_recipient`, `bad_address`, `not_found`, `no_renderer`,
  `not_configured`, `render_failed`, `send_failed`, `unavailable`. Add any
  work-order-specific state refusal (e.g. cancelled) only if the desktop
  already refuses it.
- Audit row on `Repair`, field `Emailed`, after the send — a failed log does
  not un-send.

No `enforces` key: these are not sync operations. A server without this work
refuses the path with a 403 JSON body, and the phone shows its message.

## Done when

- [ ] a device token (rights-6 technician, not an admin) gets the work order sheet PDF for a work order in its scope, and 404 JSON for one outside it
- [ ] GET email returns the sender's cc / reply_to / signature
- [ ] POST email sends the same PDF `print.pdf` serves, writes the audit row, answers 200 JSON
- [ ] no other `/work-order/...` path opens to a device token
- [ ] deployed to `demo`
