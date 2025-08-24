# Apex Metadata API (mdapi) – Usage Guide

- Purpose: Create/update metadata (Custom Objects, Fields, etc.) at runtime for Historian objects.
- Location: `force-app/main/default/classes/metadata/MetadataService*.cls` (vendored from certinia/apex-mdapi).

## Setup (Remote Site Settings)
**Automatic Deployment:** Remote Site Settings are now automatically created when the package is deployed or when historian objects are first created. The system will:
- Automatically detect missing or incorrect Remote Site Settings
- Deploy a Remote Site Setting named `Historian_Metadata_API` pointing to your org's domain
- Handle this process asynchronously via the `RemoteSiteDeploymentJob`

**Manual Setup (if needed):** If automatic deployment fails, manually create:
  - Remote Site Name: `Historian_Metadata_API`
  - Remote Site URL: your My Domain, e.g., `https://yourdomain.my.salesforce.com`
  - Active: checked
- Ensure `sourceApiVersion` and class meta are in sync (project uses 61.0).

## Core Patterns
- Create service: `MetadataService.MetadataPort service = MetadataService.createService();`
- Set endpoint to org metadata API: `service.endpoint_x = MdapiUtil.metadataEndpoint();`
- Create object: build `MetadataService.CustomObject` and call `service.createMetadata(new Metadata[]{ obj })`.
- Create field: build `MetadataService.CustomField`; call `createMetadata` similarly.
- Poll async: use `checkStatus(ids)` until `state == 'Completed'`.

## Historian Integration
**Automatic Object Creation:** The system now automatically creates historian objects when configurations are saved:
- `HistorianMetadataService.ensureHistorianObjectAsync(objectApi, cfg)` - Preferred async method
- `HistorianMetadataService.ensureHistorianObject(objectApi, cfg)` - Synchronous fallback
  - If `<objectApi>_Historian__c` doesn’t exist: create object, M-D to target object, required fields.
  - Idempotent: readDescribe first; only create missing items.
  - Truncation behavior: store full values in 32k fields; store shortened values in 4k fields.
  - Creates an accompanying Apex trigger on the source object for automatic change tracking
  - Uses `HistorianMetadataJob` for asynchronous deployment to handle callout requirements
  - Uses `Schema.getGlobalDescribe()` for accurate object existence detection

**Trigger Auto-Deployment:** When historian objects are created, the system automatically generates and deploys Apex triggers on the source objects to capture field changes without manual intervention.

## Limits & Gotchas
- Callouts: Remote Site Settings are now automatically provisioned, but callouts still fail in transactions that disallow them (handled via async jobs)
- Limits: Batch metadata changes; the system uses asynchronous jobs to avoid large synchronous create calls
- Permissions: Running user must have authorizations to deploy metadata via API (Deploy Metadata permission or be in a context with sufficient rights)
- Packaging: Automatic Remote Site Setting deployment handles the managed package limitation
- Async Processing: Object and trigger creation happens asynchronously - check job status or use `HistorianAdminController.isHistorianProvisioned()` to verify completion

## Refreshing Vendor Files
- Source repo: https://github.com/certinia/apex-mdapi
- To update: replace files under `classes/metadata/` with upstream versions; rerun Apex tests.
