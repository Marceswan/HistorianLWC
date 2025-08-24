# HistorianLWC – Complete Project Plan

## Objectives
- Deliver a managed package that tracks field changes across Salesforce objects using a configurable model.
- Provide an admin LWC (LibrarianLWC) to define per-object tracking configs via Custom Metadata Types (CMDT).
- Offer a Flow Invocable action (HistorianHelper) with a Custom Property Editor LWC to select configs.
- Create per-object Historian custom objects on-demand using the Apex Metadata API wrapper.

## Scope
- Config model (root + child CMDT), LibrarianLWC UI, HistorianHelper Invocable, property editor LWC, metadata-driven Historian object creation, change capture logic, tests, and packaging.
- Integrate and vendor the certinia/apex-mdapi (MetadataService) for runtime metadata operations.

## Architecture
- CMDT: `Historian_Config__mdt` (root), `Historian_Field_Config__mdt` (child).
- LWC: `librarianLwc` (admin), `historianFlowEditor` (Flow property editor).
- Apex: `HistorianConfigService` (read CMDT), `HistorianMetadataService` (object/field create via mdapi), `HistorianChangeService` (compute diffs + upsert Historian rows), `HistorianHelper` (Invocable wrapper).
- Storage: Per-object `X_Historian__c` (created if missing) with M-D to target record and change details.

## Dependencies
- Apex Metadata API wrapper: https://github.com/certinia/apex-mdapi
  - Vendor `MetadataService.cls` (+ supporting classes) under `force-app/main/default/classes/metadata/`.
  - Ensure API version compatibility with org; target 61.0+.
  - See `docs/mdapi_instructions.md` for setup using Remote Site Settings, usage patterns, and refresh steps.
  - Visualforce assets included (pages/components/staticresources) for admin tooling; see `docs/mdapi_assets.md`.

## Data Model
- Root CMDT `Historian_Config__mdt`
  - `Config_Name__c` (Text), `Object_Api_Name__c` (Text)
  - `Tracking_Style__c` (Picklist: Timeline, Datatable, CompactCards)
  - `Track_Mode__c` (Picklist: AllFields, PerField)
  - `Active__c` (Checkbox)
  - `History_Object_Api__c` (Text)
- Child CMDT `Historian_Field_Config__mdt`
  - `Parent_Config__c` (MetadataRelationship → root)
  - `Field_Api_Name__c` (Text), `Include__c` (Checkbox)

## Historian Object Schema
- API: `<SObjectApiName>_Historian__c` (Label: `<Label> Historian`)
- Fields: M-D to target; `Field_Changed_Label__c` (Text 100), `Field_Changed_Api__c` (Text 100),
  `Prior_Value__c` (LT 4096), `Complete_Prior_Value__c` (LT 32768),
  `New_Value__c` (LT 4096), `Complete_New_Value__c` (LT 32768),
  `Changed_On__c` (DateTime), `Changed_By__c` (Lookup User).

## Flow Integration
- Invocable inputs: `TargetRecordId`, `TargetSObjectApiName` (optional), `ConfigName`.
- Property Editor: LWC lists configs for selected sObject; displays "All fields" or enumerates configured fields.
- Output: created row count, config used, tracked scope.

## Work Packages
1) CMDT definitions + sample records
2) LWC: Librarian config CRUD
3) Apex services: Config, Metadata, Change
4) Invocable + property editor
5) mdapi vendoring + validation (Remote Site Settings)
6) Async mdapi job (Queueable) for object/field creation
7) Packaging + permissions
8) Tests (Apex + LWC)

## Milestones
- M1: CMDT + services skeleton (Week 1)
- M2: LibrarianLWC MVP (Week 2)
- M3: Historian object creation via mdapi (Week 3)
- M4: Invocable + property editor (Week 4)
- M5: Tests, polish, package beta (Week 5)

## Testing & Quality
- Apex unit tests ≥ 85% on changed classes; cover mdapi error paths.
- LWC Jest tests for core UI logic.
- Static analysis: PMD/CPD; ESLint/Prettier for LWC.

## Security & Packaging
- No secrets; guard DML/CRUD/FLS in services.
- Package with minimal perms; add Custom Permission for access.

## Risks
- mdapi governor/timeouts: batch creation, retry, and clear error messaging.
- Field-length truncation: preserve full value in 32k fields; log truncation.
