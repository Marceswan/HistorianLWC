public with sharing class HistorianTriggerHandler {
    
    public static void handleAfterUpdate(String objectApiName, List<SObject> oldRecords, List<SObject> newRecords) {
        if (oldRecords == null || newRecords == null || oldRecords.isEmpty() || newRecords.isEmpty()) {
            return;
        }
        
        try {
            System.debug('HistorianTriggerHandler.handleAfterUpdate called for ' + objectApiName + ' with ' + newRecords.size() + ' records');
            
            // Query active historian configuration for this object
            List<Historian_Config__mdt> configs = getActiveConfig(objectApiName);
            if (configs.isEmpty()) {
                System.debug('No active historian configuration found for ' + objectApiName);
                return;
            }
            
            Historian_Config__mdt config = configs[0];
            System.debug('Processing changes with config: ' + config.DeveloperName);
            
            // Process changes based on tracking mode
            if (config.Track_Mode__c == 'AllFields') {
                processAllFieldsChanges(config, oldRecords, newRecords);
            } else if (config.Track_Mode__c == 'PerField') {
                processPerFieldChanges(config, oldRecords, newRecords);
            }
            
        } catch (Exception e) {
            System.debug('Error in HistorianTriggerHandler.handleAfterUpdate: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
    }
    
    private static List<Historian_Config__mdt> getActiveConfig(String objectApiName) {
        return [
            SELECT Id, DeveloperName, Object_Api_Name__c, Track_Mode__c, 
                   Tracking_Style__c, Active__c, History_Object_Api__c
            FROM Historian_Config__mdt 
            WHERE Object_Api_Name__c = :objectApiName 
              AND Active__c = true
            LIMIT 1
        ];
    }
    
    private static void processAllFieldsChanges(Historian_Config__mdt config, List<SObject> oldRecords, List<SObject> newRecords) {
        Map<Id, SObject> oldMap = new Map<Id, SObject>(oldRecords);
        Map<Id, SObject> newMap = new Map<Id, SObject>(newRecords);
        
        System.debug('Processing all fields changes for ' + newRecords.size() + ' records');
        
        for (SObject newRecord : newRecords) {
            SObject oldRecord = oldMap.get(newRecord.Id);
            if (oldRecord != null) {
                logRecordChanges(config, oldRecord, newRecord);
            }
        }
    }
    
    private static void processPerFieldChanges(Historian_Config__mdt config, List<SObject> oldRecords, List<SObject> newRecords) {
        // Query field configurations for this config
        List<Historian_Field_Config__mdt> fieldConfigs = [
            SELECT Field_Api_Name__c, Include__c
            FROM Historian_Field_Config__mdt
            WHERE Parent_Config__c = :config.DeveloperName
              AND Include__c = true
        ];
        
        if (fieldConfigs.isEmpty()) {
            System.debug('No field configurations found for ' + config.DeveloperName);
            return;
        }
        
        Set<String> fieldsToTrack = new Set<String>();
        for (Historian_Field_Config__mdt fieldConfig : fieldConfigs) {
            fieldsToTrack.add(fieldConfig.Field_Api_Name__c);
        }
        
        Map<Id, SObject> oldMap = new Map<Id, SObject>(oldRecords);
        Map<Id, SObject> newMap = new Map<Id, SObject>(newRecords);
        
        System.debug('Processing per-field changes for ' + newRecords.size() + ' records, tracking ' + fieldsToTrack.size() + ' fields');
        
        for (SObject newRecord : newRecords) {
            SObject oldRecord = oldMap.get(newRecord.Id);
            if (oldRecord != null) {
                logFieldSpecificChanges(config, oldRecord, newRecord, fieldsToTrack);
            }
        }
    }
    
    private static void logRecordChanges(Historian_Config__mdt config, SObject oldRecord, SObject newRecord) {
        // For now, log changes to debug. In production this would create historian records
        String recordName = getRecordName(newRecord);
        
        Map<String, Object> oldFields = oldRecord.getPopulatedFieldsAsMap();
        Map<String, Object> newFields = newRecord.getPopulatedFieldsAsMap();
        
        Integer changeCount = 0;
        for (String fieldName : newFields.keySet()) {
            Object oldValue = oldFields.get(fieldName);
            Object newValue = newFields.get(fieldName);
            
            if (oldValue != newValue) {
                System.debug('Field changed - ' + recordName + '.' + fieldName + ': ' + oldValue + ' -> ' + newValue);
                changeCount++;
            }
        }
        
        if (changeCount > 0) {
            System.debug('Total changes for ' + recordName + ': ' + changeCount + ' fields');
        }
    }
    
    private static void logFieldSpecificChanges(Historian_Config__mdt config, SObject oldRecord, SObject newRecord, Set<String> fieldsToTrack) {
        String recordName = getRecordName(newRecord);
        
        Integer changeCount = 0;
        for (String fieldName : fieldsToTrack) {
            try {
                Object oldValue = oldRecord.get(fieldName);
                Object newValue = newRecord.get(fieldName);
                
                if (oldValue != newValue) {
                    System.debug('Tracked field changed - ' + recordName + '.' + fieldName + ': ' + oldValue + ' -> ' + newValue);
                    changeCount++;
                }
            } catch (Exception e) {
                System.debug('Error accessing field ' + fieldName + ' on ' + recordName + ': ' + e.getMessage());
            }
        }
        
        if (changeCount > 0) {
            System.debug('Total tracked changes for ' + recordName + ': ' + changeCount + ' fields');
        }
    }
    
    private static String getRecordName(SObject record) {
        try {
            if (record.get('Name') != null) {
                return (String) record.get('Name');
            }
        } catch (Exception e) {
            // Name field might not exist
        }
        
        return record.getSObjectType().getDescribe().getName() + ' (' + record.Id + ')';
    }
}