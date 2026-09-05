// ─────────────────────────────────────────────────────────────────────────────
// COPIED VERBATIM from the Go repository. Do not hand-edit this file.
//
//   source: C:\Delphi\GitHub_Stat_Trac_Go\docslutter-sync-schema.dart
//   copied: 2026-09-05
//
// It is generated from the live database and a captured sync stream. If a
// column changes, regenerate it there and re-copy — do not patch it here, or
// the two will drift and the drift will be invisible until a field sync fails.
//
// test/sync/powersync_schema_test.dart guards the properties this app depends
// on, so a regeneration that breaks one of them fails the build rather than
// the technician's device.
// ─────────────────────────────────────────────────────────────────────────────

// GENERATED from the live database and a captured sync stream, 2026-09-05.
// Source of truth: information_schema on the demo database, cross-checked
// against 166,277 rows actually emitted by PowerSync. Do not hand-edit — if a
// column changes, regenerate.
//
// HOW THE TYPES WERE CHOSEN. Not from the Postgres catalogue alone: every
// mapping below was confirmed against what PowerSync really put on the wire.
//   integer, smallint, boolean          -> column.integer   (boolean arrives 0/1)
//   numeric                             -> column.text      ("125896.00", a STRING)
//   date, time, timestamp, timestamptz  -> column.text       (ISO 8601)
//   varchar, char, text, uuid, jsonb    -> column.text
//   bytea                               -> OMITTED, see below
//
// numeric being text is the one that will bite: parse it, never assume a num.
//
// THE id COLUMN IS IMPLICIT. PowerSync gives every table a text `id`; do not
// declare it. The sync rules alias each table's real key to it
// ("AssetID" AS id), and the key is ALSO present as its own column below, so
// `AssetID` and `id` hold the same value — one as int, one as text.
//
// SIGNATURES AND PHOTOGRAPHS ARE NOT HERE. Eight bytea columns exist on these
// tables and PowerSync delivers every one of them as null — measured, not
// assumed: the database holds 3,796 technician signatures on TestCertificate
// and the stream carried none. Declaring them would produce a column that is
// always null, which is worse than its absence. Binary transport is a separate
// mechanism and is not designed yet.

import 'package:powersync/powersync.dart';

const schema = Schema([
  // Asset — the technician's work (bucket: by_hospital)
  // key AssetID, 63 columns
  Table('Asset', [
    Column.integer('AssetID'),                  // integer
    Column.text('AssetManufacturer'),           // character varying
    Column.text('AssetModel'),                  // character varying
    Column.text('AssetHospital'),               // character varying
    Column.text('AssetBarcode'),                // character varying
    Column.text('AssetHospitalGroup'),          // character varying
    Column.text('AssetLocation'),               // character varying
    Column.integer('AssetHours'),               // integer
    Column.text('AssetLotNo'),                  // character varying
    Column.text('AssetSoftwareVer'),            // character varying
    Column.text('AssetAccessories'),            // character varying
    Column.integer('AssetWarrantyPeriod'),      // integer
    Column.text('AssetWarrantyDateStart'),      // date
    Column.text('AssetWarrantyEndDate'),        // date
    Column.integer('AssetServicePeriod'),       // integer
    Column.text('AssetRegion'),                 // character varying
    Column.text('AssetModelType'),              // character varying
    Column.text('AssetEquipmentType'),          // character varying
    Column.text('AssetSerialNo'),               // character varying
    Column.text('AssetNextServiceDate'),        // date
    Column.text('AssetLastServiceDate'),        // date
    Column.integer('AssetType'),                // integer
    Column.text('AssetLoanDateStart'),          // date
    Column.text('AssetLoanDateEnd'),            // date
    Column.integer('AssetModuleType'),          // integer
    Column.text('AssetManufactureDate'),        // date
    Column.text('AssetNotes'),                  // character varying
    Column.text('AssetCondition'),              // character varying
    Column.integer('AssetLoan'),                // integer
    Column.integer('AssetActive'),              // integer
    Column.integer('AssetServicePlan'),         // integer
    Column.text('AssetServicePlanExpDate'),     // date
    Column.text('AssetServicePlanContract'),    // character varying
    Column.text('AssetDeliverDate'),            // date
    Column.text('AssetCommissionDate'),         // date
    Column.text('AssetPurchaseOrder'),          // character varying
    Column.text('AssetInvoiceNo'),              // character varying
    Column.text('AssetPurchasePrice'),          // numeric
    Column.text('AssetCommissionCert'),         // character varying
    Column.integer('AssetDemo'),                // integer
    Column.integer('AssetRisk'),                // integer
    Column.integer('AssetTestEquipment'),       // integer
    Column.integer('AssetCondemned'),           // integer
    Column.integer('AssetPlacing'),             // integer
    Column.text('AssetMake'),                   // character varying
    Column.text('AssetCountry'),                // character varying
    Column.text('AssetCompany'),                // character varying
    Column.integer('AssetPMschedule'),          // integer
    Column.text('AssetServicePlanStartDate'),   // date
    Column.text('AssetServicePlanValue'),       // numeric
    Column.text('AssetServicePlanDescrption'),  // character varying
    Column.text('AssetUserName'),               // character varying
    Column.integer('AssetUserID'),              // integer
    Column.text('AssetUserDate'),               // date
    Column.text('AssetImageID'),                // character
    Column.integer('AssetLiveSpan'),            // integer
    Column.integer('AssetDepreciation'),        // integer
    Column.text('AssetCustomerCode'),           // character varying
    Column.integer('AssetInstrument'),          // integer
    Column.text('AssetHospitalGroupType'),      // character varying
    Column.text('AssetHospitalAssetNo'),        // character varying
    Column.text('AssetOwner'),                  // character varying
    Column.text('SyncUpdatedAt'),               // timestamp with time zone
  ]),

  // AssetPmTask — the technician's work (bucket: by_hospital)
  // key PmTaskID, 21 columns
  Table('AssetPmTask', [
    Column.integer('PmTaskID'),                   // integer
    Column.integer('PmAssetID'),                  // integer
    Column.integer('PmTaskType'),                 // integer
    Column.text('PmTaskDescription'),             // character varying
    Column.integer('PmTaskStatus'),               // integer
    Column.text('PmTaskScheduleDate'),            // date
    Column.text('PmTaskDetailDescription'),       // character varying
    Column.text('PmTaskIntervalType'),            // character varying
    Column.integer('PmTaskIntervalTypeID'),       // integer
    Column.text('PmTaskMeterReading'),            // numeric
    Column.integer('PmTaskInterval'),             // integer
    Column.text('PmTaskNote'),                    // character varying
    Column.text('PmTaskMeterUnit'),               // character varying
    Column.text('PmTaskMeterReadingNext'),        // numeric
    Column.text('PmTaskMeterInterval'),           // numeric
    Column.integer('PmTaskActive'),               // integer
    Column.text('PmTaskMeterIntervalType'),       // character varying
    Column.integer('PmTaskMeterIntervalTypeID'),  // integer
    Column.integer('PmTaskWorkOrder'),            // integer
    Column.text('SyncHospital'),                  // character varying
    Column.text('SyncUpdatedAt'),                 // timestamp with time zone
  ]),

  // Repair — the technician's work (bucket: by_hospital)
  // key RepairTrackID, 31 columns; 4 bytea omitted: RepairTechSignature, RepairClientSignature, RepairDeconBySig, RepairDeconCheckBySig
  Table('Repair', [
    Column.integer('RepairTrackID'),        // integer
    Column.text('RepairDate'),              // date
    Column.integer('RepairEquipHours'),     // integer
    Column.integer('RepairAssetID'),        // integer
    Column.text('RepairLocation'),          // character varying
    Column.text('RepairContactPerson'),     // character varying
    Column.text('RepairContactPhone'),      // character varying
    Column.text('RepairAccessories'),       // character varying
    Column.text('RepairFault'),             // character varying
    Column.text('RepairCondition'),         // character varying
    Column.integer('RepairType'),           // integer
    Column.integer('RepairStatus'),         // integer
    Column.text('RepairBroughtIn'),         // character varying
    Column.text('RepairRmaNo'),             // character varying
    Column.text('RepairTech'),              // character varying
    Column.text('RepairDeliverBy'),         // character varying
    Column.text('RepairHospital'),          // character varying
    Column.text('RepairNote'),              // character varying
    Column.integer('RepairPriority'),       // integer
    Column.integer('RepairRequest'),        // integer
    Column.integer('RepairPmTaskID'),       // integer
    Column.integer('RepairTechID'),         // integer
    Column.text('RepairPmMeterReading'),    // numeric
    Column.text('RepairClientName'),        // character varying
    Column.text('RepairClientDate'),        // date
    Column.text('RepairTimeIn'),            // time without time zone
    Column.text('RepairDeconByName'),       // character varying
    Column.text('RepairDeconCheckByName'),  // character varying
    Column.text('SyncUpdatedAt'),           // timestamp with time zone
    Column.text('SyncHospital'),            // character varying
    Column.text('RepairMobileID'),          // character varying
  ]),

  // RepairDetail — the technician's work (bucket: by_hospital)
  // key RepairDetailJobID, 36 columns; 2 bytea omitted: RepairDetailClientSignature, RepairDetailTechSignature
  Table('RepairDetail', [
    Column.text('RepairDetailDate'),             // date
    Column.integer('RepairDetailTrackID'),       // integer
    Column.integer('RepairDetailAssetID'),       // integer
    Column.text('RepairDetailJobCard'),          // character varying
    Column.text('RepairDetailWork'),             // character varying
    Column.integer('RepairDetailStatus'),        // integer
    Column.text('RepairDetailTech'),             // character varying
    Column.text('RepairDetailQouteNo'),          // character varying
    Column.integer('RepairDetailMileage'),       // integer
    Column.text('RepairDetailLabour'),           // numeric
    Column.text('RepairDetailTravel'),           // numeric
    Column.text('RepairDetailMileageRate'),      // numeric
    Column.text('RepairDetailLabourRate'),       // numeric
    Column.text('RepairDetailTravelRate'),       // numeric
    Column.text('RepairDetailOrderNo'),          // character varying
    Column.text('RepairDetailNote'),             // character varying
    Column.text('RepairDetailCertificate'),      // character varying
    Column.integer('RepairDetailCompleted'),     // integer
    Column.text('RepairDetailDateIN'),           // date
    Column.integer('RepairDetailJobID'),         // integer
    Column.text('RepairDetailFault'),            // character varying
    Column.integer('RepairDetailHrs'),           // integer
    Column.text('RepairDetailPMValueStart'),     // numeric
    Column.text('RepairDetailInvoice'),          // character varying
    Column.integer('RepairDetailTechID'),        // integer
    Column.integer('RepairDetailType'),          // integer
    Column.text('RepairDetailClient'),           // character varying
    Column.text('RepairDetailPMValueEnd'),       // numeric
    Column.integer('RepairDetailPmTaskID'),      // integer
    Column.integer('RepairDetailManualWoType'),  // integer
    Column.integer('RepairDetailNop'),           // integer
    Column.text('RepairDetailTimeOut'),          // time without time zone
    Column.text('RepairDetailTimeIn'),           // time without time zone
    Column.text('SyncHospital'),                 // character varying
    Column.text('SyncUpdatedAt'),                // timestamp with time zone
    Column.text('RepairDetailMobileID'),         // character varying
  ]),

  // RepairProgress — the technician's work (bucket: by_hospital)
  // key ProgressID, 12 columns
  Table('RepairProgress', [
    Column.integer('ProgressID'),       // integer
    Column.integer('ProgessTrackID'),   // integer
    Column.integer('ProgressAssetID'),  // integer
    Column.text('ProgressDate'),        // date
    Column.text('ProgressWorkDone'),    // character varying
    Column.text('ProgressHrs'),         // numeric
    Column.text('ProgressTech'),        // character varying
    Column.integer('ProgressStatus'),   // integer
    Column.integer('ProgressTechID'),   // integer
    Column.text('SyncHospital'),        // character varying
    Column.text('SyncUpdatedAt'),       // timestamp with time zone
    Column.text('ProgressMobileID'),    // character varying
  ]),

  // TestCertificate — the technician's work (bucket: by_hospital)
  // key TestCertificateID, 44 columns; 2 bytea omitted: TestTechSignature, TestClientSignature
  Table('TestCertificate', [
    Column.integer('TestCertificateID'),        // integer
    Column.integer('TestAssetID'),              // integer
    Column.text('TestDate'),                    // date
    Column.integer('TestCertType'),             // integer
    Column.text('TestTech'),                    // character varying
    Column.integer('TestHrs'),                  // integer
    Column.text('TestCertificateDescription'),  // character varying
    Column.text('TestCertificateNotes'),        // character varying
    Column.integer('TestCertPatientSafe'),      // integer
    Column.text('TestNextService'),             // date
    Column.integer('TestWoNo'),                 // integer
    Column.integer('TestType'),                 // integer
    Column.integer('TestTechID'),               // integer
    Column.integer('TestJobID'),                // integer
    Column.integer('TestAnalyserAssetID'),      // integer
    Column.text('TestAnalyserCalDate'),         // date
    Column.text('TestAnalyserSerialNo'),        // character varying
    Column.text('TestAnalyserModel'),           // character varying
    Column.text('TestAnalyserManufacturer'),    // character varying
    Column.text('TestJobcardNo'),               // character varying
    Column.text('TestServiceInterval'),         // character varying
    Column.text('TestServiceType'),             // character varying
    Column.integer('TestServiceID'),            // integer
    Column.text('TestServiceDescription'),      // character varying
    Column.integer('TestTotalTest'),            // integer
    Column.integer('TestTotalDone'),            // integer
    Column.text('TestTime'),                    // time without time zone
    Column.integer('TestAnalyserAssetID2'),     // integer
    Column.text('TestAnalyserCalDate2'),        // date
    Column.text('TestAnalyserSerialNo2'),       // character varying
    Column.text('TestAnalyserModel2'),          // character varying
    Column.text('TestAnalyserManufacturer2'),   // character varying
    Column.integer('TestAnalyserAssetID3'),     // integer
    Column.text('TestAnalyserCalDate3'),        // date
    Column.text('TestAnalyserSerialNo3'),       // character varying
    Column.text('TestAnalyserModel3'),          // character varying
    Column.text('TestAnalyserManufacturer3'),   // character varying
    Column.text('TestClientNameSignature'),     // character varying
    Column.text('TestNoteTerms'),               // character varying
    Column.text('TestDocNo'),                   // character varying
    Column.integer('TestCertChart'),            // integer
    Column.text('SyncHospital'),                // character varying
    Column.text('SyncUpdatedAt'),               // timestamp with time zone
    Column.text('TestMobileID'),                // character varying
  ]),

  // TestOutput — the technician's work (bucket: by_hospital)
  // key TestOutPutID, 15 columns
  Table('TestOutput', [
    Column.integer('TestOutPutID'),       // integer
    Column.integer('TestOutputCertID'),   // integer
    Column.integer('TestOutputAssetID'),  // integer
    Column.text('TestDescriptionID'),     // character varying
    Column.text('TestDescription'),       // character varying
    Column.text('TestValue'),             // character varying
    Column.text('TestActualValue'),       // character varying
    Column.text('TestNote'),              // character varying
    Column.text('TestNotes'),             // character varying
    Column.integer('TestPass'),           // boolean
    Column.integer('TestFail'),           // boolean
    Column.integer('TestNA'),             // boolean
    Column.text('SyncHospital'),          // character varying
    Column.text('SyncUpdatedAt'),         // timestamp with time zone
    Column.text('TestOutputMobileID'),    // character varying
  ]),

  // TestTemplateName — reference lists (bucket: global)
  // key TestTemplateNameID, 18 columns
  Table('TestTemplateName', [
    Column.integer('TestTemplateNameID'),       // integer
    Column.text('TestTemplateName'),            // character varying
    Column.text('TestTemplateCertName'),        // character varying
    Column.text('TestTemplateTestEquipQty'),    // numeric
    Column.integer('TestTemplateCustomerSig'),  // integer
    Column.integer('TestTemplateType'),         // integer
    Column.integer('TestTemplateEditDate'),     // integer
    Column.integer('TestTemplateNextService'),  // integer
    Column.text('TestTemplateDocNo'),           // character varying
    Column.text('TestTemplateNote'),            // character varying
    Column.integer('TestTemplateISOStatus'),    // integer
    Column.integer('TestTemplateISOtype'),      // integer
    Column.text('TestTemplateISOnote'),         // character varying
    Column.text('TestTemplateISORev'),          // numeric
    Column.text('TestTemplateISORevDate'),      // date
    Column.text('TestTemplateISOissueDate'),    // date
    Column.text('TestTemplateISOdepartment'),   // character varying
    Column.integer('TestTemplateChart'),        // integer
  ]),

  // TestTemplate — reference lists (bucket: global)
  // key TestTemplateID, 17 columns
  Table('TestTemplate', [
    Column.integer('TestTemplateID'),             // integer
    Column.integer('TestTempCertificateNameID'),  // integer
    Column.text('TestTempDescriptionID'),         // character varying
    Column.integer('TestTempDescriptionNo'),      // integer
    Column.text('TestTempDescription'),           // character varying
    Column.text('TestTempNotes'),                 // character varying
    Column.text('TestTempValue'),                 // character varying
    Column.text('TestTempActualValue'),           // character varying
    Column.integer('TestTempPass'),               // boolean
    Column.integer('TestTempFail'),               // boolean
    Column.integer('TestTempNA'),                 // boolean
    Column.integer('TestTempChart'),              // integer
    Column.text('TestTempSetPoint'),              // numeric
    Column.text('TestTempLeeway'),                // numeric
    Column.text('TestTempUnit'),                  // character varying
    Column.text('TestTempTolLow'),                // numeric
    Column.text('TestTempTolHigh'),               // numeric
  ]),

  // ComboStatus — reference lists (bucket: global)
  // key StatusID, 3 columns
  Table('ComboStatus', [
    Column.integer('StatusID'),        // integer
    Column.text('StatusDescription'),  // character varying
    Column.text('StatusPriority'),     // character varying
  ]),

  // ComboHospital — shared with the rep app (bucket: by_hospital)
  // key HospitalID, 8 columns
  Table('ComboHospital', [
    Column.text('Hospital'),              // character varying
    Column.text('HospitalGroup'),         // character varying
    Column.text('HospitalRegion'),        // character varying
    Column.integer('HospitalID'),         // integer
    Column.text('HospitalCountry'),       // character varying
    Column.text('HospitalCompany'),       // character varying
    Column.text('HospitalCustomerCode'),  // character varying
    Column.text('HospitalGroupType'),     // character varying
  ]),

  // HospitalUsage — usage figures, read only (bucket: by_hospital_id)
  // key UsageID, 13 columns
  Table('HospitalUsage', [
    Column.integer('UsageID'),          // integer
    Column.integer('UsageHospitalID'),  // integer
    Column.integer('UsageProductID'),   // integer
    Column.integer('UsageYear'),        // smallint
    Column.integer('UsageMonth'),       // smallint
    Column.text('UsageQuantity'),       // numeric
    Column.text('UsageNote'),           // character varying
    Column.text('UsageUpdatedAt'),      // timestamp without time zone
    Column.integer('UsageActive'),      // integer
    Column.text('UsageUnitPrice'),      // numeric
    Column.integer('UsageShowPrice'),   // integer
    Column.text('UsageInvoiceNo'),      // character varying
    Column.text('UsageOrderNo'),        // character varying
  ]),

  // IssueReport — shared with the rep app (bucket: by_hospital)
  // key IssueReportID, 14 columns
  Table('IssueReport', [
    Column.integer('IssueReportID'),  // integer
    Column.text('MobileIssueID'),     // character varying
    Column.integer('UserID'),         // integer
    Column.text('Hospital'),          // character varying
    Column.integer('AssetID'),        // integer
    Column.integer('IssueType'),      // smallint
    Column.integer('Severity'),       // smallint
    Column.text('Description'),       // text
    Column.text('Location'),          // character varying
    Column.integer('Status'),         // smallint
    Column.text('CreatedAt'),         // timestamp with time zone
    Column.text('UpdatedAt'),         // timestamp with time zone
    Column.text('AccountMobileID'),   // character varying
    Column.text('PhotoPath'),         // character varying
  ]),

  // IssueReportHistory — shared with the rep app (bucket: by_hospital)
  // key IssueReportHistoryID, 11 columns
  Table('IssueReportHistory', [
    Column.integer('IssueReportHistoryID'),      // integer
    Column.integer('IssueReportID'),             // integer
    Column.integer('ChangedByUserID'),           // integer
    Column.integer('OldStatus'),                 // smallint
    Column.integer('NewStatus'),                 // smallint
    Column.text('AdminReply'),                   // text
    Column.text('ResolutionNotes'),              // text
    Column.text('ChangedAt'),                    // timestamp with time zone
    Column.text('IssueReportHistoryMobileID'),   // character varying
    Column.text('IssueReportHistoryPhotoPath'),  // character varying
    Column.text('IssueReportHistoryHospital'),   // character varying
  ]),

  // SalesVisit — shared with the rep app (bucket: by_hospital)
  // key SalesVisitID, 11 columns
  Table('SalesVisit', [
    Column.text('SalesVisitID'),            // uuid
    Column.text('SalesVisitAccountID'),     // uuid
    Column.text('SalesVisitDate'),          // date
    Column.integer('SalesVisitPurpose'),    // smallint
    Column.text('SalesVisitContactIDs'),    // jsonb
    Column.text('SalesVisitSummary'),       // text
    Column.integer('SalesVisitOutcome'),    // smallint
    Column.text('SalesVisitFollowUpDate'),  // date
    Column.text('SalesVisitCreatedAt'),     // timestamp with time zone
    Column.text('SalesVisitUpdatedAt'),     // timestamp with time zone
    Column.text('SalesVisitHospital'),      // text
  ]),

  // SalesAccount — the rep's own accounts (bucket: by_user)
  // key AccountID, 19 columns
  Table('SalesAccount', [
    Column.integer('AccountID'),                // integer
    Column.text('AccountMobileID'),             // character varying
    Column.integer('AccountUserID'),            // integer
    Column.integer('AccountFacilityID'),        // integer
    Column.text('AccountName'),                 // character varying
    Column.text('AccountFacilityType'),         // character varying
    Column.text('AccountAddress'),              // character varying
    Column.text('AccountProvince'),             // character varying
    Column.integer('AccountBeds'),              // integer
    Column.integer('AccountDeviceCount'),       // integer
    Column.text('AccountCurrentCMMS'),          // character varying
    Column.integer('AccountProcurementRoute'),  // integer
    Column.integer('AccountPipelineStage'),     // integer
    Column.real('AccountGpsLat'),               // double precision
    Column.real('AccountGpsLng'),               // double precision
    Column.text('AccountNotes'),                // text
    Column.text('AccountCreatedAt'),            // timestamp without time zone
    Column.text('AccountUpdatedAt'),            // timestamp without time zone
    Column.text('AccountServerCreatedAt'),      // timestamp without time zone
  ]),

  // SalesAccountDeleted — the rep's own accounts (bucket: by_user)
  // key AccountID, 3 columns
  Table('SalesAccountDeleted', [
    Column.integer('AccountID'),      // integer
    Column.text('DeletedAt'),         // timestamp without time zone
    Column.integer('AccountUserID'),  // integer
  ]),

  // SupportStatus — reference lists (bucket: global)
  // key SupportStatusID, 5 columns
  Table('SupportStatus', [
    Column.integer('SupportStatusID'),      // integer
    Column.text('SupportStatusName'),       // character varying
    Column.integer('SupportStatusClosed'),  // integer
    Column.integer('SupportStatusOrder'),   // integer
    Column.integer('SupportStatusActive'),  // integer
  ]),

  // SupportPriority — reference lists (bucket: global)
  // key SupportPriorityID, 4 columns
  Table('SupportPriority', [
    Column.integer('SupportPriorityID'),      // integer
    Column.text('SupportPriorityName'),       // character varying
    Column.integer('SupportPriorityOrder'),   // integer
    Column.integer('SupportPriorityActive'),  // integer
  ]),

  // SupportProgress — reference lists (bucket: global)
  // key SupportProgressID, 10 columns
  Table('SupportProgress', [
    Column.text('SupportProgressDate'),       // date
    Column.text('SupportProgressTime'),       // time without time zone
    Column.text('SupportProgressMessage'),    // character varying
    Column.integer('SupportProgressSupID'),   // integer
    Column.integer('SupportProgressStatus'),  // integer
    Column.integer('SupportProgressUserID'),  // integer
    Column.text('SupportProgressUserName'),   // character varying
    Column.integer('SupportProgressID'),      // integer
    Column.text('SupportProgressMobileID'),   // character varying
    Column.text('SupportProgressUpdatedAt'),  // timestamp without time zone
  ]),

]);
