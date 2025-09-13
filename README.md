# HistorianLWC

HistorianLWC is a Salesforce package that provides comprehensive field change tracking for any object using a configurable, metadata‑driven architecture. Administrators define what to track via Custom Metadata Types (CMDT), and the package stores change history in per‑object Historian custom objects (for example, `Account_Historian__c`).

The system provisions what it needs on demand: historian objects, change‑capture entry points (Apex triggers), and supporting metadata. An admin LWC (LibrarianLWC) manages configuration, and a record page LWC renders a timeline of changes.

## 🔄 Architecture Overview
- **Change capture entry**: Automatically deployed Apex triggers on configured objects capture before/after values.
- **Record‑Triggered Flows (optional)**: Flows can call invocables when used in custom processes.
- **Invocable actions**: `HistorianHelper.captureHistoricalChanges()` provides Flow integration for custom flows.
- **Centralized logic**: `HistorianChangeService` computes diffs and writes Historian rows.
- **Metadata automation**: `HistorianMetadataJob` and mdapi utilities create Historian objects and fields as needed.

## Features
- **🚀 Full Automation**: Zero-configuration setup with automatic Remote Site Settings and historian object deployment
- **🧩 Automatic Triggers**: Generates and deploys Apex triggers to capture changes reliably
- **⚡ Flow Integration**: Optional record‑triggered flows or custom flows can call invocables
- **🔄 Reliable Deployment**: Components deploy via Metadata API without complex ZIP packaging
- **⚡ High Performance**: Centralized `HistorianChangeService` processes all change detection logic efficiently
- **🔧 Configurable Tracking**: Track all fields or specific fields per object via CMDT configuration
- **📦 Per-object Historian Storage**: Stores field changes with complete details (field, prior/new values, changed on/by)
- **🎛️ LibrarianLWC Management**: Admin interface for config management with automatic Historian object creation
- **📊 Timeline Display**: Beautiful timeline view component for displaying change history on record pages
- **🤖 Automatic Metadata Provisioning**: System creates objects, fields, and deploys triggers as needed
- **🔍 Smart Object Detection**: Uses Schema.getGlobalDescribe() for accurate metadata validation
- **⚙️ Bundled mdapi wrapper**: Admin Visualforce tools for setup/validation and troubleshooting

## Project Structure
- `force-app/main/default/lwc/` — Lightning Web Components:
  - `librarianLwc` — Admin UI for managing historian configurations
  - `historianRecordDisplay` — Timeline component for displaying history on record pages
  - `historianFlowEditor` — Flow property editor for custom Flow integration

- `force-app/main/default/classes/` — **Core Classes**:
  - `HistorianHelper` — Invocable Action for Flow integration
  - `HistorianChangeService` — Centralized change detection and storage logic
  - `HistorianConfigAdminService` — Configuration management service
  - `HistorianMetadataJob` — Async metadata deployment job (deploys Flows and objects)
  - `FlowDeploymentService` — Flow generation and deployment utilities
  - `FlowDetectionService` — Flow existence and status detection
  - `HistorianConfigService` — Configuration utilities
  - `MdapiUtil` — Metadata API wrapper utilities
  - `metadata/MetadataService*` — Third-party metadata API wrapper
  - `HistorianTriggerDeployer` — Trigger generation and deployment helpers

- `force-app/main/default/objects/` — Custom Metadata Types:
  - `Historian_Config__mdt` — Main configuration object
  - `Historian_Field_Config__mdt` — Field-level configuration

- `force-app/main/default/pages|components|staticresources` — mdapi admin assets
- Docs: `PROJECT_PLAN.md`, `docs/mdapi_instructions.md`, `docs/mdapi_assets.md`

See `docs/architecture.md` for a deeper component map and data model.

## Setup
**🚀 Fully Automated Setup - No Manual Configuration Required!**

1) Deploy to an org (scratch org example):
   ```bash
   sf org create scratch -f config/project-scratch-def.json -a historian
   sf project deploy start -o historian
   ```

2) **That's it!** The system automatically handles:
   - Remote Site Settings deployment for mdapi connectivity
   - Historian object creation when you save configurations
   - Record-Triggered Flow deployment for automatic change tracking

3) Verify connectivity (optional): Use `remotesitepage` and `metadatabrowser` Visualforce pages for troubleshooting

Alternative deployment to a sandbox or dev org:
```bash
sf org login web -a myOrg
sf project deploy start -o myOrg
```

## Usage

### Configuration Management
1. Navigate to the **LibrarianLWC** app to create/edit configurations for any SObject
2. Select the object you want to track
3. Choose tracking mode: "All Fields" or "Specific Fields"
4. Save configuration - the system automatically creates historian objects and deploys Flows

### Viewing History
Add the **historianRecordDisplay** component to any Lightning Record Page to display field change history in a beautiful timeline view with:
- Collapsible entries showing old and new values
- User attribution with clickable links to profiles
- Multiple display styles: Timeline, Datatable, or Compact Cards
- Automatic detection of the parent record context

### Change Capture Flow
Typical end‑to‑end path:
```
Record Update → Apex Trigger → HistorianChangeService → <Object>_Historian__c row(s)
```
Optional Flow integration for custom processes:
```
Record Update → Record‑Triggered Flow → HistorianHelper.captureHistoricalChanges()
```

## 🔧 Advanced Features
- **🔄 Change Capture**: Auto‑deployed triggers capture before/after values reliably
- **🚀 Real-time Deployment**: One‑click provisioning with immediate feedback and verification
- **🏗️ Automatic Provisioning**: Historian objects, fields, and triggers are created on‑demand
- **⚡ Optimized Performance**: Single `HistorianChangeService` class processes all change tracking logic efficiently
- **🔧 Flexible Configuration**: Support for both "All Fields" and "Per Field" tracking modes
- **🌐 Zero-config Remote Sites**: Automatic mdapi connectivity setup without manual intervention
- **🔍 Robust Object Detection**: Uses Schema.getGlobalDescribe() for accurate metadata validation
- **🛡️ Read-only Protection**: Critical fields protected from editing to prevent upsert conflicts
- **♻️ Soft Delete**: Configurations can be deactivated rather than permanently deleted
- **⚡ Async Processing**: All metadata operations handled asynchronously to avoid callout limitations
- **📊 Record Page Integration**: Display historical data directly on Lightning Record Pages with timeline view
- **✅ Enhanced Verification**: Comprehensive deployment status tracking and Flow verification
- **🎯 No ZIP Packaging**: Deploys directly via Metadata API without complex ZIP creation
- **🎨 Beautiful UI**: Modern timeline interface with expand/collapse functionality and hover effects

## Development
- Source API version: 61.0
- mdapi details: see `docs/mdapi_instructions.md`
- Visualforce admin tools: `docs/mdapi_assets.md`
- Run Apex tests: `sf apex run test -o historian`
- Test coverage requirement: ≥85% for all Apex classes

Recommended local setup and commands are documented in `docs/development.md`.

## Repository Structure
```
force-app/
  main/default/
    classes/
    lwc/
    objects/
    pages/ | components/ | staticresources/
config/
docs/
```

## Troubleshooting
Common root causes and resolutions are captured in `docs/troubleshooting.md` (for example, Remote Site Setting issues, mdapi timeouts, or historian object provisioning delays).

## FAQ
See `docs/faq.md` for answers to common questions (for example, how this differs from native Field History Tracking, performance considerations, and packaging behavior).

## Current Status
✅ **Production Ready** - All core features implemented and tested:
- Admin configuration UI (LibrarianLWC)
- Automatic Flow and object deployment
- Change tracking via Invocable Actions
- Timeline display component with multiple styles
- Full test coverage for Apex classes

## License
This project vendors certinia/apex-mdapi. Review upstream license before packaging.

## Contributing
Please review `CONTRIBUTING.md` for coding standards, commit conventions, PR guidelines, and test requirements (≥85% Apex coverage). Update `README.md` and `CHANGELOG.md` with user‑facing changes.
