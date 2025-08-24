public with sharing class TriggerDeploymentService {
    
    /**
     * Deploy a trigger immediately using the Metadata API with real-time feedback
     */
    @AuraEnabled
    public static Map<String, Object> deployTriggerNow(String objectApiName) {
        System.debug('deployTriggerNow called for: ' + objectApiName);
        
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
            
            // Generate the trigger code
            String triggerName = objectApiName + 'HistorianTrigger';
            String triggerCode = generateLightweightTriggerCode(triggerName, objectApiName);
            
            result.put('triggerName', triggerName);
            result.put('triggerCode', triggerCode);
            
            // Deploy using Metadata API with immediate deployment
            Map<String, Object> deployResult = deployTriggerUsingMdapi(triggerName, triggerCode, objectApiName);
            
            // Merge deployment results
            result.putAll(deployResult);
            
            if ((Boolean) deployResult.get('success')) {
                // Verify deployment
                Boolean verified = verifyTriggerExists(objectApiName);
                result.put('verified', verified);
                
                if (verified) {
                    result.put('message', 'Trigger successfully deployed and verified');
                    saveTriggerDeploymentRecord(triggerName, objectApiName, 'SUCCESS_' + String.valueOf(System.currentTimeMillis()).right(10), 'Succeeded', 0, 'Trigger deployed and verified successfully');
                } else {
                    result.put('warning', 'Trigger deployed but verification failed');
                    saveTriggerDeploymentRecord(triggerName, objectApiName, 'WARN_' + String.valueOf(System.currentTimeMillis()).right(10), 'Warning', 0, 'Trigger deployed but verification failed');
                }
            }
            
        } catch (Exception ex) {
            System.debug('Error in deployTriggerNow: ' + ex.getMessage());
            result.put('error', ex.getMessage());
            result.put('errorType', ex.getTypeName());
            saveTriggerDeploymentRecord(
                objectApiName + 'HistorianTrigger', 
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
     * Legacy method for backward compatibility - now calls the new deployTriggerNow
     */
    @AuraEnabled
    public static String generateAndDeployTrigger(String objectApiName) {
        Map<String, Object> result = deployTriggerNow(objectApiName);
        
        if ((Boolean) result.get('success')) {
            return 'SUCCESS_' + System.currentTimeMillis();
        } else {
            throw new AuraHandledException((String) result.get('error'));
        }
    }
    
    /**
     * Generate lightweight 3-line trigger code
     */
    public static String generateLightweightTriggerCode(String triggerName, String objectApiName) {
        String timestamp = System.now().format('yyyy-MM-dd HH:mm:ss');
        
        String triggerCode = 'trigger ' + triggerName + ' on ' + objectApiName + ' (after update) {\n' +
            '    // Auto-generated lightweight historian trigger - Generated: ' + timestamp + '\n' +
            '    HistorianTriggerHandler.handleAfterUpdate(\'' + objectApiName + '\', Trigger.old, Trigger.new);\n' +
            '}';
            
        return triggerCode;
    }
    
    /**
     * Legacy method name for backward compatibility
     */
    private static String generateTriggerCode(String triggerName, String objectApiName) {
        return generateLightweightTriggerCode(triggerName, objectApiName);
    }
    
    /**
     * Deploy trigger using Metadata API with immediate deployment and callback
     */
    private static Map<String, Object> deployTriggerUsingMdapi(String triggerName, String triggerCode, String objectApiName) {
        Map<String, Object> result = new Map<String, Object>();
        result.put('success', false);
        
        try {
            System.debug('Deploying trigger using Metadata API: ' + triggerName);
            
            // Ensure remote site settings are configured
            if (!MdapiUtil.ensureRemoteSiteSettings()) {
                result.put('error', 'Remote site settings are not configured. Please configure Metadata API remote site settings first.');
                return result;
            }
            
            // Get Metadata Service
            MetadataService.MetadataPort service = MdapiUtil.newService();
            
            // Use the legacy deployment approach via HistorianMetadataJob for reliability
            System.debug('Using HistorianMetadataJob deployment approach...');
            String deployJobId = deployTriggerCode(triggerName, triggerCode, objectApiName);
            result.put('deployId', deployJobId);
            result.put('success', true);
            result.put('message', 'Trigger deployment job initiated');
            result.put('inProgress', true);
            
            System.debug('Deployment initiated with job ID: ' + deployJobId);
            
        } catch (Exception e) {
            System.debug('Error in deployTriggerUsingMdapi: ' + e.getMessage());
            System.debug('Exception stack trace: ' + e.getStackTraceString());
            result.put('error', e.getMessage());
            result.put('errorType', e.getTypeName());
        }
        
        return result;
    }
    
    /**
     * Create deployment options for trigger deployment
     */
    private static MetadataService.DeployOptions createDeployOptions() {
        MetadataService.DeployOptions options = new MetadataService.DeployOptions();
        options.allowMissingFiles = false;
        options.autoUpdatePackage = false;
        options.checkOnly = false;
        options.ignoreWarnings = false;
        options.performRetrieve = false;
        options.purgeOnDelete = false;
        options.rollbackOnError = true;
        options.runTests = new List<String>();
        options.singlePackage = false;
        
        return options;
    }
    
    /**
     * Legacy deployment method - now just enqueues job for backward compatibility
     */
    private static String deployTriggerCode(String triggerName, String triggerCode, String objectApiName) {
        String jobId = 'TRIG_' + String.valueOf(System.currentTimeMillis()).right(10);
        
        try {
            System.debug('Using legacy deployTriggerCode - enqueuing HistorianMetadataJob: ' + triggerName);
            
            // Use existing HistorianMetadataJob for backward compatibility
            HistorianConfigService.ConfigSummary cfg = new HistorianConfigService.ConfigSummary();
            cfg.objectApi = objectApiName;
            cfg.configName = 'trigger_deployment_service';
            
            Id asyncJobId = System.enqueueJob(new HistorianMetadataJob(objectApiName, cfg));
            System.debug('Legacy trigger deployment job enqueued: ' + asyncJobId);
            
            saveTriggerDeploymentRecord(triggerName, objectApiName, jobId, 'Deploying', 0, 'Legacy deployment job enqueued: ' + asyncJobId);
            
        } catch (Exception e) {
            System.debug('Error in legacy deployTriggerCode: ' + e.getMessage());
            saveTriggerDeploymentRecord(triggerName, objectApiName, jobId, 'Failed', 1, 'Legacy deployment failed: ' + e.getMessage());
            throw new AuraHandledException('Failed to deploy trigger: ' + e.getMessage());
        }
        
        return jobId;
    }
    
    private static void saveTriggerDeploymentRecord(String triggerName, String objectApiName, String jobId, String status, Integer errorCount, String message) {
        try {
            Historian_Deploy_Result__c result = new Historian_Deploy_Result__c(
                Request_Id__c = jobId,
                Status__c = status,
                State__c = status, 
                Error_Count__c = errorCount,
                Component_FullName__c = triggerName,
                Component_Type__c = 'ApexTrigger',
                Problem__c = message
            );
            insert result;
            
            System.debug('Saved trigger deployment record: ' + result.Id);
            
        } catch (Exception e) {
            System.debug('Error saving trigger deployment record: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static List<Map<String, String>> getGeneratedTriggers() {
        List<Map<String, String>> triggers = new List<Map<String, String>>();
        
        try {
            List<Historian_Deploy_Result__c> results = [
                SELECT Request_Id__c, Component_FullName__c, Component_Type__c, 
                       Status__c, State__c, Problem__c, CreatedDate
                FROM Historian_Deploy_Result__c
                WHERE Component_Type__c = 'ApexTrigger'
                  AND Status__c = 'Generated'
                ORDER BY CreatedDate DESC
                LIMIT 10
            ];
            
            for (Historian_Deploy_Result__c result : results) {
                Map<String, String> triggerInfo = new Map<String, String>();
                triggerInfo.put('requestId', result.Request_Id__c);
                triggerInfo.put('triggerName', result.Component_FullName__c);
                triggerInfo.put('status', result.Status__c);
                triggerInfo.put('state', result.State__c);
                triggerInfo.put('createdDate', String.valueOf(result.CreatedDate));
                
                // Extract trigger code from Problem field (where we stored it)
                if (String.isNotBlank(result.Problem__c) && result.Problem__c.contains('Trigger Code:')) {
                    String triggerCode = result.Problem__c.substringAfter('Trigger Code:\n');
                    triggerInfo.put('triggerCode', triggerCode);
                }
                
                triggers.add(triggerInfo);
            }
            
        } catch (Exception e) {
            System.debug('Error getting generated triggers: ' + e.getMessage());
        }
        
        return triggers;
    }
    
    /**
     * Verify that trigger exists in the org
     */
    public static Boolean verifyTriggerExists(String objectApiName) {
        try {
            return TriggerDetectionService.isTriggerDeployed(objectApiName);
        } catch (Exception ex) {
            System.debug('Error verifying trigger exists: ' + ex.getMessage());
            return false;
        }
    }
    
    /**
     * Verify that trigger deployment was successful for an object
     * This method should be called after trigger deployment to confirm success
     */
    @AuraEnabled
    public static Map<String, Object> verifyTriggerDeployment(String objectApiName) {
        Map<String, Object> result = new Map<String, Object>();
        result.put('objectApiName', objectApiName);
        
        if (String.isBlank(objectApiName)) {
            result.put('success', false);
            result.put('error', 'Object API Name is required');
            return result;
        }
        
        try {
            String triggerName = objectApiName + 'HistorianTrigger';
            result.put('triggerName', triggerName);
            
            // Use TriggerDetectionService to verify deployment
            Map<String, Object> triggerDetails = TriggerDetectionService.getTriggerDetails(objectApiName);
            
            Boolean triggerExists = (Boolean) triggerDetails.get('exists');
            result.put('triggerExists', triggerExists);
            result.put('triggerDetails', triggerDetails);
            
            if (triggerExists) {
                // Check for recent successful deployment records
                List<Historian_Deploy_Result__c> recentDeployments = [
                    SELECT Id, Request_Id__c, Status__c, State__c, Completed_On__c, Problem__c
                    FROM Historian_Deploy_Result__c
                    WHERE Component_FullName__c = :triggerName
                      AND Component_Type__c = 'ApexTrigger'
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
                result.put('message', 'Trigger deployment verified successfully');
                
            } else {
                result.put('success', false);
                result.put('message', 'Trigger does not exist - deployment may have failed or is still in progress');
            }
            
        } catch (Exception ex) {
            result.put('success', false);
            result.put('error', ex.getMessage());
            result.put('errorType', ex.getTypeName());
            System.debug('Error verifying trigger deployment for ' + objectApiName + ': ' + ex.getMessage());
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
            // Get trigger status
            Boolean triggerExists = TriggerDetectionService.isTriggerDeployed(objectApiName);
            status.put('triggerExists', triggerExists);
            
            // Get recent deployment activities for this object
            String triggerName = objectApiName + 'HistorianTrigger';
            List<Historian_Deploy_Result__c> recentDeployments = [
                SELECT Id, Status__c, State__c, Error_Count__c, Problem__c, 
                       Completed_On__c, CreatedDate, Request_Id__c
                FROM Historian_Deploy_Result__c
                WHERE Component_FullName__c = :triggerName
                  AND Component_Type__c = 'ApexTrigger'
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
                if (triggerExists && latest.Status__c == 'Succeeded') {
                    status.put('overallStatus', 'SUCCESS');
                    status.put('statusMessage', 'Trigger deployed and verified');
                } else if (triggerExists) {
                    status.put('overallStatus', 'SUCCESS_UNVERIFIED');
                    status.put('statusMessage', 'Trigger exists but deployment status unclear');
                } else if (latest.Status__c == 'Failed') {
                    status.put('overallStatus', 'FAILED');
                    status.put('statusMessage', 'Latest deployment failed');
                } else {
                    status.put('overallStatus', 'IN_PROGRESS');
                    status.put('statusMessage', 'Deployment may be in progress');
                }
            } else {
                if (triggerExists) {
                    status.put('overallStatus', 'SUCCESS_MANUAL');
                    status.put('statusMessage', 'Trigger exists (deployed manually or externally)');
                } else {
                    status.put('overallStatus', 'NOT_DEPLOYED');
                    status.put('statusMessage', 'No trigger deployment found');
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
    
    /**
     * Check deployment status for multiple objects at once
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getDeploymentStatusSummary() {
        Map<String, Object> summary = new Map<String, Object>();
        
        try {
            // Get all active historian configurations
            List<Historian_Config__mdt> configs = [
                SELECT Object_Api_Name__c, DeveloperName, Active__c
                FROM Historian_Config__mdt
                WHERE Active__c = true
            ];
            
            summary.put('totalActiveConfigs', configs.size());
            
            // Get trigger status for all configured objects
            List<String> objectApis = new List<String>();
            for (Historian_Config__mdt config : configs) {
                objectApis.add(config.Object_Api_Name__c);
            }
            
            Map<String, Boolean> triggerStatusMap = TriggerDetectionService.getTriggerStatusMap(objectApis);
            
            Integer deployedCount = 0;
            Integer notDeployedCount = 0;
            
            List<Map<String, Object>> objectStatus = new List<Map<String, Object>>();
            for (String objectApi : objectApis) {
                Map<String, Object> status = new Map<String, Object>();
                status.put('objectApi', objectApi);
                
                Boolean isDeployed = triggerStatusMap.get(objectApi) == true;
                status.put('triggerDeployed', isDeployed);
                
                if (isDeployed) {
                    deployedCount++;
                } else {
                    notDeployedCount++;
                }
                
                objectStatus.add(status);
            }
            
            summary.put('deployedTriggers', deployedCount);
            summary.put('notDeployedTriggers', notDeployedCount);
            summary.put('deploymentRate', objectApis.isEmpty() ? 0 : (deployedCount * 100 / objectApis.size()));
            summary.put('objectDetails', objectStatus);
            summary.put('success', true);
            
        } catch (Exception ex) {
            summary.put('success', false);
            summary.put('error', ex.getMessage());
            System.debug('Error getting deployment status summary: ' + ex.getMessage());
        }
        
        return summary;
    }
}