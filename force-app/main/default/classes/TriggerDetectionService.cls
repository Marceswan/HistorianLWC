public with sharing class TriggerDetectionService {
    
    /**
     * Check if a trigger exists for the given object using Metadata API
     */
    @AuraEnabled(cacheable=true)
    public static Boolean isTriggerDeployed(String objectApiName) {
        if (String.isBlank(objectApiName)) {
            return false;
        }
        
        String triggerName = objectApiName + 'HistorianTrigger';
        return checkTriggerExists(triggerName);
    }
    
    /**
     * Check trigger status for multiple objects
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Boolean> getTriggerStatusMap(List<String> objectApiNames) {
        Map<String, Boolean> statusMap = new Map<String, Boolean>();
        
        if (objectApiNames == null || objectApiNames.isEmpty()) {
            return statusMap;
        }
        
        for (String objectApi : objectApiNames) {
            if (String.isNotBlank(objectApi)) {
                statusMap.put(objectApi, isTriggerDeployed(objectApi));
            }
        }
        
        return statusMap;
    }
    
    /**
     * Get detailed trigger information for an object
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getTriggerDetails(String objectApiName) {
        Map<String, Object> details = new Map<String, Object>();
        
        if (String.isBlank(objectApiName)) {
            details.put('exists', false);
            details.put('error', 'Object API Name is required');
            return details;
        }
        
        String triggerName = objectApiName + 'HistorianTrigger';
        details.put('triggerName', triggerName);
        details.put('objectApiName', objectApiName);
        
        try {
            Boolean exists = checkTriggerExistsWithDetails(triggerName, details);
            details.put('exists', exists);
            details.put('checkMethod', 'Metadata API');
            details.put('checkTimestamp', System.now());
            
        } catch (Exception e) {
            details.put('exists', false);
            details.put('error', e.getMessage());
            details.put('errorType', e.getTypeName());
            System.debug('Error checking trigger details for ' + objectApiName + ': ' + e.getMessage());
        }
        
        return details;
    }
    
    /**
     * Check if trigger exists using Metadata API with detailed logging
     */
    private static Boolean checkTriggerExistsWithDetails(String triggerName, Map<String, Object> details) {
        try {
            // First try to use the existing MetadataService if remote site settings are ready
            if (!checkRemoteSiteSettings()) {
                details.put('remoteSiteReady', false);
                details.put('checkMethod', 'Remote site settings not configured');
                return false;
            }
            
            details.put('remoteSiteReady', true);
            
            MetadataService.MetadataPort service = MdapiUtil.newService();
            MetadataService.IReadResult result = service.readMetadata('ApexTrigger', new String[] { triggerName });
            
            Boolean exists = (result != null && result.getRecords() != null && result.getRecords().size() > 0);
            
            if (exists && result.getRecords().size() > 0) {
                try {
                    MetadataService.Metadata triggerMetadata = result.getRecords()[0];
                    if (triggerMetadata instanceof MetadataService.ApexTrigger) {
                        MetadataService.ApexTrigger apexTrigger = (MetadataService.ApexTrigger) triggerMetadata;
                        details.put('triggerStatus', apexTrigger.status);
                        details.put('apiVersion', String.valueOf(apexTrigger.apiVersion));
                        details.put('lastDeployedDate', System.now()); // Metadata API doesn't expose actual deployment date
                    } else {
                        details.put('triggerStatus', 'Found but unexpected metadata type');
                    }
                } catch (Exception castEx) {
                    System.debug('Error casting to ApexTrigger: ' + castEx.getMessage());
                    details.put('castError', castEx.getMessage());
                }
            }
            
            details.put('recordCount', result.getRecords() != null ? result.getRecords().size() : 0);
            
            System.debug('Trigger existence check via Metadata API - ' + triggerName + ': ' + exists);
            return exists;
            
        } catch (Exception e) {
            System.debug('Exception during Metadata API trigger check for ' + triggerName + ': ' + e.getMessage());
            details.put('metadataApiError', e.getMessage());
            return false;
        }
    }
    
    /**
     * Simple trigger existence check using Metadata API
     */
    private static Boolean checkTriggerExists(String triggerName) {
        try {
            // Check if remote site settings are ready for metadata API calls
            if (!checkRemoteSiteSettings()) {
                System.debug('Remote site settings not ready for trigger check: ' + triggerName);
                return false;
            }
            
            MetadataService.MetadataPort service = MdapiUtil.newService();
            MetadataService.IReadResult result = service.readMetadata('ApexTrigger', new String[] { triggerName });
            
            Boolean exists = (result != null && result.getRecords() != null && result.getRecords().size() > 0);
            System.debug('Trigger existence check - ' + triggerName + ': ' + exists);
            
            return exists;
            
        } catch (Exception e) {
            System.debug('Exception checking trigger existence for ' + triggerName + ': ' + e.getMessage());
            return false;
        }
    }
    
    /**
     * Check if remote site settings are properly configured for metadata API calls
     */
    private static Boolean checkRemoteSiteSettings() {
        try {
            String orgDomain = URL.getOrgDomainUrl().toExternalForm();
            String remoteSiteName = 'Historian_Metadata_API';
            
            List<SObject> existing = Database.query(
                'SELECT Id, Url, IsActive FROM RemoteSiteSetting WHERE DeveloperName = :remoteSiteName LIMIT 1'
            );
            
            if (!existing.isEmpty()) {
                SObject remoteSite = existing[0];
                Boolean isActive = (Boolean) remoteSite.get('IsActive');
                String url = (String) remoteSite.get('Url');
                
                return (isActive && url == orgDomain);
            }
            
            return false;
            
        } catch (Exception ex) {
            System.debug('Error checking remote site settings: ' + ex.getMessage());
            return false;
        }
    }
    
    /**
     * Get all historian triggers in the org (for debugging/admin purposes)
     */
    @AuraEnabled
    public static List<Map<String, String>> getAllHistorianTriggers() {
        List<Map<String, String>> triggers = new List<Map<String, String>>();
        
        try {
            if (!checkRemoteSiteSettings()) {
                return triggers; // Return empty list if remote site not ready
            }
            
            // Get all active historian configs to determine expected triggers
            List<Historian_Config__mdt> configs = [
                SELECT Object_Api_Name__c, DeveloperName, Active__c
                FROM Historian_Config__mdt
                WHERE Active__c = true
            ];
            
            Set<String> expectedTriggers = new Set<String>();
            for (Historian_Config__mdt config : configs) {
                expectedTriggers.add(config.Object_Api_Name__c + 'HistorianTrigger');
            }
            
            if (expectedTriggers.isEmpty()) {
                return triggers;
            }
            
            // Check each expected trigger
            MetadataService.MetadataPort service = MdapiUtil.newService();
            
            for (String triggerName : expectedTriggers) {
                try {
                    MetadataService.IReadResult result = service.readMetadata('ApexTrigger', new String[] { triggerName });
                    
                    Map<String, String> triggerInfo = new Map<String, String>();
                    triggerInfo.put('triggerName', triggerName);
                    
                    if (result != null && result.getRecords() != null && result.getRecords().size() > 0) {
                        try {
                            MetadataService.Metadata triggerMetadata = result.getRecords()[0];
                            triggerInfo.put('exists', 'true');
                            if (triggerMetadata instanceof MetadataService.ApexTrigger) {
                                MetadataService.ApexTrigger apexTrigger = (MetadataService.ApexTrigger) triggerMetadata;
                                triggerInfo.put('status', apexTrigger.status);
                                triggerInfo.put('apiVersion', String.valueOf(apexTrigger.apiVersion));
                            } else {
                                triggerInfo.put('status', 'Found but wrong type');
                            }
                        } catch (Exception castEx) {
                            triggerInfo.put('exists', 'true');
                            triggerInfo.put('status', 'Found but casting error');
                            triggerInfo.put('castError', castEx.getMessage());
                        }
                    } else {
                        triggerInfo.put('exists', 'false');
                        triggerInfo.put('status', 'Not Found');
                    }
                    
                    triggers.add(triggerInfo);
                    
                } catch (Exception e) {
                    Map<String, String> triggerInfo = new Map<String, String>();
                    triggerInfo.put('triggerName', triggerName);
                    triggerInfo.put('exists', 'error');
                    triggerInfo.put('error', e.getMessage());
                    triggers.add(triggerInfo);
                }
            }
            
        } catch (Exception e) {
            System.debug('Error getting all historian triggers: ' + e.getMessage());
        }
        
        return triggers;
    }
    
    /**
     * Verify that a trigger was successfully deployed by checking its existence
     * This method is designed to be called after trigger deployment
     */
    @AuraEnabled
    public static Boolean verifyTriggerDeployment(String objectApiName) {
        if (String.isBlank(objectApiName)) {
            return false;
        }
        
        System.debug('Verifying trigger deployment for: ' + objectApiName);
        
        // Wait a moment for deployment to complete if called immediately after deployment
        try {
            // Small delay to allow for deployment completion
            Long start = System.currentTimeMillis();
            while (System.currentTimeMillis() - start < 2000) {
                // 2-second wait
            }
        } catch (Exception e) {
            // Continue if wait fails
        }
        
        Boolean triggerExists = isTriggerDeployed(objectApiName);
        System.debug('Trigger deployment verification for ' + objectApiName + ': ' + triggerExists);
        
        return triggerExists;
    }
}