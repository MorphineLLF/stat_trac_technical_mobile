# Server Deployment Checklist — Certificate PDF Feature

**Date:** 2026-06-03

This checklist covers everything that must be in place on the production server before the PDF endpoint works.

---

## Files to deploy to production server

| # | File | Source | Destination on server | Notes |
|---|---|---|---|---|
| 1 | `test_certificate.fr3` | `templates/test_certificate.fr3` (this repo) | `C:\Delphi\StatTracTechAPI\templates\test_certificate.fr3` | Create the `templates\` folder if it doesn't exist |
| 2 | `StatTracTechAPI.exe` | Build output | Replace running Horse API executable | Rebuild after code changes; includes `PDF.Routes.pas` |
| 3 | Stat Trac app | Build output | Replace running Stat Trac UniGUI exe | Rebuild after `ServerModule.pas` changes |

---

## Configuration changes required before production

| Item | File | Change needed |
|---|---|---|
| `PDF_SECRET` | `ServerModule.pas` | Change from `'pdf-secret-CHANGE-ME'` to a real secret (currently unused — endpoint restricted to localhost) |
| `JWT_SECRET` | `PDF.Routes.pas` | Must match the JWT secret used in `Auth.Routes.pas` |
| SMTP credentials | `Email.Config.pas` (not yet created) | Required before email feature is implemented |
| DB password | `ServerModule.pas` line 106 | `'Cbr900RR'` — confirm this is correct for production DB |

---

## Dependencies on production server

| Dependency | Notes |
|---|---|
| `CompanyLogo.jpg` | Must exist at `{uniServerModule.FilesFolderPath}CompanyLogo.jpg` — check `FilesFolderPath` in the Stat Trac ServerModule config on the production server |
| FastReport VCL runtime | Must be available to Stat Trac app — already present since existing cert printing works |
| PostgreSQL | Already running — no changes needed |

---

## Pre-deployment test sequence

1. On the dev server, hit `http://localhost:8077/cert/pdf/<id>?db=Stat_Trac` directly in a browser — confirm `{"pdf_b64":"..."}` response with large base64 string
2. Hit `http://localhost:9000/certificates/<id>/pdf` with a valid JWT — confirm same JSON
3. From Flutter app, tap **View PDF** on a synced certificate — confirm PDF opens with data

---

## Known open items

- Email endpoint (`POST /certificates/:id/email`) not yet implemented in Horse API
