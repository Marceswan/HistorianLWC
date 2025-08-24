# HistorianLWC

HistorianLWC is a Salesforce package that records field changes for any object using a configurable model. Admins define what to track via Custom Metadata Types (CMDT), and the package stores change rows in a per-object Historian custom object (e.g., `Account_Historian__c`). It includes a management LWC (LibrarianLWC), a Flow Invocable action (HistorianHelper) with a custom property editor LWC, and the Apex Metadata API (mdapi) wrapper to create metadata at runtime.

## Features
- Configurable tracking via CMDT (All fields or per-field).
- Per-object Historian storage with key details (field, prior/new values, changed on/by).
- LibrarianLWC to manage configs and trigger Historian object creation.
- Flow Invocable (HistorianHelper) + property editor to pick configs in Flow.
- Bundled mdapi wrapper and admin Visualforce tools for setup/validation.

## Project Structure
- `force-app/main/default/lwc/` — `librarianLwc`, `historianFlowEditor` (stubs).
- `force-app/main/default/classes/` — `HistorianHelper`, `HistorianConfigService`, `HistorianMetadataService`, `HistorianMetadataJob`, `HistorianChangeService`, `MdapiUtil`, plus `metadata/MetadataService*`.
- `force-app/main/default/objects/` — `Historian_Config__mdt`, `Historian_Field_Config__mdt`.
- `force-app/main/default/pages|components|staticresources` — mdapi admin assets.
- Docs: `PROJECT_PLAN.md`, `docs/mdapi_instructions.md`, `docs/mdapi_assets.md`.

## Setup
1) Deploy to an org (scratch org example):
   - `sf org create scratch -f config/project-scratch-def.json -a historian`
   - `sf project deploy start -o historian`
2) Remote Site Setting (required for mdapi callouts):
   - Name: `Historian_Mdapi`; URL: `https://<yourdomain>.my.salesforce.com` (Setup → Security → Remote Site Settings).
3) Verify mdapi connectivity (optional): Open `remotesitepage` and `metadatabrowser` Visualforce pages.

## Usage
- Create configs in CMDT (`Historian_Config__mdt` root; optional `Historian_Field_Config__mdt` children for per-field mode).
- In the LibrarianLWC, enter the SObject API (e.g., `Account`) and click “Ensure Historian Object” to provision `<SObject>_Historian__c`.
- In Flow, add the “HistorianHelper” Invocable; in its custom property editor select a config. The action writes change rows to the Historian object.

## Development
- Source API version: 61.0.
- mdapi details: see `docs/mdapi_instructions.md`. Visualforce admin tools: `docs/mdapi_assets.md`.
- Run Apex tests: `sf apex run test -o historian`.

## License
This project vendors certinia/apex-mdapi. Review upstream license before packaging.

