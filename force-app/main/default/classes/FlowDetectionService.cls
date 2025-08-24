public with sharing class FlowDetectionService {
    
    /**
     * Check if a Record-Triggered Flow is deployed for the given object
     */
    public static Boolean isFlowDeployed(String objectApiName) {
        try {
            String flowName = objectApiName + '_Historian_Flow';
            
            // Use Tooling API query approach for Flow detection
            // Since direct Flow queries can be complex, we'll use a simpler approach
            // Check if we can find any flow with the expected naming pattern
            Boolean flowExists = false;
            
            try {
                // Try to query using different approaches
                List<FlowDefinitionView> flowDefs = [SELECT Id, DurableId, ApiName FROM FlowDefinitionView WHERE ApiName = :flowName LIMIT 1];
                flowExists = !flowDefs.isEmpty();
            } catch (Exception queryEx) {
                System.debug('FlowDefinitionView query failed: ' + queryEx.getMessage());
                flowExists = false;
            }
            
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
            
            // Query FlowDefinitionView for basic Flow information
            List<FlowDefinitionView> flows = [
                SELECT Id, DurableId, ApiName, Label, Description
                FROM FlowDefinitionView 
                WHERE ApiName = :flowName
                LIMIT 1
            ];
            
            if (!flows.isEmpty()) {
                FlowDefinitionView flow = flows[0];
                details.put('exists', true);
                details.put('flowId', flow.Id);
                details.put('flowDefId', flow.DurableId);
                details.put('apiName', flow.ApiName);
                details.put('label', flow.Label);
                details.put('description', flow.Description);
                // Note: CreatedDate and LastModifiedDate not available on FlowDefinitionView
                
                // Check if there's an active version
                Boolean hasActiveVersion = false;
                try {
                    List<FlowVersionView> activeVersions = [
                        SELECT Id, Status 
                        FROM FlowVersionView 
                        WHERE FlowDefinitionViewId = :flow.DurableId 
                          AND Status = 'Active'
                        LIMIT 1
                    ];
                    hasActiveVersion = !activeVersions.isEmpty();
                    if (hasActiveVersion) {
                        details.put('status', 'Active');
                    } else {
                        details.put('status', 'Inactive');
                    }
                } catch (Exception versionEx) {
                    System.debug('Error checking active version: ' + versionEx.getMessage());
                    details.put('status', 'Unknown');
                    hasActiveVersion = false;
                }
                
                details.put('isActive', hasActiveVersion);
                
                System.debug('Found Flow: ' + flowName + ', Active: ' + hasActiveVersion);
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
            
            // Query FlowDefinitionView for all flows at once
            List<FlowDefinitionView> flowDefs = [
                SELECT Id, DurableId, ApiName
                FROM FlowDefinitionView 
                WHERE ApiName IN :flowNames
            ];
            
            // For each found flow definition, check if it has an active version
            Set<String> foundFlowDefIds = new Set<String>();
            Map<String, String> flowDefIdToApiName = new Map<String, String>();
            
            for (FlowDefinitionView flowDef : flowDefs) {
                foundFlowDefIds.add(flowDef.DurableId);
                flowDefIdToApiName.put(flowDef.DurableId, flowDef.ApiName);
            }
            
            if (!foundFlowDefIds.isEmpty()) {
                List<FlowVersionView> activeFlows = [
                    SELECT Id, FlowDefinitionViewId
                    FROM FlowVersionView 
                    WHERE FlowDefinitionViewId IN :foundFlowDefIds 
                      AND Status = 'Active'
                ];
                
                // Mark flows as active if they have an active version
                for (FlowVersionView activeFlow : activeFlows) {
                    String apiName = flowDefIdToApiName.get(activeFlow.FlowDefinitionViewId);
                    if (apiName != null) {
                        String objectApi = apiName.replace('_Historian_Flow', '');
                        statusMap.put(objectApi, true);
                    }
                }
            }
            
            // Results are already mapped in the previous block
            
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