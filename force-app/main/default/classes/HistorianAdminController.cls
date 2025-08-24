public with sharing class HistorianAdminController {
    @AuraEnabled
    public static String startEnsureHistorianObject(String objectApi, String configName) {
        HistorianConfigService.ConfigSummary cfg = HistorianConfigService.getActiveConfig(objectApi, configName);
        Id jobId = HistorianMetadataService.ensureHistorianObjectAsync(objectApi, cfg);
        return (String)jobId;
    }

    // Cacheable, read-only helper to check if the historian object already exists for an sObject
    @AuraEnabled(cacheable=true)
    public static Boolean isHistorianProvisioned(String objectApi) {
        if (String.isBlank(objectApi)) return false;
        String historianApi = objectApi + '_Historian__c';
        return Schema.getGlobalDescribe().containsKey(historianApi);
    }

    // Cacheable method to get record types for a given object
    @AuraEnabled(cacheable=true)
    public static List<RecordTypeOption> getRecordTypes(String objectApiName) {
        if (String.isBlank(objectApiName)) {
            return new List<RecordTypeOption>();
        }
        
        List<RecordTypeOption> options = new List<RecordTypeOption>();
        
        try {
            // Verify the object exists
            Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectApiName);
            if (objectType == null) {
                System.debug('Object does not exist: ' + objectApiName);
                return options;
            }
            
            // Get record type info for this specific object
            List<Schema.RecordTypeInfo> recordTypes = objectType.getDescribe().getRecordTypeInfos();
            
            // Filter to only active record types (excluding master if there are others)
            List<Schema.RecordTypeInfo> activeRecordTypes = new List<Schema.RecordTypeInfo>();
            for (Schema.RecordTypeInfo rtInfo : recordTypes) {
                if (rtInfo.isAvailable()) { // isAvailable() checks IsActive
                    activeRecordTypes.add(rtInfo);
                }
            }
            
            // If no active record types found or only master record type, return empty list
            if (activeRecordTypes.isEmpty() || 
                (activeRecordTypes.size() == 1 && activeRecordTypes[0].isMaster())) {
                System.debug('No non-master record types found for object: ' + objectApiName);
                return options;
            }
            
            // Add "All Record Types" option only if there are record types
            options.add(new RecordTypeOption(
                'All Record Types', 
                'ALL_RECORD_TYPES', 
                'Track all current and future record types for this object'
            ));
            
            // Add individual record types
            for (Schema.RecordTypeInfo rtInfo : activeRecordTypes) {
                // Skip master record type if there are other record types available
                if (!rtInfo.isMaster() || activeRecordTypes.size() == 1) {
                    options.add(new RecordTypeOption(
                        rtInfo.getName(), 
                        rtInfo.getRecordTypeId(),
                        'Record Type: ' + rtInfo.getName()
                    ));
                }
            }
            
            return options;
        } catch (Exception e) {
            System.debug('Error getting record types for ' + objectApiName + ': ' + e.getMessage());
            // Return empty list on error - indicates no record types available
            return options;
        }
    }

    // Inner class for record type options
    public class RecordTypeOption {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }
        @AuraEnabled public String description { get; set; }
        
        public RecordTypeOption(String label, String value, String description) {
            this.label = label;
            this.value = value;
            this.description = description;
        }
    }
}
