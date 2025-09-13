# FAQ

## How is this different from Salesforce Field History Tracking?
Native Field History Tracking is limited in number of fields per object and in how data is presented. HistorianLWC stores changes in a dedicated historian object per source object, supports flexible display (timeline/datatable), and provides configurable tracking across many fields.

## What objects and fields are supported?
Standard and custom objects are supported. Most scalar field types are supported. Very large values are preserved in long text fields (`Complete_*` fields) while short summaries are stored in shorter text fields for quick display.

## Does it require Apex triggers or Flows?
Yes—change capture uses auto‑deployed Apex triggers for reliability. Flows can optionally call the invocable for custom processes.

## Is metadata provisioning automatic?
Yes. When you save a configuration, the system ensures the historian object, fields, and trigger exist. Operations are performed asynchronously using the Metadata API.

## What about permissions and security?
The services check CRUD/FLS before DML and SOQL. Use the provided permission set (`Historian_Admin`) during development; production access should be restricted based on your org’s security model.

## How does this impact performance?
The trigger and services are designed to minimize overhead and operate within governor limits. Metadata changes run asynchronously. If you encounter limits, review the troubleshooting guide.

## Can this be packaged?
Yes. Consider excluding or gating Visualforce admin tooling in managed packages, and keep dependency footprints minimal. Review the upstream mdapi license.

## How are values stored for long text fields?
Short display fields (`Prior_Value__c`, `New_Value__c`) store concise values, while full values go to `Complete_Prior_Value__c` and `Complete_New_Value__c` (long text).

## Where can I learn more?
See `docs/architecture.md`, `docs/mdapi_instructions.md`, and `PROJECT_PLAN.md`.

