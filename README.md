# HistorianLWC

HistorianLWC is a Salesforce package that records field changes for any object using a configurable, Flow-based architecture. Admins define what to track via Custom Metadata Types (CMDT), and the package stores change rows in a per-object Historian custom object (e.g., `Account_Historian__c`). The package features automatically deployed Record-Triggered Flows that call Invocable Actions for optimal performance, reliability, and maintainability.

## 🔄 **Flow-Based Architecture**
- **Record-Triggered Flows**: Automatically deployed Flows fire on record updates
- **Invocable Actions**: `HistorianHelper.captureHistoricalChanges()` processes change detection
- **Centralized Logic**: All change detection handled by `HistorianChangeService`
- **No Apex Triggers**: Eliminates trigger deployment complexity and ZIP packaging issues

## Features
- **🚀 Full Automation**: Zero-configuration setup with automatic Remote Site Settings and historian object deployment
- **⚡ Flow-Based Tracking**: Record-Triggered Flows automatically call Invocable Actions for change detection
- **🔄 Reliable Deployment**: Flows deploy via Metadata API without complex ZIP packaging requirements
- **⚡ High Performance**: Centralized `HistorianChangeService` processes all change detection logic efficiently
- **🔧 Configurable Tracking**: Track all fields or specific fields per object via CMDT configuration
- **📦 Per-object Historian Storage**: Stores field changes with complete details (field, prior/new values, changed on/by)
- **🎛️ LibrarianLWC Management**: Admin interface for config management with automatic Historian object creation
- **🤖 Automatic Flow Deployment**: System generates and deploys Record-Triggered Flows on configured objects
- **🔍 Smart Object Detection**: Uses Schema.getGlobalDescribe() for accurate metadata validation
- **⚙️ Bundled mdapi wrapper**: Admin Visualforce tools for setup/validation and troubleshooting

## Project Structure
- `force-app/main/default/lwc/` — `librarianLwc` (admin UI), `historianRecordDisplay` (record page component).
- `force-app/main/default/classes/` — **Core Classes**:
  - `HistorianHelper` — Invocable Action for Flow integration
  - `HistorianChangeService` — Centralized change detection and storage logic
  - `HistorianConfigAdminService` — Configuration management service
  - `HistorianMetadataJob` — Async metadata deployment job (now deploys Flows)
  - `FlowDeploymentService` — Flow generation and deployment utilities
  - `FlowDetectionService` — Flow existence and status detection
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
   - Record-Triggered Flow deployment for automatic change tracking
3) Verify connectivity (optional): Use `remotesitepage` and `metadatabrowser` Visualforce pages for troubleshooting

## Usage
- **Configuration Management**: Use LibrarianLWC to create/edit configurations for any SObject
- **Automatic Provisioning**: Historian objects and Record-Triggered Flows are automatically created when configs are saved
- **Flow-Based Architecture**: Generated Flows call the `HistorianHelper` Invocable Action:
  ```
  Record Update → Record-Triggered Flow → HistorianHelper.captureHistoricalChanges() → HistorianChangeService
  ```
- **Centralized Logic**: All change detection logic handled by `HistorianChangeService` class
- **Record Display**: Use `historianRecordDisplay` LWC component on Lightning Record Pages to show historical data

## 🔧 Advanced Features
- **🔄 Flow-Based Architecture**: Record-Triggered Flows call Invocable Actions for reliable change tracking
- **🚀 Real-time Deployment**: One-click Flow deployment with immediate feedback and verification
- **🏗️ Automatic Provisioning**: Historian objects and Flows are created on-demand - no manual setup
- **⚡ Optimized Performance**: Single `HistorianChangeService` class processes all change tracking logic efficiently
- **🔧 Flexible Configuration**: Support for both "All Fields" and "Per Field" tracking modes
- **🌐 Zero-config Remote Sites**: Automatic mdapi connectivity setup without manual intervention
- **🔍 Robust Object Detection**: Uses Schema.getGlobalDescribe() for accurate metadata validation
- **🛡️ Read-only Protection**: Critical fields protected from editing to prevent upsert conflicts
- **♻️ Soft Delete**: Configurations can be deactivated rather than permanently deleted
- **⚡ Async Processing**: All metadata operations handled asynchronously to avoid callout limitations
- **📊 Record Page Integration**: Display historical data directly on Lightning Record Pages
- **✅ Enhanced Verification**: Comprehensive deployment status tracking and Flow verification
- **🎯 No ZIP Packaging**: Flows deploy directly via Metadata API without complex ZIP creation

## Development
- Source API version: 61.0.
- mdapi details: see `docs/mdapi_instructions.md`. Visualforce admin tools: `docs/mdapi_assets.md`.
- Run Apex tests: `sf apex run test -o historian`.

## License
This project vendors certinia/apex-mdapi. Review upstream license before packaging.