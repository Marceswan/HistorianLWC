public with sharing class HistorianChangeService {
    
    // Main method that uses config developer name to look up configuration
    public static Integer createHistorianRecords(String configDeveloperName, Map<Id, SObject> oldRecords, Map<Id, SObject> newRecords) {
        if (String.isBlank(configDeveloperName) || oldRecords == null || newRecords == null || oldRecords.isEmpty() || newRecords.isEmpty()) {
            return 0;
        }
        
        try {
            // Get the configuration
            List<Historian_Config__mdt> configs = [
                SELECT DeveloperName, Config_Name__c, Object_Api_Name__c, Track_Mode__c, Record_Types__c, Active__c
                FROM Historian_Config__mdt
                WHERE DeveloperName = :configDeveloperName AND Active__c = true
                LIMIT 1
            ];
            
            if (configs.isEmpty()) {
                System.debug('No active config found for developer name: ' + configDeveloperName);
                return 0;
            }
            
            Historian_Config__mdt config = configs[0];
            String objectApiName = config.Object_Api_Name__c;
            
            // Parse record types from configuration
            Set<String> allowedRecordTypes = parseRecordTypesFromConfig(config.Record_Types__c);
            
            Integer totalChanges = 0;
            
            // Process each record
            for (Id recordId : newRecords.keySet()) {
                SObject oldRecord = oldRecords.get(recordId);
                SObject newRecord = newRecords.get(recordId);
                
                if (oldRecord == null || newRecord == null) {
                    continue;
                }
                
                // Check if this record's record type should be tracked
                if (!shouldTrackRecordType(newRecord, allowedRecordTypes)) {
                    continue;
                }
                
                // Convert to ConfigSummary for compatibility with existing logic
                HistorianConfigService.ConfigSummary cfg = new HistorianConfigService.ConfigSummary();
                cfg.configName = config.Config_Name__c;
                cfg.objectApi = config.Object_Api_Name__c;
                cfg.allFields = (config.Track_Mode__c == 'AllFields');
                cfg.fieldApis = new List<String>();
                cfg.recordTypes = new List<String>(allowedRecordTypes);
                
                // Get field configurations if not tracking all fields
                if (!cfg.allFields) {
                    for (Historian_Field_Config__mdt fc : [
                        SELECT Field_Api_Name__c
                        FROM Historian_Field_Config__mdt
                        WHERE Parent_Config__c = :config.DeveloperName AND Include__c = true
                    ]) {
                        cfg.fieldApis.add(fc.Field_Api_Name__c);
                    }
                }
                
                // Convert SObjects to field value maps
                Map<String, Object> oldVals = convertSObjectToFieldMap(oldRecord);
                Map<String, Object> newVals = convertSObjectToFieldMap(newRecord);
                
                // Apply changes using existing logic
                totalChanges += applyChanges(recordId, cfg, oldVals, newVals);
            }
            
            return totalChanges;
            
        } catch (Exception ex) {
            System.debug('Error in createHistorianRecords: ' + ex.getMessage());
            // Don't throw exception to avoid breaking the transaction
            return 0;
        }
    }
    
    public static Integer applyChanges(Id recordId, HistorianConfigService.ConfigSummary cfg, Map<String, Object> oldVals, Map<String, Object> newVals) {
        if (recordId == null || cfg == null) return 0;

        String objectApi = recordId.getSObjectType().getDescribe().getName();
        Set<String> tracked = new Set<String>();
        if (cfg.allFields == true) {
            // Track all updatable fields
            Schema.DescribeSObjectResult d = recordId.getSObjectType().getDescribe();
            for (Schema.SObjectField f : d.fields.getMap().values()) {
                Schema.DescribeFieldResult fr = f.getDescribe();
                if (fr.isUpdateable()) tracked.add(fr.getName());
            }
        } else if (cfg.fieldApis != null) {
            tracked.addAll(cfg.fieldApis);
        }

        Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(objectApi).getDescribe().fields.getMap();
        Set<String> candidates = new Set<String>();
        if (oldVals != null) candidates.addAll(oldVals.keySet());
        if (newVals != null) candidates.addAll(newVals.keySet());
        if (!tracked.isEmpty()) candidates.retainAll(tracked);

        String historianApi = objectApi + '_Historian__c';
        Schema.SObjectType histType = Schema.getGlobalDescribe().get(historianApi);

        List<SObject> rows = new List<SObject>();
        for (String api : candidates) {
            try {
                Schema.DescribeFieldResult fr = fieldMap.containsKey(api) ? fieldMap.get(api).getDescribe() : null;
                String oldStr = stringify(oldVals != null ? oldVals.get(api) : null);
                String newStr = stringify(newVals != null ? newVals.get(api) : null);
                if (equalsSafe(oldStr, newStr)) continue; // no change

                if (histType == null) {
                    // Object not provisioned; count change without DML
                    rows.add((SObject) null);
                    continue;
                }
                SObject row = histType.newSObject();
                row.put('Parent_Record__c', recordId);
                row.put('Changed_On__c', System.now());
                row.put('Changed_By__c', UserInfo.getUserId());
                row.put('Field_Changed_Api__c', api);
                row.put('Field_Changed_Label__c', fr != null ? fr.getLabel() : api);

                // Short fields (4k) store truncated; complete fields store full
                row.put('Prior_Value__c', truncateForShort(oldStr));
                row.put('New_Value__c', truncateForShort(newStr));
                row.put('Complete_Prior_Value__c', oldStr);
                row.put('Complete_New_Value__c', newStr);
                rows.add(row);
            } catch (Exception e) {
                // continue best-effort
            }
        }
        if (histType == null) {
            return rows.size();
        }
        if (!rows.isEmpty()) {
            try { insert rows; } catch (DmlException dmle) { /* swallow to avoid breaking flow */ }
        }
        return rows.size();
    }

    private static String stringify(Object v) {
        if (v == null) return null;
        if (v instanceof String) return (String) v;
        if (v instanceof Boolean) return String.valueOf((Boolean) v);
        if (v instanceof Integer) return String.valueOf((Integer) v);
        if (v instanceof Long) return String.valueOf((Long) v);
        if (v instanceof Decimal) return String.valueOf((Decimal) v);
        if (v instanceof Double) return String.valueOf((Double) v);
        if (v instanceof Date) return ((Date) v).format();
        if (v instanceof Datetime) return ((Datetime) v).formatGmt('yyyy-MM-dd HH:mm:ss');
        if (v instanceof Time) return String.valueOf((Time) v);
        return JSON.serialize(v);
    }

    private static String truncateForShort(String s) {
        if (s == null) return null;
        Integer max = 4000; // LTA short fields set to ~4k
        return s.length() > max ? s.substring(0, max) : s;
    }

    private static Boolean equalsSafe(String a, String b) {
        return (a == null && b == null) || (a != null && a.equals(b));
    }
    
    @TestVisible
    private static Set<String> parseRecordTypesFromConfig(String recordTypesString) {
        Set<String> recordTypes = new Set<String>();
        
        if (String.isNotBlank(recordTypesString)) {
            List<String> parts = recordTypesString.split(',');
            for (String part : parts) {
                String trimmed = part.trim();
                if (String.isNotBlank(trimmed)) {
                    recordTypes.add(trimmed);
                }
            }
        }
        
        return recordTypes;
    }
    
    @TestVisible
    private static Boolean shouldTrackRecordType(SObject record, Set<String> allowedRecordTypes) {
        // If no specific record types are configured, track all records
        if (allowedRecordTypes == null || allowedRecordTypes.isEmpty()) {
            return true;
        }
        
        try {
            // Get the record type developer name
            String recordTypeId = (String) record.get('RecordTypeId');
            
            // If record has no RecordTypeId, it's using the default record type
            if (String.isBlank(recordTypeId)) {
                return allowedRecordTypes.contains('Master') || allowedRecordTypes.contains('Default');
            }
            
            // Query for the record type developer name
            List<RecordType> recordTypes = [
                SELECT DeveloperName 
                FROM RecordType 
                WHERE Id = :recordTypeId 
                LIMIT 1
            ];
            
            if (!recordTypes.isEmpty()) {
                String developerName = recordTypes[0].DeveloperName;
                return allowedRecordTypes.contains(developerName);
            }
            
            return false;
            
        } catch (Exception ex) {
            System.debug('Error checking record type for tracking: ' + ex.getMessage());
            // If we can't determine the record type, default to tracking
            return true;
        }
    }
    
    @TestVisible
    private static Map<String, Object> convertSObjectToFieldMap(SObject record) {
        Map<String, Object> fieldMap = new Map<String, Object>();
        
        if (record == null) {
            return fieldMap;
        }
        
        // Get all populated fields from the SObject
        Map<String, Object> populatedFields = record.getPopulatedFieldsAsMap();
        
        for (String fieldName : populatedFields.keySet()) {
            fieldMap.put(fieldName, populatedFields.get(fieldName));
        }
        
        return fieldMap;
    }
    
}
