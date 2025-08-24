public with sharing class HistorianMetadataJob implements Queueable, Database.AllowsCallouts {
    private String objectApi;
    private HistorianConfigService.ConfigSummary cfg;

    public HistorianMetadataJob(String objectApi, HistorianConfigService.ConfigSummary cfg) {
        this.objectApi = objectApi;
        this.cfg = cfg;
    }

    public void execute(QueueableContext context) {
        System.debug('=== HistorianMetadataJob.execute started ===');
        System.debug('objectApi: ' + objectApi);
        
        if (String.isBlank(objectApi)) {
            System.debug('objectApi is blank, returning');
            return;
        }
        if (Test.isRunningTest()) {
            System.debug('Test is running, returning to avoid callouts');
            return; // Avoid callouts in tests; unit tests validate enqueue only
        }
        
        // Ensure remote site settings are configured before proceeding
        if (!MdapiUtil.ensureRemoteSiteSettings()) {
            System.debug('Remote site settings being deployed, will retry historian creation later');
            return;
        }
        
        String historianApi = objectApi + '_Historian__c';
        System.debug('historianApi: ' + historianApi);
        
        MetadataService.MetadataPort service = MdapiUtil.newService();
        System.debug('MetadataPort service created');

        // Check if object exists using Schema.getGlobalDescribe() for accurate detection
        Boolean exists = false;
        try {
            System.debug('Checking if object exists via Schema.getGlobalDescribe()');
            exists = Schema.getGlobalDescribe().containsKey(historianApi);
            System.debug('Schema.getGlobalDescribe() result - exists: ' + exists);
            
            // Also check via readMetadata for comparison
            System.debug('Also checking via readMetadata for comparison');
            MetadataService.IReadResult rr = service.readMetadata('CustomObject', new String[] { historianApi });
            Boolean metadataExists = (rr != null && rr.getRecords() != null && rr.getRecords().size() > 0);
            String recordCount = (rr != null && rr.getRecords() != null ? String.valueOf(rr.getRecords().size()) : 'null');
            System.debug('readMetadata result - exists: ' + metadataExists + ', records: ' + recordCount);
            
            if (exists != metadataExists) {
                System.debug('WARNING: Schema.getGlobalDescribe() and readMetadata disagree on object existence!');
                System.debug('Using Schema.getGlobalDescribe() result as authoritative');
            }
        } catch (Exception e) {
            System.debug('Exception during object existence check: ' + e.getMessage());
            exists = false;
        }
        List<MetadataService.Metadata> toCreate = new List<MetadataService.Metadata>();

        if (!exists) {
            System.debug('Object does not exist, creating: ' + historianApi);
            MetadataService.CustomObject obj = new MetadataService.CustomObject();
            obj.fullName = historianApi;
            obj.deploymentStatus = 'Deployed';
            obj.description = 'Historian change log for ' + objectApi;
            obj.enableFeeds = false;
            obj.label = objectApi + ' Historian';
            obj.pluralLabel = objectApi + ' Historian';
            obj.sharingModel = 'ReadWrite';
            MetadataService.CustomField nameField = new MetadataService.CustomField();
            nameField.type_x = 'AutoNumber';
            nameField.displayFormat = 'HIST-{000000}';
            nameField.label = 'Name';
            obj.nameField = nameField;
            toCreate.add(obj);
            System.debug('Added custom object to create list: ' + obj.fullName);
        } else {
            System.debug('Object already exists: ' + historianApi);
        }

        // Determine missing fields via readMetadata
        Map<String, MetadataService.Metadata> existingFieldMap = new Map<String, MetadataService.Metadata>();
        List<String> fieldFullNames = new List<String>{
            historianApi + '.Field_Changed_Label__c',
            historianApi + '.Field_Changed_Api__c',
            historianApi + '.Prior_Value__c',
            historianApi + '.Complete_Prior_Value__c',
            historianApi + '.New_Value__c',
            historianApi + '.Complete_New_Value__c',
            historianApi + '.Changed_On__c',
            historianApi + '.Changed_By__c',
            historianApi + '.Parent_Record__c'
        };
        try {
            MetadataService.IReadResult rrf = service.readMetadata('CustomField', fieldFullNames);
            if (rrf != null && rrf.getRecords() != null) {
                for (MetadataService.Metadata rec : rrf.getRecords()) {
                    if (rec != null) existingFieldMap.put(((MetadataService.CustomField)rec).fullName, rec);
                }
            }
        } catch (Exception e) {
            // ignore
        }

        for (String fullName : fieldFullNames) {
            if (existingFieldMap.containsKey(fullName)) continue;
            MetadataService.CustomField f = new MetadataService.CustomField();
            f.fullName = fullName;
            if (fullName.endsWith('.Field_Changed_Label__c')) {
                f.type_x = 'Text'; f.label = 'Field Changed Label'; f.length = 100;
            } else if (fullName.endsWith('.Field_Changed_Api__c')) {
                f.type_x = 'Text'; f.label = 'Field Changed API'; f.length = 100;
            } else if (fullName.endsWith('.Prior_Value__c')) {
                f.type_x = 'LongTextArea'; f.label = 'Prior Value'; f.length = 4000; f.visibleLines = 3;
            } else if (fullName.endsWith('.Complete_Prior_Value__c')) {
                f.type_x = 'LongTextArea'; f.label = 'Complete Prior Value'; f.length = 32768; f.visibleLines = 3;
            } else if (fullName.endsWith('.New_Value__c')) {
                f.type_x = 'LongTextArea'; f.label = 'New Value'; f.length = 4000; f.visibleLines = 3;
            } else if (fullName.endsWith('.Complete_New_Value__c')) {
                f.type_x = 'LongTextArea'; f.label = 'Complete New Value'; f.length = 32768; f.visibleLines = 3;
            } else if (fullName.endsWith('.Changed_On__c')) {
                f.type_x = 'DateTime'; f.label = 'Changed On';
            } else if (fullName.endsWith('.Changed_By__c')) {
                f.type_x = 'Lookup'; f.referenceTo = 'User'; f.label = 'Changed By'; f.relationshipName = 'Changed_By';
            } else if (fullName.endsWith('.Parent_Record__c')) {
                f.type_x = 'Lookup'; f.referenceTo = objectApi; f.label = 'Parent Record'; f.relationshipName = 'Parent_Record';
            }
            toCreate.add(f);
        }

        System.debug('Total metadata components to create: ' + toCreate.size());
        if (!toCreate.isEmpty()) {
            // createMetadata returns SaveResult[] in this mdapi version
            try { 
                System.debug('About to create ' + toCreate.size() + ' metadata components');
                for (MetadataService.Metadata meta : toCreate) {
                    if (meta instanceof MetadataService.CustomObject) {
                        MetadataService.CustomObject obj = (MetadataService.CustomObject) meta;
                        System.debug('Creating CustomObject: ' + obj.fullName + ', label: ' + obj.label);
                    } else if (meta instanceof MetadataService.CustomField) {
                        MetadataService.CustomField fld = (MetadataService.CustomField) meta;
                        System.debug('Creating CustomField: ' + fld.fullName + ', type: ' + fld.type_x);
                    }
                }
                
                MetadataService.SaveResult[] results = service.createMetadata(toCreate); 
                String resultCount = (results != null ? String.valueOf(results.size()) : 'null');
                System.debug('CreateMetadata call completed, results: ' + resultCount);
                
                if (results != null) {
                    for (MetadataService.SaveResult result : results) {
                        if (result.success) {
                            System.debug('Successfully created: ' + result.fullName);
                        } else {
                            System.debug('Failed to create: ' + result.fullName);
                            if (result.errors != null) {
                                for (MetadataService.Error err : result.errors) {
                                    System.debug('Error: ' + err.message + ' (statusCode: ' + err.statusCode + ')');
                                }
                            }
                        }
                    }
                } else {
                    System.debug('CreateMetadata returned null results');
                }
            } catch (Exception e) { 
                System.debug('Exception during createMetadata: ' + e.getMessage());
                System.debug('Exception type: ' + e.getTypeName());
                System.debug('Exception stack trace: ' + e.getStackTraceString());
            }
        } else {
            System.debug('No metadata components to create - toCreate list is empty');
        }

        // Create Apex Trigger for the source object to track changes
        createHistorianTrigger(service);
    }

    private void createHistorianTrigger(MetadataService.MetadataPort service) {
        String triggerName = objectApi + 'HistorianTrigger';
        System.debug('Creating/Updating Apex Trigger: ' + triggerName);
        
        try {
            // Check if trigger already exists
            MetadataService.IReadResult triggerReadResult = service.readMetadata('ApexTrigger', new String[] { triggerName });
            Boolean triggerExists = (triggerReadResult != null && triggerReadResult.getRecords() != null && triggerReadResult.getRecords().size() > 0);
            
            if (triggerExists) {
                System.debug('Trigger exists, updating with current configuration: ' + triggerName);
                // Continue with deployment to update the trigger with current field configuration
            } else {
                System.debug('Creating new trigger: ' + triggerName);
            }
            
            // Create the trigger body template
            String triggerBody = buildTriggerBody(triggerName);
            
            // Create ApexTrigger metadata
            MetadataService.ApexTrigger triggerMeta = new MetadataService.ApexTrigger();
            triggerMeta.fullName = triggerName;
            triggerMeta.content = EncodingUtil.base64Encode(Blob.valueOf(triggerBody));
            triggerMeta.status = 'Active';
            triggerMeta.apiVersion = 61.0; // Current API version
            
            // Deploy the trigger
            MetadataService.SaveResult[] triggerResults = service.createMetadata(new List<MetadataService.Metadata>{ triggerMeta });
            
            if (triggerResults != null && triggerResults.size() > 0) {
                MetadataService.SaveResult result = triggerResults[0];
                if (result.success) {
                    System.debug('Successfully created trigger: ' + result.fullName);
                    
                    // Update deployment result record with success
                    updateTriggerDeploymentResult(triggerName, 'Succeeded', 0, 'Trigger successfully deployed');
                    
                    // Verify deployment by checking trigger existence
                    try {
                        Boolean verified = TriggerDetectionService.verifyTriggerDeployment(objectApi);
                        if (verified) {
                            System.debug('Trigger deployment verified successfully: ' + triggerName);
                        } else {
                            System.debug('WARNING: Trigger deployment reported success but verification failed: ' + triggerName);
                            updateTriggerDeploymentResult(triggerName, 'Warning', 0, 'Deployment succeeded but verification failed');
                        }
                    } catch (Exception verifyEx) {
                        System.debug('Error verifying trigger deployment: ' + verifyEx.getMessage());
                    }
                    
                } else {
                    System.debug('Failed to create trigger: ' + result.fullName);
                    
                    String errorMessages = '';
                    Integer errorCount = 0;
                    
                    if (result.errors != null) {
                        for (MetadataService.Error err : result.errors) {
                            System.debug('Trigger Error: ' + err.message + ' (statusCode: ' + err.statusCode + ')');
                            errorMessages += err.message + ' (' + err.statusCode + '); ';
                            errorCount++;
                        }
                    }
                    
                    // Update deployment result record with failure
                    updateTriggerDeploymentResult(triggerName, 'Failed', errorCount, 'Trigger deployment failed: ' + errorMessages);
                }
            } else {
                System.debug('No trigger results returned from createMetadata');
                updateTriggerDeploymentResult(triggerName, 'Failed', 1, 'No results returned from createMetadata call');
            }
            
        } catch (Exception e) {
            System.debug('Exception during trigger creation: ' + e.getMessage());
            System.debug('Exception type: ' + e.getTypeName());
            System.debug('Exception stack trace: ' + e.getStackTraceString());
            
            // Update deployment result record with exception
            updateTriggerDeploymentResult(triggerName, 'Failed', 1, 'Exception during trigger creation: ' + e.getMessage());
        }
    }
    
    /**
     * Update or create deployment result record for trigger deployment tracking
     */
    private void updateTriggerDeploymentResult(String triggerName, String status, Integer errorCount, String message) {
        try {
            // Look for existing deployment result record for this trigger
            List<Historian_Deploy_Result__c> existingResults = [
                SELECT Id, Request_Id__c, Status__c, State__c
                FROM Historian_Deploy_Result__c
                WHERE Component_FullName__c = :triggerName
                  AND Component_Type__c = 'ApexTrigger'
                  AND Request_Id__c LIKE 'TRIGGER_DEPLOY_%'
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            
            if (!existingResults.isEmpty()) {
                // Update existing record
                Historian_Deploy_Result__c result = existingResults[0];
                result.Status__c = status;
                result.State__c = (status == 'Succeeded') ? 'Completed' : 'Failed';
                result.Error_Count__c = errorCount;
                result.Problem__c = message;
                result.Completed_On__c = System.now();
                
                update result;
                System.debug('Updated existing deployment result record: ' + result.Id);
                
            } else {
                // Create new record
                Historian_Deploy_Result__c result = new Historian_Deploy_Result__c(
                    Request_Id__c = 'TRIGGER_DEPLOY_' + System.currentTimeMillis(),
                    Status__c = status,
                    State__c = (status == 'Succeeded') ? 'Completed' : 'Failed',
                    Error_Count__c = errorCount,
                    Component_FullName__c = triggerName,
                    Component_Type__c = 'ApexTrigger',
                    Problem__c = message,
                    Completed_On__c = System.now()
                );
                
                insert result;
                System.debug('Created new deployment result record: ' + result.Id);
            }
            
        } catch (Exception ex) {
            System.debug('Error updating trigger deployment result: ' + ex.getMessage());
            // Don't throw - this is for tracking purposes only
        }
    }

    private String buildTriggerBody(String triggerName) {
        String triggerBody = 'trigger ' + triggerName + ' on ' + objectApi + ' (after update) {\n';
        triggerBody += '    // Auto-generated lightweight historian trigger - Updated: ' + System.now().format() + '\n';
        triggerBody += '    HistorianTriggerHandler.handleAfterUpdate(\'' + objectApi + '\', Trigger.old, Trigger.new);\n';
        triggerBody += '}\n';
        
        return triggerBody;
    }
}
