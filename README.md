# HistorianLWC

HistorianLWC is a Salesforce package that records field changes for any object using a configurable model. Admins define what to track via Custom Metadata Types (CMDT), and the package stores change rows in a per-object Historian custom object (e.g., `Account_Historian__c`). It includes a management LWC (LibrarianLWC), a Flow Invocable action (HistorianHelper) with a custom property editor LWC, and the Apex Metadata API (mdapi) wrapper to create metadata at runtime.

## Features
- **🚀 Full Automation**: Zero-configuration setup with automatic Remote Site Settings and historian object deployment
- **Configurable Tracking**: Track all fields or specific fields per object via CMDT configuration
- **Per-object Historian Storage**: Stores field changes with complete details (field, prior/new values, changed on/by)
- **LibrarianLWC Management**: Admin interface for config management with automatic Historian object creation
- **Automatic Trigger Deployment**: System generates and deploys Apex triggers on source objects
- **Flow Integration**: Invocable action (HistorianHelper) with custom property editor for Flow builders
- **Smart Object Detection**: Uses Schema.getGlobalDescribe() for accurate metadata validation
- **Bundled mdapi wrapper**: Admin Visualforce tools for setup/validation and troubleshooting

## Project Structure
- `force-app/main/default/lwc/` — `librarianLwc`, `historianFlowEditor` (stubs).
- `force-app/main/default/classes/` — `HistorianHelper`, `HistorianConfigService`, `HistorianMetadataService`, `HistorianMetadataJob`, `HistorianChangeService`, `MdapiUtil`, plus `metadata/MetadataService*`.
- `force-app/main/default/objects/` — `Historian_Config__mdt`, `Historian_Field_Config__mdt`.
- `force-app/main/default/pages|components|staticresources` — mdapi admin assets.
- Docs: `PROJECT_PLAN.md`, `docs/mdapi_instructions.md`, `docs/mdapi_assets.md`.

## Setup
**🚀 Fully Automated Setup - No Manual Configuration Required!**

1) Deploy to an org (scratch org example):
   - `sf org create scratch -f config/project-scratch-def.json -a historian`
   - `sf project deploy start -o historian`
2) **That's it!** The system automatically handles:
   - Remote Site Settings deployment for mdapi connectivity
   - Historian object creation when you save configurations
   - Apex trigger deployment for automatic change tracking
3) Verify connectivity (optional): Use `remotesitepage` and `metadatabrowser` Visualforce pages for troubleshooting

## Usage
- Create configs in CMDT (`Historian_Config__mdt` root; optional `Historian_Field_Config__mdt` children for per-field mode).
- **Historian objects are automatically created** when configs are saved via LibrarianLWC.
- In the LibrarianLWC, create/edit configurations for any SObject. The system automatically provisions the corresponding `<SObject>_Historian__c` object with all required fields.
- In Flow, add the "HistorianHelper" Invocable; in its custom property editor select a config. The action writes change rows to the Historian object.

## 🔧 Advanced Features
- **Automatic Historian Object Provisioning**: No manual object creation required - objects are created on-demand
- **Automatic Trigger Deployment**: System generates and deploys Apex triggers for seamless change tracking
- **Automatic Remote Site Settings**: Zero-configuration mdapi connectivity setup
- **Robust Object Detection**: Uses Schema.getGlobalDescribe() for accurate metadata validation  
- **Read-only Protection**: DeveloperName and Label fields protected from editing to prevent upsert conflicts
- **Soft Delete**: Configurations can be deactivated rather than permanently deleted
- **Async Processing**: All metadata operations handled asynchronously to avoid callout limitations

## Development
- Source API version: 61.0.
- mdapi details: see `docs/mdapi_instructions.md`. Visualforce admin tools: `docs/mdapi_assets.md`.
- Run Apex tests: `sf apex run test -o historian`.

## License
This project vendors certinia/apex-mdapi. Review upstream license before packaging.