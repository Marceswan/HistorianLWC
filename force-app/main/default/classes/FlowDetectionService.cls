public with sharing class FlowDetectionService {
    
    /**
     * Check if a Record-Triggered Flow is deployed for the given object
     */
    public static Boolean isFlowDeployed(String objectApiName) {
        try {
            String flowName = objectApiName + '_Historian_Flow';
            
            // Query Flow metadata to check if Flow exists and is active
            List<Flow> flows = [
                SELECT Id, DeveloperName, MasterLabel, Status 
                FROM Flow 
                WHERE DeveloperName = :flowName 
                  AND Status = 'Active'
                LIMIT 1
            ];
            
            Boolean flowExists = !flows.isEmpty();
            System.debug('Flow deployment check for ' + objectApiName + ': ' + flowExists);
            
            return flowExists;
            
        } catch (Exception ex) {
            System.debug('Error checking Flow deployment for ' + objectApiName + ': ' + ex.getMessage());
            return false;
        }
    }
    
    /**
     * Get detailed information about a Flow for the given object
     */
    public static Map<String, Object> getFlowDetails(String objectApiName) {
        Map<String, Object> details = new Map<String, Object>();
        details.put('objectApiName', objectApiName);
        
        try {
            String flowName = objectApiName + '_Historian_Flow';
            details.put('flowName', flowName);
            
            // Query Flow information
            List<Flow> flows = [
                SELECT Id, DeveloperName, MasterLabel, Status, TriggerType, ProcessType, 
                       CreatedDate, LastModifiedDate, Description, ApiVersion
                FROM Flow 
                WHERE DeveloperName = :flowName
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            
            if (!flows.isEmpty()) {
                Flow flow = flows[0];
                details.put('exists', true);
                details.put('flowId', flow.Id);
                details.put('status', flow.Status);
                details.put('triggerType', flow.TriggerType);
                details.put('processType', flow.ProcessType);
                details.put('description', flow.Description);
                details.put('createdDate', flow.CreatedDate);
                details.put('lastModifiedDate', flow.LastModifiedDate);
                details.put('apiVersion', flow.ApiVersion);
                details.put('isActive', flow.Status == 'Active');
                
                System.debug('Found Flow: ' + flow.DeveloperName + ', Status: ' + flow.Status);
            } else {
                details.put('exists', false);
                details.put('isActive', false);
                System.debug('Flow not found: ' + flowName);
            }
            
        } catch (Exception ex) {
            System.debug('Error getting Flow details for ' + objectApiName + ': ' + ex.getMessage());
            details.put('exists', false);
            details.put('error', ex.getMessage());
        }
        
        return details;
    }
    
    /**
     * Get Flow status for multiple objects at once
     */
    public static Map<String, Boolean> getFlowStatusMap(List<String> objectApiNames) {
        Map<String, Boolean> statusMap = new Map<String, Boolean>();
        
        if (objectApiNames == null || objectApiNames.isEmpty()) {
            return statusMap;
        }
        
        try {
            // Build Flow names
            Set<String> flowNames = new Set<String>();
            for (String objectApi : objectApiNames) {
                flowNames.add(objectApi + '_Historian_Flow');
                statusMap.put(objectApi, false); // Default to false
            }
            
            // Query all Flows at once
            List<Flow> flows = [
                SELECT Id, DeveloperName, Status 
                FROM Flow 
                WHERE DeveloperName IN :flowNames 
                  AND Status = 'Active'
            ];
            
            // Map results back to object names
            for (Flow flow : flows) {
                String objectApi = flow.DeveloperName.replace('_Historian_Flow', '');
                statusMap.put(objectApi, true);
            }
            
        } catch (Exception ex) {
            System.debug('Error getting Flow status map: ' + ex.getMessage());
        }
        
        return statusMap;
    }
    
    /**
     * Verify that a Flow deployment completed successfully
     */
    public static Boolean verifyFlowDeployment(String objectApiName) {
        try {
            Map<String, Object> details = getFlowDetails(objectApiName);
            Boolean exists = (Boolean) details.get('exists');
            Boolean isActive = (Boolean) details.get('isActive');
            
            System.debug('Flow verification for ' + objectApiName + ' - Exists: ' + exists + ', Active: ' + isActive);
            
            return exists && isActive;
            
        } catch (Exception ex) {
            System.debug('Error verifying Flow deployment for ' + objectApiName + ': ' + ex.getMessage());
            return false;
        }
    }
    
    /**
     * Get summary of all deployed Flows for Historian configurations
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getFlowDeploymentSummary() {
        Map<String, Object> summary = new Map<String, Object>();
        
        try {
            // Get all active historian configurations
            List<Historian_Config__mdt> configs = [
                SELECT Object_Api_Name__c, DeveloperName, Active__c
                FROM Historian_Config__mdt
                WHERE Active__c = true
            ];
            
            summary.put('totalActiveConfigs', configs.size());
            
            // Get Flow status for all configured objects
            List<String> objectApis = new List<String>();
            for (Historian_Config__mdt config : configs) {
                objectApis.add(config.Object_Api_Name__c);
            }
            
            Map<String, Boolean> flowStatusMap = getFlowStatusMap(objectApis);
            
            Integer deployedCount = 0;
            Integer notDeployedCount = 0;
            
            List<Map<String, Object>> objectStatus = new List<Map<String, Object>>();
            for (String objectApi : objectApis) {
                Map<String, Object> status = new Map<String, Object>();
                status.put('objectApi', objectApi);
                
                Boolean isDeployed = flowStatusMap.get(objectApi) == true;
                status.put('flowDeployed', isDeployed);
                
                if (isDeployed) {
                    deployedCount++;
                } else {
                    notDeployedCount++;
                }
                
                objectStatus.add(status);
            }
            
            summary.put('deployedFlows', deployedCount);
            summary.put('notDeployedFlows', notDeployedCount);
            summary.put('deploymentRate', objectApis.isEmpty() ? 0 : (deployedCount * 100 / objectApis.size()));
            summary.put('objectDetails', objectStatus);
            summary.put('success', true);
            
        } catch (Exception ex) {
            summary.put('success', false);
            summary.put('error', ex.getMessage());
            System.debug('Error getting Flow deployment summary: ' + ex.getMessage());
        }
        
        return summary;
    }
}