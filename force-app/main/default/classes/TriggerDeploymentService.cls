public with sharing class TriggerDeploymentService {
    
    @AuraEnabled
    public static String generateAndDeployTrigger(String objectApiName) {
        System.debug('generateAndDeployTrigger called for: ' + objectApiName);
        
        if (String.isBlank(objectApiName)) {
            throw new AuraHandledException('Object API Name is required');
        }
        
        try {
            // Validate object exists
            if (!Schema.getGlobalDescribe().containsKey(objectApiName)) {
                throw new AuraHandledException('Object "' + objectApiName + '" does not exist');
            }
            
            // Check for active configurations
            List<Historian_Config__mdt> configs = [
                SELECT DeveloperName FROM Historian_Config__mdt 
                WHERE Object_Api_Name__c = :objectApiName AND Active__c = true LIMIT 1
            ];
            
            if (configs.isEmpty()) {
                throw new AuraHandledException('No active configurations found for ' + objectApiName);
            }
            
            // Generate the trigger code
            String triggerName = objectApiName + 'HistorianTrigger';
            String triggerCode = generateTriggerCode(triggerName, objectApiName);
            
            // Deploy using a streamlined approach
            return deployTriggerCode(triggerName, triggerCode, objectApiName);
            
        } catch (Exception ex) {
            System.debug('Error in generateAndDeployTrigger: ' + ex.getMessage());
            throw new AuraHandledException('Failed to deploy trigger: ' + ex.getMessage());
        }
    }
    
    private static String generateTriggerCode(String triggerName, String objectApiName) {
        String triggerTemplate = 'trigger {0} on {1} (after update) {\n' +
            '    // Auto-generated lightweight historian trigger - Generated: {2}\n' +
            '    HistorianTriggerHandler.handleAfterUpdate(\'{1}\', Trigger.old, Trigger.new);\n' +
            '}';
            
        return String.format(triggerTemplate, new List<String>{
            triggerName,
            objectApiName, 
            System.now().format('yyyy-MM-dd HH:mm:ss')
        });
    }
    
    private static String deployTriggerCode(String triggerName, String triggerCode, String objectApiName) {
        String jobId = 'TRIGGER_DEPLOY_' + System.currentTimeMillis();
        
        try {
            System.debug('Deploying trigger using HistorianMetadataJob: ' + triggerName);
            
            // Use existing HistorianMetadataJob which has working trigger deployment
            HistorianConfigService.ConfigSummary cfg = new HistorianConfigService.ConfigSummary();
            cfg.objectApi = objectApiName;
            cfg.configName = 'trigger_only_deployment';
            
            // Enqueue the job for trigger deployment only
            Id asyncJobId = System.enqueueJob(new HistorianMetadataJob(objectApiName, cfg));
            
            System.debug('Trigger deployment job enqueued successfully: ' + asyncJobId);
            
            // Log deployment initiation
            saveTriggerDeploymentRecord(triggerName, objectApiName, jobId, 'Deploying', 0, 'Trigger deployment job enqueued: ' + asyncJobId);
            
        } catch (Exception e) {
            System.debug('Error deploying trigger: ' + e.getMessage());
            saveTriggerDeploymentRecord(triggerName, objectApiName, jobId, 'Failed', 1, 'Deployment failed: ' + e.getMessage());
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
}