# Certificate PDF Generation — Delphi Changes

**Date:** 2026-06-03  
**Status:** In progress — FastReport dataset connection under investigation

---

## Overview

On-demand PDF generation for test certificates. The Flutter app calls the Horse API, which proxies to Stat Trac. Stat Trac generates the PDF using FastReport VCL and returns it as base64 JSON. The Flutter app decodes, caches, and opens the PDF with the native Android viewer.

```
Flutter app
  → GET /certificates/:id/pdf  (Horse API, port 9000)
    → GET /cert/pdf/:id?db=Stat_Trac  (Stat Trac UniGUI, port 8077)
      → FastReport generates PDF from TestCertificate + TestOutput + TestAnalyser
      ← { "pdf_b64": "..." }
    ← { "pdf_b64": "..." }
  ← decode base64 → write to cache → open with open_file
```

---

## 1. Stat Trac — `ServerModule.pas`

**Location:** `C:\Delphi\GitHub_Stat_Trac_Delphi10.4\Stat_Trac_Web\ServerModule.pas`

### What was added

`HandleCertPDFRequest` procedure added to `TUniServerModule`. Routes to it via `UniGUIServerModuleHTTPCommand`:

```pascal
if ARequestInfo.Document.StartsWith('/cert/pdf/') then
begin
  HandleCertPDFRequest(ARequestInfo, AResponseInfo);
  Handled := True;
  Exit;
end;
```

### Security

Only accepts calls from `127.0.0.1` or `::1` (localhost only — Horse API is the only caller). No JWT on this endpoint; Horse API validates the JWT before proxying.

### Constants

```pascal
PDF_TEMPLATE = 'C:\Delphi\StatTracTechAPI\templates\test_certificate.fr3';
```

Logo loaded from: `UniServerModule.FilesFolderPath + 'CompanyLogo.jpg'`  
(resolves to `C:\StatMedical\files\CompanyLogo.jpg`)

### SQL queries

**CertPrintQuery** (dataset UserName: `Certification`):
```sql
SELECT * FROM "Company","Asset"
LEFT JOIN "TestOutput"      ON "Asset"."AssetID" = "TestOutputAssetID"
LEFT JOIN "TestCertificate" ON "TestCertificateID" = "TestOutputCertID"
WHERE "TestCertificateID" = :cert_id ORDER BY "TestOutPutID"
```

**AnalyserPrintQuery** (dataset UserName: `Analyser`):
```sql
SELECT * FROM "TestAnalyser" WHERE "AnalyserTestID" = :cert_id
```

### FastReport dataset connection (⚠️ under investigation)

The `.fr3` template references two datasets:
- `DataSet="CertDataset1"` / `DataSetName="Certification"`
- `DataSet="CertDataset2"` / `DataSetName="Analyser"`

Current approach (fix 3 — confirmed generating correct PDF for cert 5030 at 16:21 on 2026-06-03):

```pascal
LReport := TfrxReport.Create(LOwner);
LReport.LoadFromFile(PDF_TEMPLATE);

LCertDS := TfrxDBDataSet.Create(LReport);  // owned by report
LCertDS.Name     := 'CertDataset1';
LCertDS.UserName := 'Certification';
LCertDS.DataSet  := LCertQ;

LAnalyserDS := TfrxDBDataSet.Create(LReport);
LAnalyserDS.Name     := 'CertDataset2';
LAnalyserDS.UserName := 'Analyser';
LAnalyserDS.DataSet  := LAnalyserQ;
```

**Known issue:** Some cert IDs produce a blank 946-byte PDF (datasets not connecting). Investigation ongoing. The exact FastReport API for programmatic dataset registration in this version (2026.2.0) is not yet confirmed.

### Response

```
HTTP 200 application/json
{ "pdf_b64": "<base64 string — no line breaks — TBase64Encoding.Create(0)>" }
```

### New uses clause additions

Interface section: `frxClass`, `frxExportPDF`, `frxDBSet`, `Uni`, `PostgreSQLUniProvider`, `System.IOUtils`, `System.Classes`, `System.NetEncoding`

---

## 2. Horse API — `PDF.Routes.pas`

**Location:** `C:\Delphi\StatTracTechAPI\src\PDF.Routes.pas`

**New file.** Registered in `StatTracTechAPI.dpr`.

### Endpoint

`GET /certificates/:id/pdf`

- JWT required (via `HorseJWT`)
- Extracts `db` claim from JWT → passes as `?db=` query param to Stat Trac
- Proxies to `http://localhost:8077/cert/pdf/:id?db=<db>`
- Forwards Stat Trac's JSON response body unchanged to Flutter

### Constants

```pascal
STAT_TRAC_HOST = 'http://localhost';
STAT_TRAC_PORT = 8077;
```

---

## 3. FastReport Template

**File:** `test_certificate.fr3`  
**Canonical location (Horse API server):** `C:\Delphi\StatTracTechAPI\templates\test_certificate.fr3`  
**Source copy (Flutter repo):** `templates/test_certificate.fr3`

Exported from `TFrmEmailAdd.CertificateReport` (Unit49) in Stat Trac via FastReport Designer → File → Save As.

### Template datasets

| Delphi Name  | UserName        | Data source       |
|---|---|---|
| CertDataset1 | Certification   | CertPrintQuery    |
| CertDataset2 | Analyser        | AnalyserPrintQuery|

### PascalScript events in template

- `CertificationTestTypeOnAfterData` — hides signature section when `TestType <> 1`
- `CertificationTestCertPatientSafeOnAfterData` — sets COMPLIANT/NON-COMPLIANT/INCOMPLETE/VOID text and colour
- `Memo21/25/26OnAfterData` — P/F/N tick marks (Wingdings 2)
- `Memo51OnAfterData` — cert type label (OVP / QA / Commission / Decontamination)
- `CertificationTestNextServiceOnAfterData` — shows N/A when next service date is blank
- `CertificationTestAnalyserSerialNo1OnAfterData` — analyser serial display

---

## 4. What still needs to be done

- Resolve FastReport dataset connection for all cert IDs (investigation in progress)
- Implement `POST /certificates/:id/email` in Horse API (SMTP send — see spec `docs/superpowers/specs/2026-06-03-certificate-pdf-design.md`)
- Remove diagnostic files from `C:\Temp\` on server after testing
