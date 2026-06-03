# Certificate PDF Generation & Email — Design Spec

**Date:** 2026-06-03  
**Status:** Approved  
**Scope:** On-demand PDF generation for test certificates via Horse API (FastReport), with device viewing and email delivery.

---

## 1. Overview

A technician who has completed and synced a test certificate can tap **View PDF** or **Email** on the certificate detail screen. The Horse API generates the PDF on-demand using FastReport VCL, returning it as raw bytes (View PDF) or emailing it directly to a user-supplied address (Email). The Flutter app caches downloaded PDFs locally and opens them with the device's native PDF viewer.

---

## 2. Horse API (Delphi)

### 2.1 New endpoints — `Certificates.Routes.pas`

#### `GET /certificates/:id/pdf`

| Item | Detail |
|---|---|
| Auth | JWT required |
| Path param | `:id` = `TestCertificateID` (integer) |
| Response (success) | `200 application/pdf` — raw PDF bytes; `Content-Disposition: attachment; filename="cert-{id}.pdf"` |
| Response (not found) | `404` |
| Response (generation error) | `500` with plain-text error message |

Steps:
1. Validate JWT; extract `db` claim.
2. Load `TestCertificate` row by `:id` (verify it belongs to the authenticated technician or allow any — TBD with business rule; start with no ownership check for simplicity).
3. Load related `TestOutput` rows and `TestAnalyser` rows for the cert.
4. Open FastReport engine, load `templates/test_certificate.fr3`.
5. Populate FastReport datasets (cert header dataset + outputs dataset + equipment dataset).
6. Export to a `TMemoryStream` as PDF using `TfrxPDFExport`.
7. Write stream bytes to HTTP response with correct content type.

#### `POST /certificates/:id/email`

| Item | Detail |
|---|---|
| Auth | JWT required |
| Path param | `:id` = `TestCertificateID` |
| Request body | `{ "to": "recipient@example.com" }` |
| Response (success) | `204 No Content` |
| Response (bad email) | `400` |
| Response (SMTP failure) | `500` with error message |

Steps:
1. Validate JWT and parse body.
2. Validate `to` field is non-empty and contains `@` (basic check; SMTP failure is the real gate).
3. Generate PDF bytes using the same internal procedure as the GET endpoint.
4. Compose `TIdMessage`: from address from `Email.Config.pas`, to address from request, subject `"Test Certificate — {cert description} — {date}"`, body as plain text, PDF as attachment.
5. Send via `TIdSMTP` using config constants.
6. Return 204.

### 2.2 New file — `Email.Config.pas`

Holds SMTP constants (host, port, username, password, from address). Values to be filled in before deployment. Example:

```pascal
const
  SMTP_HOST = 'smtp.example.com';
  SMTP_PORT = 587;
  SMTP_USER = 'noreply@example.com';
  SMTP_PASS = 'CHANGE_ME';
  SMTP_FROM = 'noreply@example.com';
```

### 2.3 FastReport template — `templates/test_certificate.fr3`

To be designed in the FastReport Report Designer. Must display:

- **Header band**: Certificate title, doc no, date, technician name, asset details (equipment type, serial no, hospital, location)
- **Patient safe status**: Compliant / Non-Compliant / Incomplete (colour-coded)
- **Test results band** (repeating): description group header + rows of description / expected value / actual value / Pass / Fail / NA
- **Test equipment section**: one row per `TestAnalyser` record (manufacturer, model, serial no, cal date)
- **Signatures section**: technician signature image + client name + client signature image (if present)
- **Footer band**: page numbers, generation timestamp

Three FastReport datasets fed from Delphi:
- `dsCert` — single-row cert header
- `dsOutputs` — one row per `TestOutput` record
- `dsEquipment` — one row per `TestAnalyser` record

---

## 3. Flutter App

### 3.1 New remote methods — `cert_remote_data_source.dart`

```dart
/// Downloads PDF bytes for [serverId]. Throws on non-200.
Future<Uint8List> fetchCertificatePdf(int serverId);

/// Sends the cert PDF to [toEmail] via server-side SMTP. Throws on non-204.
Future<void> emailCertificate(int serverId, String toEmail);
```

Both use the existing `Dio` client with JWT interceptor.

### 3.2 Certificate detail screen — `certificate_detail_screen.dart`

Two action buttons added to the AppBar `actions` list:

| Button | Icon | Enabled condition |
|---|---|---|
| View PDF | `picture_as_pdf_outlined` | `cert.serverId != null` |
| Email | `email_outlined` | `cert.serverId != null` |

If `serverId == null`, buttons are shown but disabled with a `Tooltip`: `"Sync this certificate first"`.

**View PDF behaviour:**
1. Button shows `CircularProgressIndicator` (replace icon) while loading.
2. Check for cached file: `{cacheDir}/certs/cert-{serverId}.pdf`.
3. If cached → `OpenFile.open(path)` directly.
4. If not cached → `fetchCertificatePdf(serverId)` → write bytes to cache path → `OpenFile.open(path)`.
5. On error → error snackbar.

**Email behaviour:**
1. `showDialog` with `_EmailCertDialog` (see below).

### 3.3 New widget — `_EmailCertDialog`

Private widget within `certificate_detail_screen.dart`:

- Single `TextField` with `keyboardType: TextInputType.emailAddress`, label "Recipient email"
- "Send" `FilledButton` — disabled until text contains `@` and `.` (basic client-side gate)
- On Send: shows inline loading, calls `emailCertificate(serverId, email)`, dismisses dialog, shows snackbar `"Certificate emailed to {email}"`
- On error: shows error snackbar inside dialog context, keeps dialog open

### 3.4 New packages — `pubspec.yaml`

| Package | Purpose |
|---|---|
| `open_file` | Open cached PDF with native Android viewer |
| `path_provider` | Get cache directory (likely already present) |

---

## 4. Data Flow

```
User taps "View PDF"
  │
  ├─ cache hit? ──Yes──► OpenFile.open(cachedPath)
  │
  └─ No ──► GET /certificates/:serverId/pdf (JWT)
              │
              ├─ 200 ──► write to {cacheDir}/certs/cert-{id}.pdf ──► OpenFile.open()
              └─ error ──► error snackbar

User taps "Email"
  │
  └─ _EmailCertDialog
       │
       └─ POST /certificates/:serverId/email { "to": "..." } (JWT)
            │
            ├─ 204 ──► dismiss dialog, success snackbar
            └─ error ──► error snackbar (dialog stays open)
```

---

## 5. Error Handling Summary

| Situation | Behaviour |
|---|---|
| `serverId == null` (pending sync) | Both buttons disabled, tooltip: "Sync this certificate first" |
| Server unreachable / timeout | Error snackbar: "Cannot reach server. Check your connection." |
| FastReport generation failure (500) | Error snackbar: "PDF generation failed — contact your administrator" |
| Invalid / empty email | Send button disabled |
| SMTP failure (500) | Error snackbar with server message |

---

## 6. Out of Scope

- Automatic PDF pre-generation during sync (on-demand only)
- In-app PDF rendering (native viewer only)
- PDF caching invalidation / regeneration (can be added later via long-press)
- Ownership check on PDF endpoint (any authenticated tech can request any cert ID)

---

## 7. Open Items Before Implementation

- [ ] SMTP credentials for `Email.Config.pas` (host, port, user, password, from address)
- [ ] FastReport template layout to be designed in FR designer before Delphi code is wired
- [ ] Confirm `path_provider` is already in `pubspec.yaml`
