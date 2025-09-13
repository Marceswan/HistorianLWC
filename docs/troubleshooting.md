# Troubleshooting

Common issues and how to resolve them.

## Remote Site Settings / mdapi Callouts
- Symptom: Metadata API operations fail with callout errors.
- Expected: Remote Site Settings are created automatically.
- Action:
  - Open the org and navigate to the `remotesitepage` VF page to create the Remote Site if needed.
  - Confirm the Remote Site points to your My Domain and is Active.
  - Re‑try the operation; background jobs handle callouts asynchronously.

## Historian Object Not Created
- Symptom: No `<Object>_Historian__c` exists after saving a config.
- Action:
  - Wait for `HistorianMetadataJob` to complete; check Apex Jobs.
  - Confirm the config is Active and the object API name is valid.
  - Run Apex tests for `HistorianMetadataJob` and review logs for errors.

## Trigger Not Firing / No History Rows
- Symptom: Updates occur but no history entries are created.
- Action:
  - Validate that the trigger deployment finished successfully (Apex Jobs / debug logs).
  - Ensure the user has permissions to write to `<Object>_Historian__c`.
  - Confirm fields are within the configured tracking scope (AllFields vs PerField).

## mdapi Timeout or Large Changes
- Symptom: Timeouts or partial state during large metadata operations.
- Action:
  - Retry after reducing batch size; allow async jobs to run.
  - Check org limits and active Apex jobs to avoid contention.

## LWC UI Not Showing Data
- Symptom: Timeline component renders but is empty.
- Action:
  - Ensure at least one change has been captured on the record.
  - Verify the Historian object exists and has rows related to the record.
  - Check component visibility on the Lightning page and profile permissions.

## Scratch Org Issues
- Symptom: Deploy errors on fresh scratch org.
- Action:
  - Recreate the scratch org and re‑deploy.
  - Ensure `sourceApiVersion` matches class meta (61.0+).

