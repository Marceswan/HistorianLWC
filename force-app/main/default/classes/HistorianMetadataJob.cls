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

        // Create Record-Triggered Flow for the source object to track changes
        createHistorianFlow(service);
    }

    private void createHistorianFlow(MetadataService.MetadataPort service) {
        String flowName = objectApi + '_Historian_Flow';
        System.debug('Creating Record-Triggered Flow: ' + flowName);
        
        try {
            // Check if flow already exists
            MetadataService.IReadResult flowReadResult = service.readMetadata('Flow', new String[] { flowName });
            Boolean flowExists = (flowReadResult != null && flowReadResult.getRecords() != null && flowReadResult.getRecords().size() > 0);
            
            if (flowExists) {
                System.debug('Flow exists, updating with current configuration: ' + flowName);
            } else {
                System.debug('Creating new Record-Triggered Flow: ' + flowName);
            }
            
            // Create the Flow metadata
            MetadataService.Flow historianFlow = buildHistorianFlow(flowName);
            
            // Deploy the Flow using createMetadata (Flows can be created directly)
            List<MetadataService.Metadata> toCreateFlow = new List<MetadataService.Metadata>{historianFlow};
            
            MetadataService.SaveResult[] flowResults = service.createMetadata(toCreateFlow);
            
            if (flowResults != null && flowResults.size() > 0) {
                MetadataService.SaveResult result = flowResults[0];
                if (result.success) {
                    System.debug('Successfully created Flow: ' + result.fullName);
                    updateFlowDeploymentResult(flowName, 'Succeeded', 0, 'Flow successfully deployed');
                    
                } else {
                    System.debug('Failed to create Flow: ' + result.fullName);
                    
                    String errorMessages = '';
                    Integer errorCount = 0;
                    
                    if (result.errors != null) {
                        for (MetadataService.Error err : result.errors) {
                            System.debug('Flow Error: ' + err.message + ' (statusCode: ' + err.statusCode + ')');
                            errorMessages += err.message + ' (' + err.statusCode + '); ';
                            errorCount++;
                        }
                    }
                    
                    updateFlowDeploymentResult(flowName, 'Failed', errorCount, 'Flow deployment failed: ' + errorMessages);
                }
            } else {
                System.debug('No flow results returned from createMetadata');
                updateFlowDeploymentResult(flowName, 'Failed', 1, 'No results returned from createMetadata call');
            }
            
        } catch (Exception e) {
            System.debug('Exception during Flow creation: ' + e.getMessage());
            System.debug('Exception type: ' + e.getTypeName());
            System.debug('Exception stack trace: ' + e.getStackTraceString());
            
            updateFlowDeploymentResult(flowName, 'Failed', 1, 'Exception during Flow creation: ' + e.getMessage());
        }
    }
    
    /**
     * Build a Record-Triggered Flow that calls the HistorianHelper invocable action
     */
    private MetadataService.Flow buildHistorianFlow(String flowName) {
        MetadataService.Flow flow = new MetadataService.Flow();
        flow.fullName = flowName;
        flow.description = 'Auto-generated Record-Triggered Flow to capture field changes for ' + objectApi + ' using Historian';
        flow.label = objectApi + ' Historian Flow';
        flow.processType = 'AutoLaunchedFlow';
        flow.status = 'Active';
        flow.triggerType = 'RecordAfterSave';
        
        // Set up the trigger (what fires the flow)
        MetadataService.FlowStart startElement = new MetadataService.FlowStart();
        startElement.name = 'Start';
        startElement.label = 'Start';
        startElement.locationX = 50;
        startElement.locationY = 50;
        startElement.object_x = objectApi;
        startElement.triggerType = 'RecordAfterSave';
        
        // Add connector to action call
        MetadataService.FlowConnector startConnector = new MetadataService.FlowConnector();
        startConnector.targetReference = 'Capture_Historical_Changes';
        startElement.connector = startConnector;
        
        flow.start = startElement;
        
        // Create action call to HistorianHelper.captureHistoricalChanges
        MetadataService.FlowActionCall actionCall = new MetadataService.FlowActionCall();
        actionCall.name = 'Capture_Historical_Changes';
        actionCall.label = 'Capture Historical Changes';
        actionCall.locationX = 300;
        actionCall.locationY = 150;
        actionCall.actionName = 'HistorianHelper';
        actionCall.actionType = 'apex';
        
        // Set up input parameters for the HistorianHelper.captureHistoricalChanges method
        List<MetadataService.FlowActionCallInputParameter> inputParams = new List<MetadataService.FlowActionCallInputParameter>();
        
        // targetRecordId parameter
        MetadataService.FlowActionCallInputParameter recordIdParam = new MetadataService.FlowActionCallInputParameter();
        recordIdParam.name = 'targetRecordId';
        recordIdParam.value = new MetadataService.FlowElementReferenceOrValue();
        recordIdParam.value.elementReference = '$Record.Id';
        inputParams.add(recordIdParam);
        
        // targetSObjectApiName parameter
        MetadataService.FlowActionCallInputParameter sObjectParam = new MetadataService.FlowActionCallInputParameter();
        sObjectParam.name = 'targetSObjectApiName';
        sObjectParam.value = new MetadataService.FlowElementReferenceOrValue();
        sObjectParam.value.stringValue = objectApi;
        inputParams.add(sObjectParam);
        
        actionCall.inputParameters = inputParams;
        
        flow.actionCalls = new List<MetadataService.FlowActionCall>{actionCall};
        
        // Set API version
        flow.apiVersion = 64.0;
        
        return flow;
    }
    
    /**
     * Update or create deployment result record for Flow deployment tracking
     */
    private void updateFlowDeploymentResult(String flowName, String status, Integer errorCount, String message) {
        try {
            // Look for existing deployment result record for this flow
            List<Historian_Deploy_Result__c> existingResults = [
                SELECT Id, Request_Id__c, Status__c, State__c
                FROM Historian_Deploy_Result__c
                WHERE Component_FullName__c = :flowName
                  AND Component_Type__c = 'Flow'
                  AND Request_Id__c LIKE 'FLOW_DEPLOY_%'
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
                System.debug('Updated existing Flow deployment result record: ' + result.Id);
                
            } else {
                // Create new record
                Historian_Deploy_Result__c result = new Historian_Deploy_Result__c(
                    Request_Id__c = 'FLOW_DEPLOY_' + System.currentTimeMillis(),
                    Status__c = status,
                    State__c = (status == 'Succeeded') ? 'Completed' : 'Failed',
                    Error_Count__c = errorCount,
                    Component_FullName__c = flowName,
                    Component_Type__c = 'Flow',
                    Problem__c = message,
                    Completed_On__c = System.now()
                );
                
                insert result;
                System.debug('Created new Flow deployment result record: ' + result.Id);
            }
            
        } catch (Exception ex) {
            System.debug('Error updating Flow deployment result: ' + ex.getMessage());
            // Don't throw - this is for tracking purposes only
        }
    }

}
