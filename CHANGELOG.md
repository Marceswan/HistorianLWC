# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog, and this project adheres to Semantic Versioning.

## [Unreleased] - Major Automation Release
### 🚀 New Automation Features
- **Automatic Remote Site Settings Deployment**: System detects missing settings and auto-deploys via `RemoteSiteDeploymentJob`
- **Automatic Historian Object Creation**: Objects created on-demand when configurations are saved using `HistorianMetadataJob`
- **Automatic Trigger Deployment**: System generates and deploys Apex triggers on source objects for seamless change tracking
- **Smart Object Detection**: Enhanced existence validation using `Schema.getGlobalDescribe()` for accuracy
- **Async Processing**: All metadata operations handled asynchronously to avoid callout limitations

### ✅ Core Features Completed
- Initial SFDX scaffold with LWCs, Apex services, CMDT types
- Vendored mdapi (Apex + VF assets + static resources)
- LibrarianLWC admin interface with enhanced config management
- **Read-only protection** for DeveloperName and Label fields to prevent upsert conflicts
- **Soft delete functionality** for configuration deactivation instead of permanent deletion
- Enhanced config editing with proper CMDT value mapping
- Comprehensive debug logging throughout all services for troubleshooting

### 📚 Documentation Updates
- Updated mdapi instructions to reflect automation features
- Enhanced PROJECT_PLAN.md with current status and completed milestones
- Improved README.md with automation highlights and zero-config setup instructions
- Updated all documentation to remove references to manual setup steps

