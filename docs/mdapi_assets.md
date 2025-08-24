# mdapi Visualforce Assets

This project vendors the Visualforce assets from certinia/apex-mdapi to support admin workflows and testing. They are optional at runtime but useful for setup and troubleshooting.

## Visualforce Pages (force-app/main/default/pages)
- `remotesitepage.page`: Helper UI to create a Remote Site Setting for your My Domain.
- `metadatabrowser.page`: Explore available metadata types and describe results.
- `metadataretrieve.page`: Retrieve metadata ZIPs via mdapi.
- `metadatadeploy.page`: Deploy metadata ZIPs via mdapi.
- `metadatadata.page`: Inspect raw request/response payloads.

## Visualforce Components (force-app/main/default/components)
- `remotesitehelper.component`: Backing logic used by `remotesitepage` to configure Remote Site.
- `zip.component`, `zipEntry.component`, `unzip.component`: Utilities to construct and extract ZIPs when interacting with retrieve/deploy pages.

## Static Resources (force-app/main/default/staticresources)
- `extjs.resource`: UI library used by the browser/retrieve/deploy pages.
- `jszip.resource`: ZIP processing library for VF components.

## Usage Notes
- These assets require the MetadataService classes and a Remote Site Setting to your My Domain.
- In managed packaging, consider excluding these assets from the subscriber package or gating them behind a Custom Permission, as they are primarily admin tools.
- For HistorianLWC, these UIs can validate mdapi connectivity and object/field creation flows during development.
