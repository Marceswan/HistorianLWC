# Apex Metadata API (mdapi) – Usage Guide

- Purpose: Create/update metadata (Custom Objects, Fields, etc.) at runtime for Historian objects.
- Location: `force-app/main/default/classes/metadata/MetadataService*.cls` (vendored from certinia/apex-mdapi).

## Setup (Remote Site Settings)
- Create a Remote Site Setting (Setup → Security → Remote Site Settings):
  - Remote Site Name: `Historian_Mdapi`
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
- `HistorianMetadataService.ensureHistorianObject(objectApi, cfg)`
  - If `<objectApi>_Historian__c` doesn’t exist: create object, M-D to target object, required fields.
  - Idempotent: readDescribe first; only create missing items.
  - Truncation behavior: store full values in 32k fields; store shortened values in 4k fields.

## Limits & Gotchas
- Callouts: Require Remote Site Setting; fail in transactions that disallow callouts.
- Limits: Batch metadata changes; avoid large synchronous create calls.
- Permissions: Running user must have authorizations to deploy metadata via API (Deploy Metadata permission or be in a context with sufficient rights).
- Packaging: Managed packages cannot provision Remote Site Settings; document post-install setup.

## Refreshing Vendor Files
- Source repo: https://github.com/certinia/apex-mdapi
- To update: replace files under `classes/metadata/` with upstream versions; rerun Apex tests.
