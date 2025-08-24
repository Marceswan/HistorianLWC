public with sharing class FlowDeploymentService {
    
    /**
     * Deploy a Record-Triggered Flow immediately using the Metadata API with real-time feedback
     */
    @AuraEnabled
    public static Map<String, Object> deployFlowNow(String objectApiName) {
        System.debug('deployFlowNow called for: ' + objectApiName);
        
        Map<String, Object> result = new Map<String, Object>();
        result.put('success', false);
        result.put('objectApiName', objectApiName);
        
        if (String.isBlank(objectApiName)) {
            result.put('error', 'Object API Name is required');
            return result;
        }
        
        try {
            // Validate object exists
            if (!Schema.getGlobalDescribe().containsKey(objectApiName)) {
                result.put('error', 'Object "' + objectApiName + '" does not exist');
                return result;
            }
            
            // Check for active configurations
            List<Historian_Config__mdt> configs = [
                SELECT DeveloperName FROM Historian_Config__mdt 
                WHERE Object_Api_Name__c = :objectApiName AND Active__c = true LIMIT 1
            ];
            
            if (configs.isEmpty()) {
                result.put('error', 'No active configurations found for ' + objectApiName);
                return result;
            }
            
            // Generate the Flow name and description
            String flowName = objectApiName + '_Historian_Flow';
            String flowDescription = 'Auto-generated Record-Triggered Flow to capture field changes for ' + objectApiName + ' using Historian';
            
            result.put('flowName', flowName);
            result.put('flowDescription', flowDescription);
            
            // Deploy using Metadata API with immediate deployment
            Map<String, Object> deployResult = deployFlowUsingMdapi(flowName, objectApiName);
            
            // Merge deployment results
            result.putAll(deployResult);
            
            if ((Boolean) deployResult.get('success')) {
                // Verify deployment
                Boolean verified = verifyFlowExists(objectApiName);
                result.put('verified', verified);
                
                if (verified) {
                    result.put('message', 'Flow successfully deployed and verified');
                    saveFlowDeploymentRecord(flowName, objectApiName, 'SUCCESS_' + String.valueOf(System.currentTimeMillis()).right(10), 'Succeeded', 0, 'Flow deployed and verified successfully');
                } else {
                    result.put('warning', 'Flow deployed but verification failed');
                    saveFlowDeploymentRecord(flowName, objectApiName, 'WARN_' + String.valueOf(System.currentTimeMillis()).right(10), 'Warning', 0, 'Flow deployed but verification failed');
                }
            }
            
        } catch (Exception ex) {
            System.debug('Error in deployFlowNow: ' + ex.getMessage());
            result.put('error', ex.getMessage());
            result.put('errorType', ex.getTypeName());
            saveFlowDeploymentRecord(
                objectApiName + '_Historian_Flow', 
                objectApiName, 
                'ERR_' + String.valueOf(System.currentTimeMillis()).right(10), 
                'Failed', 
                1, 
                'Deployment failed: ' + ex.getMessage()
            );
        }
        
        return result;
    }
    
    /**
     * Legacy method for backward compatibility - now calls the new deployFlowNow
     */
    @AuraEnabled
    public static String generateAndDeployFlow(String objectApiName) {
        Map<String, Object> result = deployFlowNow(objectApiName);
        
        if ((Boolean) result.get('success')) {
            return 'SUCCESS_' + System.currentTimeMillis();
        } else {
            throw new AuraHandledException((String) result.get('error'));
        }
    }
    
    /**
     * Deploy Flow using Metadata API with immediate deployment
     */
    private static Map<String, Object> deployFlowUsingMdapi(String flowName, String objectApiName) {
        Map<String, Object> result = new Map<String, Object>();
        result.put('success', false);
        
        try {
            System.debug('Deploying Flow using Metadata API: ' + flowName);
            
            // Ensure remote site settings are configured
            if (!MdapiUtil.ensureRemoteSiteSettings()) {
                result.put('error', 'Remote site settings are not configured. Please configure Metadata API remote site settings first.');
                return result;
            }
            
            // Use the HistorianMetadataJob for Flow deployment
            System.debug('Using HistorianMetadataJob deployment approach...');
            String deployJobId = deployFlowCode(flowName, objectApiName);
            result.put('deployId', deployJobId);
            result.put('success', true);
            result.put('message', 'Flow deployment job initiated');
            result.put('inProgress', true);
            
            System.debug('Flow deployment initiated with job ID: ' + deployJobId);
            
        } catch (Exception e) {
            System.debug('Error in deployFlowUsingMdapi: ' + e.getMessage());
            System.debug('Exception stack trace: ' + e.getStackTraceString());
            result.put('error', e.getMessage());
            result.put('errorType', e.getTypeName());
        }
        
        return result;
    }
    
    /**
     * Deploy Flow directly using Metadata API without circular dependencies
     */
    private static String deployFlowCode(String flowName, String objectApiName) {
        String jobId = 'FLOW_' + String.valueOf(System.currentTimeMillis()).right(10);
        
        try {
            System.debug('Deploying Flow directly via Metadata API: ' + flowName);
            
            // Deploy Flow directly using Metadata API instead of creating circular dependency
            String deployResult = deployFlowDirectly(flowName, objectApiName);
            System.debug('Direct Flow deployment result: ' + deployResult);
            
            saveFlowDeploymentRecord(flowName, objectApiName, jobId, 'Succeeded', 0, 'Flow deployed directly: ' + deployResult);
            
        } catch (Exception e) {
            System.debug('Error in deployFlowCode: ' + e.getMessage());
            saveFlowDeploymentRecord(flowName, objectApiName, jobId, 'Failed', 1, 'Flow deployment failed: ' + e.getMessage());
            throw new AuraHandledException('Failed to deploy Flow: ' + e.getMessage());
        }
        
        return jobId;
    }
    
    /**
     * Deploy Flow directly using Metadata API with proper Flow creation
     */
    private static String deployFlowDirectly(String flowName, String objectApiName) {
        System.debug('Creating Flow metadata for: ' + flowName);
        
        try {
            // Use MetadataService to deploy the Flow
            MetadataService.MetadataPort service = MdapiUtil.newService();
            
            // Create the Flow metadata with proper structure
            MetadataService.Flow historianFlow = buildHistorianFlowMetadata(flowName, objectApiName);
            
            System.debug('Deploying Flow via Metadata API: ' + flowName);
            
            // Deploy the Flow using createMetadata
            List<MetadataService.Metadata> toCreateFlow = new List<MetadataService.Metadata>{historianFlow};
            MetadataService.SaveResult[] flowResults = service.createMetadata(toCreateFlow);
            
            if (flowResults != null && flowResults.size() > 0) {
                MetadataService.SaveResult result = flowResults[0];
                if (result.success) {
                    System.debug('Successfully created Flow: ' + result.fullName);
                    return 'Flow successfully deployed: ' + result.fullName;
                } else {
                    String errorMessages = '';
                    if (result.errors != null) {
                        for (MetadataService.Error err : result.errors) {
                            System.debug('Flow Error: ' + err.message + ' (statusCode: ' + err.statusCode + ')');
                            errorMessages += err.message + ' (' + err.statusCode + '); ';
                        }
                    }
                    throw new AuraHandledException('Flow deployment failed: ' + errorMessages);
                }
            } else {
                throw new AuraHandledException('No results returned from Flow deployment');
            }
            
        } catch (Exception e) {
            System.debug('Exception during direct Flow deployment: ' + e.getMessage());
            System.debug('Exception stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Flow deployment error: ' + e.getMessage());
        }
    }
    
    /**
     * Build proper Flow metadata object for deployment
     */
    private static MetadataService.Flow buildHistorianFlowMetadata(String flowName, String objectApiName) {
        MetadataService.Flow flow = new MetadataService.Flow();
        flow.fullName = flowName;
        flow.description = 'Auto-generated Record-Triggered Flow to capture field changes for ' + objectApiName + ' using Historian';
        flow.label = objectApiName + ' Historian Flow';
        flow.processType = 'AutoLaunchedFlow';
        
        // Create action call to HistorianHelper.captureHistoricalChanges
        MetadataService.FlowActionCall actionCall = new MetadataService.FlowActionCall();
        actionCall.name = 'Capture_Historical_Changes';
        actionCall.label = 'Capture Historical Changes';
        actionCall.locationX = 176;
        actionCall.locationY = 287;
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
        sObjectParam.value.stringValue = objectApiName;
        inputParams.add(sObjectParam);
        
        actionCall.inputParameters = inputParams;
        flow.actionCalls = new List<MetadataService.FlowActionCall>{actionCall};
        
        return flow;
    }
    
    /**
     * Build basic Flow XML structure
     */
    private static String buildFlowXml(String flowName, String objectApiName) {
        return '<?xml version="1.0" encoding="UTF-8"?>\n' +
               '<Flow xmlns="http://soap.sforce.com/2006/04/metadata">\n' +
               '    <apiVersion>64.0</apiVersion>\n' +
               '    <description>Auto-generated Record-Triggered Flow to capture field changes for ' + objectApiName + ' using Historian</description>\n' +
               '    <label>' + objectApiName + ' Historian Flow</label>\n' +
               '    <processType>AutoLaunchedFlow</processType>\n' +
               '    <start>\n' +
               '        <locationX>176</locationX>\n' +
               '        <locationY>0</locationY>\n' +
               '        <object>' + objectApiName + '</object>\n' +
               '        <recordTriggerType>Update</recordTriggerType>\n' +
               '        <triggerType>RecordAfterSave</triggerType>\n' +
               '    </start>\n' +
               '    <status>Active</status>\n' +
               '</Flow>';
    }
    
    private static void saveFlowDeploymentRecord(String flowName, String objectApiName, String jobId, String status, Integer errorCount, String message) {
        try {
            Historian_Deploy_Result__c result = new Historian_Deploy_Result__c(
                Request_Id__c = jobId,
                Status__c = status,
                State__c = status, 
                Error_Count__c = errorCount,
                Component_FullName__c = flowName,
                Component_Type__c = 'Flow',
                Problem__c = message
            );
            insert result;
            
            System.debug('Saved Flow deployment record: ' + result.Id);
            
        } catch (Exception e) {
            System.debug('Error saving Flow deployment record: ' + e.getMessage());
        }
    }
    
    /**
     * Verify that Record-Triggered Flow exists in the org
     */
    public static Boolean verifyFlowExists(String objectApiName) {
        try {
            return FlowDetectionService.isFlowDeployed(objectApiName);
        } catch (Exception ex) {
            System.debug('Error verifying Flow exists: ' + ex.getMessage());
            return false;
        }
    }
    
    /**
     * Verify that Flow deployment was successful for an object
     */
    @AuraEnabled
    public static Map<String, Object> verifyFlowDeployment(String objectApiName) {
        Map<String, Object> result = new Map<String, Object>();
        result.put('objectApiName', objectApiName);
        
        if (String.isBlank(objectApiName)) {
            result.put('success', false);
            result.put('error', 'Object API Name is required');
            return result;
        }
        
        try {
            String flowName = objectApiName + '_Historian_Flow';
            result.put('flowName', flowName);
            
            // Use FlowDetectionService to verify deployment
            Map<String, Object> flowDetails = FlowDetectionService.getFlowDetails(objectApiName);
            
            Boolean flowExists = (Boolean) flowDetails.get('exists');
            result.put('flowExists', flowExists);
            result.put('flowDetails', flowDetails);
            
            if (flowExists) {
                // Check for recent successful deployment records
                List<Historian_Deploy_Result__c> recentDeployments = [
                    SELECT Id, Request_Id__c, Status__c, State__c, Completed_On__c, Problem__c
                    FROM Historian_Deploy_Result__c
                    WHERE Component_FullName__c = :flowName
                      AND Component_Type__c = 'Flow'
                    ORDER BY CreatedDate DESC
                    LIMIT 3
                ];
                
                result.put('recentDeploymentCount', recentDeployments.size());
                
                if (!recentDeployments.isEmpty()) {
                    List<Map<String, String>> deploymentSummary = new List<Map<String, String>>();
                    for (Historian_Deploy_Result__c deployment : recentDeployments) {
                        Map<String, String> deployInfo = new Map<String, String>();
                        deployInfo.put('requestId', deployment.Request_Id__c);
                        deployInfo.put('status', deployment.Status__c);
                        deployInfo.put('state', deployment.State__c);
                        deployInfo.put('completedOn', String.valueOf(deployment.Completed_On__c));
                        deploymentSummary.add(deployInfo);
                    }
                    result.put('deploymentHistory', deploymentSummary);
                    
                    // Check if most recent deployment was successful
                    Historian_Deploy_Result__c latestDeployment = recentDeployments[0];
                    Boolean recentSuccess = (latestDeployment.Status__c == 'Succeeded' || 
                                           latestDeployment.State__c == 'Completed');
                    result.put('recentDeploymentSuccess', recentSuccess);
                }
                
                result.put('success', true);
                result.put('message', 'Flow deployment verified successfully');
                
            } else {
                result.put('success', false);
                result.put('message', 'Flow does not exist - deployment may have failed or is still in progress');
            }
            
        } catch (Exception ex) {
            result.put('success', false);
            result.put('error', ex.getMessage());
            result.put('errorType', ex.getTypeName());
            System.debug('Error verifying Flow deployment for ' + objectApiName + ': ' + ex.getMessage());
        }
        
        return result;
    }
    
    /**
     * Get real-time deployment status with immediate feedback
     */
    @AuraEnabled
    public static Map<String, Object> getDeploymentStatus(String objectApiName) {
        Map<String, Object> status = new Map<String, Object>();
        status.put('objectApiName', objectApiName);
        
        try {
            // Get Flow status
            Boolean flowExists = FlowDetectionService.isFlowDeployed(objectApiName);
            status.put('flowExists', flowExists);
            
            // Get recent deployment activities for this object
            String flowName = objectApiName + '_Historian_Flow';
            List<Historian_Deploy_Result__c> recentDeployments = [
                SELECT Id, Status__c, State__c, Error_Count__c, Problem__c, 
                       Completed_On__c, CreatedDate, Request_Id__c
                FROM Historian_Deploy_Result__c
                WHERE Component_FullName__c = :flowName
                  AND Component_Type__c = 'Flow'
                ORDER BY CreatedDate DESC
                LIMIT 5
            ];
            
            status.put('recentDeploymentCount', recentDeployments.size());
            
            if (!recentDeployments.isEmpty()) {
                Historian_Deploy_Result__c latest = recentDeployments[0];
                status.put('latestDeploymentStatus', latest.Status__c);
                status.put('latestDeploymentState', latest.State__c);
                status.put('latestDeploymentTime', latest.CreatedDate);
                status.put('latestErrorCount', latest.Error_Count__c);
                status.put('latestProblem', latest.Problem__c);
                
                // Determine overall status
                if (flowExists && latest.Status__c == 'Succeeded') {
                    status.put('overallStatus', 'SUCCESS');
                    status.put('statusMessage', 'Flow deployed and verified');
                } else if (flowExists) {
                    status.put('overallStatus', 'SUCCESS_UNVERIFIED');
                    status.put('statusMessage', 'Flow exists but deployment status unclear');
                } else if (latest.Status__c == 'Failed') {
                    status.put('overallStatus', 'FAILED');
                    status.put('statusMessage', 'Latest deployment failed');
                } else {
                    status.put('overallStatus', 'IN_PROGRESS');
                    status.put('statusMessage', 'Deployment may be in progress');
                }
            } else {
                if (flowExists) {
                    status.put('overallStatus', 'SUCCESS_MANUAL');
                    status.put('statusMessage', 'Flow exists (deployed manually or externally)');
                } else {
                    status.put('overallStatus', 'NOT_DEPLOYED');
                    status.put('statusMessage', 'No Flow deployment found');
                }
            }
            
            status.put('success', true);
            
        } catch (Exception ex) {
            status.put('success', false);
            status.put('error', ex.getMessage());
            status.put('errorType', ex.getTypeName());
        }
        
        return status;
    }
}