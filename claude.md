# HistorianLWC - Project Guidelines

## Project Overview
HistorianLWC is a Salesforce managed package that tracks field changes across objects using configurable Custom Metadata Types (CMDT). It provides admin tools and Flow integration for comprehensive audit trail management.

## Core Components
- **CMDT Model**: `Historian_Config__mdt` (root) + `Historian_Field_Config__mdt` (child)
- **Admin LWC**: `librarianLwc` for configuration management
- **Flow Integration**: `HistorianHelper` Invocable with `historianFlowEditor` property editor
- **Apex Services**: Config, Metadata, and Change services
- **Storage**: Dynamic `<Object>_Historian__c` objects created via Metadata API

## Architecture
```
LibrarianLWC (Admin UI) → CMDT Configs → HistorianHelper (Flow) → Change Tracking → Historian Objects
```

## Development Commands
- Setup: `./scripts/setup.sh`
- Dev: `./scripts/dev.sh` 
- Build: `./scripts/build.sh`
- Test: `./scripts/test.sh`
- Lint: `./scripts/lint.sh`

## Code Standards
- Indentation: 2 spaces (JS/TS), 4 spaces (Python)
- Naming: kebab-case files, PascalCase classes, camelCase variables
- Max line length: 100 characters
- Test coverage: ≥85% for Apex classes

## Dependencies

### Apex Metadata API (apex-mdapi)
- **Source**: https://github.com/certinia/apex-mdapi
- **Location**: `force-app/main/default/classes/metadata/`
- **Purpose**: Programmatic Salesforce metadata management via Apex
- **Key Classes**: `MetadataService.cls`, `MetadataServiceTest.cls`
- **API Version**: 61.0+ required

### Remote Site Settings (Required Setup)
Configure the following Remote Site Setting for metadata API operations:
- **Name**: `Historian_Mdapi`
- **URL**: Your org's My Domain (e.g., `https://yourdomain.my.salesforce.com`)
- **Active**: Checked
- **Setup Path**: Setup → Security → Remote Site Settings

*Note: Managed packages cannot auto-provision Remote Site Settings - document post-install setup*

## Key Integration Patterns

### Metadata API Integration for HistorianLWC
The project uses apex-mdapi for dynamic creation and management of Historian objects:

#### Core Operations
- **Dynamic Object Creation**: `<Object>_Historian__c` objects created on-demand
- **Field Management**: Required fields added to Historian objects automatically  
- **Relationship Setup**: Master-Detail relationships to source objects
- **Validation Rules**: Configure data integrity rules programmatically

#### Standard Implementation Pattern
```apex
// Service initialization
MetadataService.MetadataPort service = MetadataService.createService();
service.endpoint_x = MdapiUtil.metadataEndpoint();

// Object creation
MetadataService.CustomObject histObj = new MetadataService.CustomObject();
histObj.fullName = objectApiName + '_Historian__c';
histObj.label = objectLabel + ' Historian';
// Configure fields, relationships, etc.
```

#### Error Handling & Performance
- **Async Processing**: Use Queueable pattern for metadata operations
- **Idempotent Operations**: Check existing metadata before creation
- **Batch Processing**: Group metadata changes to respect governor limits
- **Authentication**: Handle session-based auth with retry logic

#### Key Service Classes
- `HistorianMetadataService`: Primary orchestration for historian object management
- `MdapiUtil`: Utility methods for metadata API endpoint configuration
- `HistorianMetadataJob`: Queueable implementation for async metadata operations

## Testing Strategy
- Apex unit tests with mdapi error path coverage
- LWC Jest tests for UI logic
- Static analysis: PMD/CPD, ESLint/Prettier

## Security
- No hardcoded secrets
- DML/CRUD/FLS guards in all services
- Minimal package permissions with Custom Permission gates

## Documentation References
- **Detailed apex-mdapi Requirements**: `docs/apex_mdapi_requirements.md`
- **Setup Instructions**: `docs/mdapi_instructions.md`
- **Asset Documentation**: `docs/mdapi_assets.md`

## Work Packages (Sequential)
1. CMDT definitions + samples
2. LibrarianLWC config CRUD
3. Apex services (Config, Metadata, Change)
4. Flow Invocable + property editor
5. mdapi vendoring + async Queueable jobs
6. Packaging + permissions
7. Comprehensive testing
8. Documentation + deployment guides