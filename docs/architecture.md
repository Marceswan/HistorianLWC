# Architecture

This document explains how HistorianLWC captures changes, how data is stored, and how the system provisions metadata on demand.

## Components
- LWC
  - `librarianLwc`: Admin UI for configuring tracked objects and fields.
  - `historianRecordDisplay`: Record page component rendering a timeline/datatable of changes.
  - `historianFlowEditor`: Custom property editor for Flow invocables.
- Apex
  - `HistorianChangeService`: Computes diffs and writes Historian rows.
  - `HistorianConfigService`: Reads config from CMDT and validates scope.
  - `HistorianConfigAdminService`: Admin CRUD + provisioning coordination.
  - `HistorianMetadataJob`: Queueable that creates Historian objects/fields.
  - `HistorianTriggerDeployer`: Generates and deploys triggers for change capture.
  - `FlowDeploymentService` / `FlowDetectionService`: Flow generation and verification utilities.
  - `HistorianHelper`: Invocable action for Flow integration.
  - `MdapiUtil` + `MetadataService*`: Apex Metadata API access.
- Data
  - CMDT: `Historian_Config__mdt` (root), `Historian_Field_Config__mdt` (child).
  - Storage: `<SObject>_Historian__c` custom object per source SObject.

## Data Model
Historian Object (per source object):
- Relationship: Master‑Detail to source record
- Change fields:
  - `Field_Changed_Label__c`, `Field_Changed_Api__c`
  - `Prior_Value__c` (short), `Complete_Prior_Value__c` (long)
  - `New_Value__c` (short), `Complete_New_Value__c` (long)
  - `Changed_On__c` (DateTime), `Changed_By__c` (Lookup User)

Config (CMDT):
- Root: name, target object, active, track mode (AllFields or PerField), display style.
- Child: field API name + include flag.

## Change Capture Flow
1) Record update occurs on a configured object.
2) Auto‑deployed Apex trigger reads before/after values and delegates to `HistorianChangeService`.
3) Service compares previous vs new values within configured scope.
4) Service writes one or more Historian rows on `<SObject>_Historian__c`.

Optional Flow integration:
1) Record‑triggered Flow calls `HistorianHelper.captureHistoricalChanges()`.
2) Invocable reuses the same service to write history rows.

## Metadata Provisioning
When a config is saved or first used:
- `HistorianMetadataJob` ensures the historian object exists; creates missing fields and relationships.
- `HistorianTriggerDeployer` ensures a change‑capture trigger exists on the source object.
- Remote Site Settings are created automatically when needed for mdapi operations.

## Error Handling & Limits
- All mdapi operations are asynchronous to avoid callout restrictions.
- Batched operations and idempotent checks minimize retries and partial state.
- Clear error messages and logs aid troubleshooting (see `docs/troubleshooting.md`).

