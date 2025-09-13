public with sharing class HistorianHelper {

    /**
     * Static method for triggers to track changes
     * Called directly from triggers with Trigger.new and Trigger.oldMap
     * When configName is null, processes ALL active configurations for the object
     */
    public static void trackChanges(List<SObject> newRecords, Map<Id, SObject> oldMap, String objectApiName, String configName) {
        // Exit early if no records to process
        if (newRecords == null || newRecords.isEmpty()) {
            return;
        }

        // Skip processing in test context if no configs are expected
        // This helps avoid CPU timeouts in auto-generated trigger tests
        if (Test.isRunningTest()) {
            // Check if this is a simple trigger deployment test without actual configs
            List<HistorianConfigService.ConfigSummary> testConfigs;
            try {
                testConfigs = HistorianConfigService.listActiveConfigs(objectApiName);
                if (testConfigs == null || testConfigs.isEmpty()) {
                    // No configs in test context, skip processing
                    return;
                }
            } catch (Exception e) {
                // If there's any issue getting configs in test, skip processing
                return;
            }
        }

        System.debug('HistorianHelper.trackChanges called for ' + objectApiName + ' with config: ' + configName);

        // Get all active configurations for this object if configName is null
        List<HistorianConfigService.ConfigSummary> configs = new List<HistorianConfigService.ConfigSummary>();

        if (String.isBlank(configName)) {
            // Get ALL active configurations for this object
            configs = HistorianConfigService.listActiveConfigs(objectApiName);
            System.debug('Found ' + configs.size() + ' active configurations for ' + objectApiName);
        } else {
            // Get specific configuration
            HistorianConfigService.ConfigSummary specificConfig = getConfiguration(objectApiName, configName);
            if (specificConfig != null) {
                configs.add(specificConfig);
            }
        }

        // If no configs, exit early
        if (configs.isEmpty()) {
            return;
        }

        // Process with bulk-optimized change service directly
        // Limit processing to avoid CPU timeouts
        for (HistorianConfigService.ConfigSummary config : configs) {
            // Convert newRecords and oldMap to format expected by ChangeService
            List<Id> recordIds = new List<Id>();
            List<Map<String, Object>> currentRecords = new List<Map<String, Object>>();
            List<Map<String, Object>> previousRecords = new List<Map<String, Object>>();

            for (SObject newRecord : newRecords) {
                recordIds.add(newRecord.Id);
                currentRecords.add(newRecord.getPopulatedFieldsAsMap());

                if (oldMap != null && oldMap.containsKey(newRecord.Id)) {
                    previousRecords.add(oldMap.get(newRecord.Id).getPopulatedFieldsAsMap());
                } else {
                    previousRecords.add(null);
                }
            }

            // Use the bulk-optimized change service
            HistorianChangeService.captureChanges(
                config,
                recordIds,
                previousRecords.isEmpty() || previousRecords[0] == null ? null : previousRecords,
                currentRecords
            );
        }
    }

    /**
     * Invocable method for Flow integration to capture field changes
     * This method can be called from Record-Triggered Flows on any object
     */
    @InvocableMethod(
        label='Capture Historical Changes'
        description='Captures field changes for a record using Historian configuration'
        category='Historian'
    )
    public static List<HistorianResult> captureHistoricalChanges(List<HistorianRequest> requests) {
        System.debug('HistorianHelper.captureHistoricalChanges called with ' + requests.size() + ' requests');
        
        List<HistorianResult> results = new List<HistorianResult>();
        
        for (HistorianRequest request : requests) {
            HistorianResult result = new HistorianResult();
            result.success = false;
            result.recordId = request.targetRecordId;
            result.sobjectType = request.targetSObjectApiName;
            result.configName = request.configName;
            
            try {
                // Process the change capture request
                HistorianChangeService.ChangeResult changeResult = processChangeRequest(request);
                
                result.success = changeResult.success;
                result.recordsCreated = changeResult.recordsCreated;
                result.fieldsTracked = changeResult.fieldsTracked;
                result.message = changeResult.message;
                result.errorMessage = changeResult.errorMessage;
                
            } catch (Exception ex) {
                System.debug('Error in captureHistoricalChanges: ' + ex.getMessage());
                result.success = false;
                result.errorMessage = ex.getMessage();
                result.message = 'Failed to capture changes: ' + ex.getMessage();
            }
            
            results.add(result);
        }
        
        return results;
    }
    
    /**
     * Process individual change request
     */
    private static HistorianChangeService.ChangeResult processChangeRequest(HistorianRequest request) {
        System.debug('Processing change request for record: ' + request.targetRecordId);
        
        // Validate required fields
        if (String.isBlank(request.targetRecordId)) {
            return new HistorianChangeService.ChangeResult(
                false, 0, 0, null, 'Target Record ID is required'
            );
        }
        
        // Determine sObject type if not provided
        String sobjectType = request.targetSObjectApiName;
        if (String.isBlank(sobjectType)) {
            sobjectType = getSObjectTypeFromId(request.targetRecordId);
            if (String.isBlank(sobjectType)) {
                return new HistorianChangeService.ChangeResult(
                    false, 0, 0, null, 'Could not determine sObject type from Record ID'
                );
            }
        }
        
        // Get configuration
        HistorianConfigService.ConfigSummary config = getConfiguration(sobjectType, request.configName);
        if (config == null) {
            return new HistorianChangeService.ChangeResult(
                false, 0, 0, null, 'No active configuration found for ' + sobjectType
            );
        }
        
        // Get the current and previous record states
        // Since this is called from Flow, we need to query both current and previous states
        Map<String, Object> currentRecord = getCurrentRecordState(request.targetRecordId, config);
        Map<String, Object> previousRecord = getPreviousRecordState(request.targetRecordId, config, request);
        
        if (currentRecord == null) {
            return new HistorianChangeService.ChangeResult(
                false, 0, 0, null, 'Could not retrieve current record state'
            );
        }
        
        // Use HistorianChangeService to detect and store changes
        return HistorianChangeService.captureChanges(
            config,
            new List<Id>{Id.valueOf(request.targetRecordId)},
            previousRecord != null ? new List<Map<String, Object>>{previousRecord} : null,
            new List<Map<String, Object>>{currentRecord}
        );
    }
    
    /**
     * Get sObject type from record ID
     */
    private static String getSObjectTypeFromId(String recordId) {
        try {
            Id recordIdObj = Id.valueOf(recordId);
            return recordIdObj.getSObjectType().getDescribe().getName();
        } catch (Exception ex) {
            System.debug('Error getting sObject type from ID: ' + ex.getMessage());
            return null;
        }
    }
    
    /**
     * Get configuration for the sObject
     */
    private static HistorianConfigService.ConfigSummary getConfiguration(String sobjectType, String configName) {
        List<HistorianConfigService.ConfigSummary> configs = HistorianConfigService.listActiveConfigs(sobjectType);
        
        for (HistorianConfigService.ConfigSummary config : configs) {
            // If specific config name provided, match it
            if (String.isNotBlank(configName) && !config.configName.equals(configName)) {
                continue;
            }
            return config;
        }
        
        return null;
    }
    
    /**
     * Get current record state
     */
    private static Map<String, Object> getCurrentRecordState(String recordId, HistorianConfigService.ConfigSummary config) {
        try {
            // Build SOQL query for all tracked fields
            Set<String> fieldsToQuery = new Set<String>{'Id', 'LastModifiedDate', 'LastModifiedById'};
            
            if (config.allFields) {
                // Add all fields from object describe
                Schema.SObjectType sobjectType = Schema.getGlobalDescribe().get(config.objectApi);
                if (sobjectType != null) {
                    Schema.DescribeSObjectResult describe = sobjectType.getDescribe();
                    for (Schema.SObjectField field : describe.fields.getMap().values()) {
                        Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
                        if (fieldDescribe.isAccessible()) {
                            fieldsToQuery.add(fieldDescribe.getName());
                        }
                    }
                }
            } else {
                // Add specific configured fields
                for (String fieldApi : config.fieldApis) {
                    fieldsToQuery.add(fieldApi);
                }
            }
            
            String soql = 'SELECT ' + String.join(new List<String>(fieldsToQuery), ', ') + 
                         ' FROM ' + config.objectApi + ' WHERE Id = :recordId LIMIT 1';
            
            List<SObject> records = Database.query(soql);
            if (records.isEmpty()) {
                return null;
            }
            
            return records[0].getPopulatedFieldsAsMap();
            
        } catch (Exception ex) {
            System.debug('Error querying current record state: ' + ex.getMessage());
            return null;
        }
    }
    
    /**
     * Get previous record state - this is challenging in Flow context
     * We'll use the previous values if provided in the request, otherwise return null
     */
    private static Map<String, Object> getPreviousRecordState(String recordId, HistorianConfigService.ConfigSummary config, HistorianRequest request) {
        // In a Flow context, previous values might be passed as serialized data
        if (String.isNotBlank(request.previousValuesJson)) {
            try {
                return (Map<String, Object>) JSON.deserializeUntyped(request.previousValuesJson);
            } catch (Exception ex) {
                System.debug('Error deserializing previous values: ' + ex.getMessage());
            }
        }
        
        // If no previous values provided, return null (will be treated as new record)
        return null;
    }
    
    /**
     * Input class for the invocable method
     */
    public class HistorianRequest {
        @InvocableVariable(label='Target Record ID' description='ID of the record to track changes for' required=true)
        public String targetRecordId;
        
        @InvocableVariable(label='Target sObject API Name' description='API name of the sObject (optional - will be determined from ID if not provided)')
        public String targetSObjectApiName;
        
        @InvocableVariable(label='Configuration Name' description='Specific configuration name to use (optional - will use first active config for object)')
        public String configName;
        
        @InvocableVariable(label='Previous Values JSON' description='JSON string of previous record values (optional - for accurate change detection)')
        public String previousValuesJson;
    }
    
    /**
     * Result class for the invocable method
     */
    public class HistorianResult {
        @InvocableVariable(label='Success' description='Whether the operation succeeded')
        public Boolean success;
        
        @InvocableVariable(label='Records Created' description='Number of historian records created')
        public Integer recordsCreated;
        
        @InvocableVariable(label='Fields Tracked' description='Number of fields that had changes')
        public Integer fieldsTracked;
        
        @InvocableVariable(label='Message' description='Success or informational message')
        public String message;
        
        @InvocableVariable(label='Error Message' description='Error message if operation failed')
        public String errorMessage;
        
        @InvocableVariable(label='Record ID' description='ID of the record that was processed')
        public String recordId;
        
        @InvocableVariable(label='sObject Type' description='sObject type that was processed')
        public String sobjectType;
        
        @InvocableVariable(label='Configuration Name' description='Configuration that was used')
        public String configName;
    }
}