# Certificate PDF Generation — Delphi Changes

**Date:** 2026-06-04  
**Status:** Working ✅

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
(resolves to `{FilesFolderPath}CompanyLogo.jpg` — check `FilesFolderPath` in the Stat Trac ServerModule config on the production server)

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

### FastReport dataset connection ✅ resolved 2026-06-04

The `.fr3` template references two datasets:
- `DataSet="CertDataset1"` / `DataSetName="Certification"`
- `DataSet="CertDataset2"` / `DataSetName="Analyser"`

Correct approach (confirmed working 2026-06-04 — all cert IDs):

```pascal
// 1. Create wrappers BEFORE LoadFromFile
LCertDS := TfrxDBDataSet.Create(LOwner);
LCertDS.Name     := 'CertDataset1';
LCertDS.UserName := 'Certification';
LCertDS.DataSet  := LCertQ;

LAnalyserDS := TfrxDBDataSet.Create(LOwner);
LAnalyserDS.Name     := 'CertDataset2';
LAnalyserDS.UserName := 'Analyser';
LAnalyserDS.DataSet  := LAnalyserQ;

LReport := TfrxReport.Create(LOwner);
LReport.LoadFromFile(PDF_TEMPLATE);

// 2. LoadFromFile creates stub TfrxDataSetItems with DataSet=nil.
//    Find them by UserName and wire to the live wrappers.
var LCertItem := LReport.DataSets.Find('Certification');
if Assigned(LCertItem) then LCertItem.DataSet := LCertDS;

var LAnalyserItem := LReport.DataSets.Find('Analyser');
if Assigned(LAnalyserItem) then LAnalyserItem.DataSet := LAnalyserDS;
```

**Why this works:** The .fr3 `<Datasets>` section is a reference list, not serialized components. `LoadFromFile` calls `TfrxReportDataSets.Add(AName)` for each entry, producing stubs where `DataSet = nil`. `TfrxDBDataSet.Create(LReport)` only sets Delphi ownership — it does NOT register the dataset in `LReport.DataSets`. The correct API is `LReport.DataSets.Find(UserName)` which returns a `TfrxDataSetItem` whose published `DataSet` property can be set directly.

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

- Implement `POST /certificates/:id/email` in Horse API (SMTP send — see spec `docs/superpowers/specs/2026-06-03-certificate-pdf-design.md`)
