public with sharing class HistorianChangeService {
    
    /**
     * Main entry point for capturing changes from Flow invocable actions
     */
    public static ChangeResult captureChanges(
        HistorianConfigService.ConfigSummary config,
        List<Id> recordIds,
        List<Map<String, Object>> oldRecords,
        List<Map<String, Object>> newRecords
    ) {
        System.debug('HistorianChangeService.captureChanges called for ' + recordIds.size() + ' records');
        
        ChangeResult result = new ChangeResult();
        result.success = false;
        result.recordsCreated = 0;
        result.fieldsTracked = 0;
        
        try {
            if (config == null) {
                result.errorMessage = 'Configuration is required';
                return result;
            }
            
            if (recordIds == null || recordIds.isEmpty()) {
                result.errorMessage = 'At least one record ID is required';
                return result;
            }
            
            if (newRecords == null || newRecords.isEmpty()) {
                result.errorMessage = 'New record data is required';
                return result;
            }
            
            String historianObjectApi = config.objectApi + '_Historian__c';
            
            // Ensure historian object exists
            if (!Schema.getGlobalDescribe().containsKey(historianObjectApi)) {
                result.errorMessage = 'Historian object ' + historianObjectApi + ' does not exist. Please create it first.';
                return result;
            }
            
            List<SObject> historianRecords = new List<SObject>();
            Integer totalFieldsTracked = 0;
            
            // Process each record
            for (Integer i = 0; i < recordIds.size(); i++) {
                Id recordId = recordIds[i];
                Map<String, Object> newRecord = newRecords[i];
                Map<String, Object> oldRecord = (oldRecords != null && oldRecords.size() > i) ? oldRecords[i] : null;
                
                List<SObject> recordHistorians = processRecordChanges(config, recordId, oldRecord, newRecord);
                historianRecords.addAll(recordHistorians);
                totalFieldsTracked += recordHistorians.size();
            }
            
            // Insert all historian records
            if (!historianRecords.isEmpty()) {
                try {
                    insert historianRecords;
                    result.recordsCreated = historianRecords.size();
                    result.success = true;
                    result.message = 'Successfully created ' + historianRecords.size() + ' historian records';
                    System.debug('Inserted ' + historianRecords.size() + ' historian records');
                    
                } catch (DmlException dmlEx) {
                    System.debug('DML error inserting historian records: ' + dmlEx.getMessage());
                    result.errorMessage = 'Failed to insert historian records: ' + dmlEx.getMessage();
                    return result;
                }
            } else {
                result.success = true;
                result.message = 'No field changes detected - no historian records created';
                System.debug('No field changes detected for processing');
            }
            
            result.fieldsTracked = totalFieldsTracked;
            
        } catch (Exception ex) {
            System.debug('Exception in captureChanges: ' + ex.getMessage());
            result.errorMessage = ex.getMessage();
        }
        
        return result;
    }
    
    /**
     * Process changes for a single record
     */
    private static List<SObject> processRecordChanges(
        HistorianConfigService.ConfigSummary config,
        Id recordId,
        Map<String, Object> oldRecord,
        Map<String, Object> newRecord
    ) {
        List<SObject> historianRecords = new List<SObject>();
        String historianObjectApi = config.objectApi + '_Historian__c';
        
        try {
            // Get the fields to track
            Set<String> fieldsToTrack = getFieldsToTrack(config);
            
            // Compare old vs new values for each tracked field
            for (String fieldApi : fieldsToTrack) {
                Object oldValue = (oldRecord != null) ? oldRecord.get(fieldApi) : null;
                Object newValue = newRecord.get(fieldApi);
                
                // Check if the field changed
                if (hasFieldChanged(oldValue, newValue)) {
                    SObject historianRecord = createHistorianRecord(
                        historianObjectApi,
                        recordId,
                        fieldApi,
                        oldValue,
                        newValue
                    );
                    
                    if (historianRecord != null) {
                        historianRecords.add(historianRecord);
                    }
                }
            }
            
        } catch (Exception ex) {
            System.debug('Error processing record changes for ' + recordId + ': ' + ex.getMessage());
        }
        
        return historianRecords;
    }
    
    /**
     * Get the set of fields to track based on configuration
     */
    private static Set<String> getFieldsToTrack(HistorianConfigService.ConfigSummary config) {
        Set<String> fieldsToTrack = new Set<String>();
        
        if (config.trackMode == 'AllFields') {
            // Get all accessible fields for the object
            Schema.SObjectType sobjectType = Schema.getGlobalDescribe().get(config.objectApi);
            if (sobjectType != null) {
                Schema.DescribeSObjectResult describe = sobjectType.getDescribe();
                for (Schema.SObjectField field : describe.fields.getMap().values()) {
                    Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
                    if (fieldDescribe.isAccessible() && fieldDescribe.isUpdateable()) {
                        fieldsToTrack.add(fieldDescribe.getName());
                    }
                }
            }
        } else {
            // Track specific configured fields
            for (HistorianConfigService.FieldSummary field : config.fields) {
                if (field.include) {
                    fieldsToTrack.add(field.fieldApi);
                }
            }
        }
        
        return fieldsToTrack;
    }
    
    /**
     * Check if a field value has changed
     */
    private static Boolean hasFieldChanged(Object oldValue, Object newValue) {
        // Handle nulls
        if (oldValue == null && newValue == null) {
            return false;
        }
        if (oldValue == null || newValue == null) {
            return true;
        }
        
        // Compare values - convert to strings for consistent comparison
        String oldStr = String.valueOf(oldValue);
        String newStr = String.valueOf(newValue);
        
        return !oldStr.equals(newStr);
    }
    
    /**
     * Create a historian record for a changed field
     */
    private static SObject createHistorianRecord(
        String historianObjectApi,
        Id recordId,
        String fieldApi,
        Object oldValue,
        Object newValue
    ) {
        try {
            // Get the object type
            Schema.SObjectType historianSObjectType = Schema.getGlobalDescribe().get(historianObjectApi);
            if (historianSObjectType == null) {
                System.debug('Historian object type not found: ' + historianObjectApi);
                return null;
            }
            
            SObject historianRecord = historianSObjectType.newSObject();
            
            // Get field label
            String fieldLabel = getFieldLabel(recordId.getSObjectType().getDescribe().getName(), fieldApi);
            
            // Set standard historian fields
            historianRecord.put('Parent_Record__c', recordId);
            historianRecord.put('Field_Changed_Api__c', fieldApi);
            historianRecord.put('Field_Changed_Label__c', fieldLabel);
            historianRecord.put('Changed_On__c', System.now());
            historianRecord.put('Changed_By__c', UserInfo.getUserId());
            
            // Set value fields with truncation handling
            String oldValueStr = (oldValue != null) ? String.valueOf(oldValue) : '';
            String newValueStr = (newValue != null) ? String.valueOf(newValue) : '';
            
            // Prior Value (4000 char limit)
            historianRecord.put('Prior_Value__c', truncateString(oldValueStr, 4000));
            historianRecord.put('Complete_Prior_Value__c', truncateString(oldValueStr, 32768));
            
            // New Value (4000 char limit)
            historianRecord.put('New_Value__c', truncateString(newValueStr, 4000));
            historianRecord.put('Complete_New_Value__c', truncateString(newValueStr, 32768));
            
            return historianRecord;
            
        } catch (Exception ex) {
            System.debug('Error creating historian record: ' + ex.getMessage());
            return null;
        }
    }
    
    /**
     * Get the display label for a field
     */
    private static String getFieldLabel(String objectApi, String fieldApi) {
        try {
            Schema.SObjectType sobjectType = Schema.getGlobalDescribe().get(objectApi);
            if (sobjectType != null) {
                Schema.DescribeSObjectResult describe = sobjectType.getDescribe();
                Schema.SObjectField field = describe.fields.getMap().get(fieldApi);
                if (field != null) {
                    return field.getDescribe().getLabel();
                }
            }
        } catch (Exception ex) {
            System.debug('Error getting field label: ' + ex.getMessage());
        }
        
        // Fallback to API name if label lookup fails
        return fieldApi;
    }
    
    /**
     * Truncate string to specified length
     */
    private static String truncateString(String value, Integer maxLength) {
        if (String.isBlank(value) || value.length() <= maxLength) {
            return value;
        }
        return value.substring(0, maxLength);
    }
    
    /**
     * Result class for change capture operations
     */
    public class ChangeResult {
        public Boolean success { get; set; }
        public Integer recordsCreated { get; set; }
        public Integer fieldsTracked { get; set; }
        public String message { get; set; }
        public String errorMessage { get; set; }
        
        public ChangeResult() {
            this.success = false;
            this.recordsCreated = 0;
            this.fieldsTracked = 0;
        }
        
        public ChangeResult(Boolean success, Integer recordsCreated, Integer fieldsTracked, String message, String errorMessage) {
            this.success = success;
            this.recordsCreated = recordsCreated;
            this.fieldsTracked = fieldsTracked;
            this.message = message;
            this.errorMessage = errorMessage;
        }
    }
}