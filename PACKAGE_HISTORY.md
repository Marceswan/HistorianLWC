# HistorianLWC Package History

## Package Information
- **Package Name:** HistorianLWC
- **Package ID:** 0HoWs0000001zMPKAY
- **Namespace:** (none - unmanaged package)
- **Dev Hub:** GSO-Org (marc-zbcx@force.com)

## Version History

### Version 0.1.0.1 - Initial Release
**Released:** September 13, 2025
**Version ID:** 04tWs000000bDazIAE
**Installation URL:** https://login.salesforce.com/packaging/installPackage.apexp?p0=04tWs000000bDazIAE

#### Installation Commands
```bash
# Production/Developer Edition
sf package install --package 04tWs000000bDazIAE --target-org YOUR_ORG_ALIAS --wait 10

# Sandbox
sf package install --package 04tWs000000bDazIAE --target-org YOUR_ORG_ALIAS --wait 10 --installation-key ""
```

#### Features
- **Admin Configuration UI (LibrarianLWC)**: Complete admin interface for managing historian configurations
- **Timeline Display Component**: Beautiful timeline view with collapsible entries for displaying field history
- **Automatic Metadata Provisioning**: Dynamic creation of Historian objects and fields on-demand
- **Flow Integration**: Invocable actions for custom Flow processes
- **Change Tracking Service**: Centralized service for detecting and storing field changes
- **Multiple Display Styles**: Timeline, Datatable, and Compact Cards views
- **CMDT Configuration**: Flexible configuration using Custom Metadata Types

#### Components Included
- **Lightning Web Components:**
  - `librarianLwc` - Admin configuration interface
  - `historianRecordDisplay` - Timeline display component
  - `historianFlowEditor` - Flow property editor

- **Apex Classes:**
  - `HistorianHelper` - Invocable action for Flow integration
  - `HistorianChangeService` - Core change detection and storage
  - `HistorianConfigAdminService` - Configuration management
  - `HistorianMetadataJob` - Async metadata deployment
  - `HistorianTriggerDeployer` - Trigger deployment service
  - `FlowDeploymentService` - Flow generation utilities
  - `FlowDetectionService` - Flow status detection
  - `HistorianConfigService` - Configuration utilities
  - `MdapiUtil` - Metadata API utilities
  - Supporting test classes with >85% coverage

- **Custom Metadata Types:**
  - `Historian_Config__mdt` - Main configuration object
  - `Historian_Field_Config__mdt` - Field-level configuration

- **Custom Objects:**
  - `Historian_Deploy_Result__c` - Deployment tracking

- **Visualforce Pages:**
  - `metadatabrowser` - Metadata browsing utility
  - `HistorianDeploy` - Deployment interface
  - `historiansessionhelper` - Session management

#### Known Issues
- Remote Site Settings must be configured manually post-installation
- Historian objects are created asynchronously on first configuration save

#### Breaking Changes
- None (initial release)

---

## Installation Notes

### Prerequisites
- Salesforce API version 61.0 or higher
- System Administrator profile or equivalent permissions
- Remote Site Settings configuration for metadata API access

### Post-Installation Steps
1. Configure Remote Site Settings:
   - Name: `Historian_Mdapi`
   - URL: Your org's My Domain URL
   - Active: Checked

2. Navigate to the LibrarianLWC app to begin configuration

3. Create your first Historian configuration:
   - Select an object to track
   - Choose tracking mode (All Fields or Specific Fields)
   - Save configuration (triggers automatic object creation)

4. Add the `historianRecordDisplay` component to Lightning Record Pages

### Support
For issues or questions, please create an issue in the GitHub repository.

---

## Future Releases

### Planned for v0.2.0
- Enhanced error handling and recovery
- Bulk change processing optimization
- Additional display styles
- Field-level security enhancements
- Performance improvements for large datasets

### Roadmap
- v0.3.0: Advanced filtering and search capabilities
- v0.4.0: Export functionality (CSV, Excel)
- v0.5.0: Analytics and reporting dashboard
- v1.0.0: Production-ready managed package with namespace

---

## Package Maintenance

### Building New Versions
```bash
# Create new version
sf package version create --package HistorianLWC --installation-key-bypass --wait 20 --target-dev-hub GSO-Org

# List all versions
sf package version list --packages HistorianLWC --target-dev-hub GSO-Org

# Promote to released
sf package version promote --package VERSION_ID --target-dev-hub GSO-Org
```

### Testing Installation
```bash
# Create scratch org for testing
sf org create scratch -f config/project-scratch-def.json -a test-install

# Install package
sf package install --package VERSION_ID --target-org test-install --wait 10

# Open org
sf org open --target-org test-install
```

---

*Last Updated: September 13, 2025*