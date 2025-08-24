# HistorianLWC

HistorianLWC is a Salesforce package that records field changes for any object using a configurable, lightweight model. Admins define what to track via Custom Metadata Types (CMDT), and the package stores change rows in a per-object Historian custom object (e.g., `Account_Historian__c`). The package features minimal, auto-deployed triggers that delegate all logic to a centralized handler class, ensuring optimal performance and maintainability.

## Features
- **🚀 Full Automation**: Zero-configuration setup with automatic Remote Site Settings and historian object deployment
- **🪶 Lightweight Triggers**: Minimal, auto-deployed triggers delegate all logic to centralized HistorianTriggerHandler
- **⚡ High Performance**: Single centralized handler class processes all change detection logic efficiently
- **🔧 Configurable Tracking**: Track all fields or specific fields per object via CMDT configuration
- **📦 Per-object Historian Storage**: Stores field changes with complete details (field, prior/new values, changed on/by)
- **🎛️ LibrarianLWC Management**: Admin interface for config management with automatic Historian object creation
- **🤖 Automatic Trigger Deployment**: System generates and deploys minimal Apex triggers on configured objects
- **🔍 Smart Object Detection**: Uses Schema.getGlobalDescribe() for accurate metadata validation
- **⚙️ Bundled mdapi wrapper**: Admin Visualforce tools for setup/validation and troubleshooting

## Project Structure
- `force-app/main/default/lwc/` — `librarianLwc` (admin UI), `historianRecordDisplay` (record page component).
- `force-app/main/default/classes/` — **Core Classes**:
  - `HistorianTriggerHandler` — Lightweight centralized change detection handler
  - `HistorianConfigAdminService` — Configuration management service
  - `HistorianMetadataJob` — Async metadata deployment job
  - `TriggerDeploymentService` — Trigger generation and deployment utilities
  - `HistorianConfigService` — Configuration utilities
  - `MdapiUtil` — Metadata API wrapper utilities
  - `metadata/MetadataService*` — Third-party metadata API wrapper
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
- **Configuration Management**: Use LibrarianLWC to create/edit configurations for any SObject
- **Automatic Provisioning**: Historian objects and triggers are automatically created when configs are saved
- **Lightweight Triggers**: Generated triggers contain only 3 lines of code:
  ```apex
  trigger AccountHistorianTrigger on Account (after update) {
      HistorianTriggerHandler.handleAfterUpdate('Account', Trigger.old, Trigger.new);
  }
  ```
- **Centralized Logic**: All change detection logic handled by `HistorianTriggerHandler` class
- **Record Display**: Use `historianRecordDisplay` LWC component on Lightning Record Pages to show historical data

## 🔧 Advanced Features
- **🪶 Lightweight Architecture**: Minimal 3-line triggers delegate to centralized `HistorianTriggerHandler`
- **🏗️ Automatic Provisioning**: Historian objects and triggers are created on-demand - no manual setup
- **⚡ Optimized Performance**: Single handler class processes all change tracking logic efficiently
- **🔧 Flexible Configuration**: Support for both "All Fields" and "Per Field" tracking modes
- **🌐 Zero-config Remote Sites**: Automatic mdapi connectivity setup without manual intervention
- **🔍 Robust Object Detection**: Uses Schema.getGlobalDescribe() for accurate metadata validation
- **🛡️ Read-only Protection**: Critical fields protected from editing to prevent upsert conflicts
- **♻️ Soft Delete**: Configurations can be deactivated rather than permanently deleted
- **⚡ Async Processing**: All metadata operations handled asynchronously to avoid callout limitations
- **📊 Record Page Integration**: Display historical data directly on Lightning Record Pages

## Development
- Source API version: 61.0.
- mdapi details: see `docs/mdapi_instructions.md`. Visualforce admin tools: `docs/mdapi_assets.md`.
- Run Apex tests: `sf apex run test -o historian`.

## License
This project vendors certinia/apex-mdapi. Review upstream license before packaging.