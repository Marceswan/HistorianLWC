public with sharing class HistorianConfigAdminService {
    public class RootConfigDTO {
        @AuraEnabled public String developerName;
        @AuraEnabled public String label;
        @AuraEnabled public String configName;
        @AuraEnabled public String objectApiName;
        @AuraEnabled public String trackingStyle; // Timeline, Datatable, CompactCards
        @AuraEnabled public String trackMode;    // AllFields, PerField
        @AuraEnabled public Boolean active;
        @AuraEnabled public String historyObjectApi;
        @AuraEnabled public String recordTypes; // Comma-separated record type developer names
        @AuraEnabled public String requestId; // enqueueDeployment id
    }

    public class FieldConfigDTO {
        @AuraEnabled public String developerName;
        @AuraEnabled public String label;
        @AuraEnabled public String parentDeveloperName;
        @AuraEnabled public String fieldApiName;
        @AuraEnabled public Boolean include;
    }

    public class DeployResultDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String requestId;
        @AuraEnabled public String status;
        @AuraEnabled public String state;
        @AuraEnabled public Integer errorCount;
        @AuraEnabled public String componentFullName;
        @AuraEnabled public String componentType;
        @AuraEnabled public String problem;
        @AuraEnabled public Datetime completedOn;
        @AuraEnabled public Datetime createdDate;
    }

    public class ObjectSummaryDTO {
        @AuraEnabled public String objectApiName;
        @AuraEnabled public String objectLabel;
        @AuraEnabled public Boolean triggerDeployed;
        @AuraEnabled public Integer activeConfigCount;
        @AuraEnabled public Integer totalRecordTypes;
        @AuraEnabled public Boolean historyObjectExists;
        @AuraEnabled public Datetime lastUpdated;
    }

    @AuraEnabled(cacheable=true)
    public static List<ObjectSummaryDTO> getObjectSummaries() {
        List<ObjectSummaryDTO> summaries = new List<ObjectSummaryDTO>();
        
        try {
            System.debug('Starting getObjectSummaries execution');
            
            // Get global describe to validate objects and get labels
            Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
            
            // Query all active configs grouped by object
            Map<String, List<Historian_Config__mdt>> configsByObject = new Map<String, List<Historian_Config__mdt>>();
            Map<String, Datetime> lastUpdatedByObject = new Map<String, Datetime>();
            
            for (Historian_Config__mdt config : [
                SELECT Object_Api_Name__c, Record_Types__c, DeveloperName, Label
                FROM Historian_Config__mdt
                WHERE Active__c = true
                ORDER BY Object_Api_Name__c
            ]) {
                String objectApi = config.Object_Api_Name__c;
                
                // Group configs by object
                if (!configsByObject.containsKey(objectApi)) {
                    configsByObject.put(objectApi, new List<Historian_Config__mdt>());
                }
                configsByObject.get(objectApi).add(config);
                
                // Track a placeholder date since CMDT doesn't expose CreatedDate/LastModifiedDate 
                Datetime configLastUpdated = System.now(); // Using current time as placeholder
                if (!lastUpdatedByObject.containsKey(objectApi)) {
                    lastUpdatedByObject.put(objectApi, configLastUpdated);
                }
            }
            
            System.debug('Found configs for ' + configsByObject.size() + ' objects');
            
            // Get real Trigger deployment status using TriggerDetectionService
            Map<String, Boolean> triggerStatusByObject = new Map<String, Boolean>();
            List<String> objectApiList = new List<String>(configsByObject.keySet());

            try {
                // Use batch Trigger detection for better performance
                triggerStatusByObject = TriggerDetectionService.getTriggerStatusMap(objectApiList);
                System.debug('Retrieved Trigger status for ' + triggerStatusByObject.size() + ' objects');
            } catch (Exception ex) {
                System.debug('Error getting Trigger status, falling back to individual checks: ' + ex.getMessage());
                // Fallback to individual checks if batch fails
                for (String objectApi : configsByObject.keySet()) {
                    try {
                        Boolean triggerExists = TriggerDetectionService.isTriggerDeployed(objectApi);
                        triggerStatusByObject.put(objectApi, triggerExists);
                    } catch (Exception individualEx) {
                        System.debug('Error checking Trigger for ' + objectApi + ': ' + individualEx.getMessage());
                        triggerStatusByObject.put(objectApi, false); // Default to false on error
                    }
                }
            }
            
            // Build summaries for each object
            for (String objectApi : configsByObject.keySet()) {
                try {
                    ObjectSummaryDTO summary = new ObjectSummaryDTO();
                    summary.objectApiName = objectApi;
                    summary.activeConfigCount = configsByObject.get(objectApi).size();
                    summary.lastUpdated = lastUpdatedByObject.get(objectApi);
                    
                    // Get object label from schema
                    if (globalDescribe.containsKey(objectApi)) {
                        Schema.SObjectType sObjectType = globalDescribe.get(objectApi);
                        Schema.DescribeSObjectResult objectDescribe = sObjectType.getDescribe();
                        summary.objectLabel = objectDescribe.getLabel();
                    } else {
                        summary.objectLabel = objectApi; // Fallback to API name if object not found
                        System.debug('Warning: Object ' + objectApi + ' not found in schema');
                    }
                    
                    // Check if trigger is deployed
                    summary.triggerDeployed = triggerStatusByObject.get(objectApi) == true;
                    
                    // Check if history object exists
                    String historyObjectApi = objectApi + '_Historian__c';
                    summary.historyObjectExists = globalDescribe.containsKey(historyObjectApi);
                    
                    // Count total record types across all configs for this object
                    Set<String> recordTypesSet = new Set<String>();
                    for (Historian_Config__mdt config : configsByObject.get(objectApi)) {
                        if (String.isNotBlank(config.Record_Types__c)) {
                            List<String> recordTypes = config.Record_Types__c.split(',');
                            for (String rt : recordTypes) {
                                String cleanRt = rt.trim();
                                if (String.isNotBlank(cleanRt)) {
                                    recordTypesSet.add(cleanRt);
                                }
                            }
                        }
                    }
                    summary.totalRecordTypes = recordTypesSet.size();
                    
                    summaries.add(summary);
                    
                } catch (Exception objEx) {
                    System.debug('Error processing object ' + objectApi + ': ' + objEx.getMessage());
                    // Continue processing other objects even if one fails
                    continue;
                }
            }
            
            System.debug('Successfully built ' + summaries.size() + ' object summaries');
            
        } catch (Exception e) {
            System.debug('Error in getObjectSummaries: ' + e.getMessage());
            throw new AuraHandledException('Failed to retrieve object summaries: ' + e.getMessage());
        }
        
        return summaries;
    }

    @AuraEnabled
    public static List<RootConfigDTO> listConfigsByObject(String objectApi) {
        List<RootConfigDTO> out = new List<RootConfigDTO>();
        String whereClause = String.isBlank(objectApi) ? 'WHERE Active__c = true' : 'WHERE Object_Api_Name__c = :objectApi AND Active__c = true';
        
        for (Historian_Config__mdt r : [
            SELECT DeveloperName, Label, Config_Name__c, Object_Api_Name__c, Tracking_Style__c, Track_Mode__c, Active__c, History_Object_Api__c
            FROM Historian_Config__mdt
            WHERE Object_Api_Name__c = :objectApi AND Active__c = true
            ORDER BY Config_Name__c
        ]) {
            RootConfigDTO dto = new RootConfigDTO();
            dto.developerName = r.DeveloperName;
            dto.label = r.Label;
            dto.configName = r.Config_Name__c;
            dto.objectApiName = r.Object_Api_Name__c;
            dto.trackingStyle = r.Tracking_Style__c;
            dto.trackMode = r.Track_Mode__c;
            dto.active = r.Active__c;
            dto.historyObjectApi = r.History_Object_Api__c;
            dto.recordTypes = ''; // Empty for now
            out.add(dto);
        }
        return out;
    }
    
    @AuraEnabled
    public static List<RootConfigDTO> listAllConfigs() {
        List<RootConfigDTO> out = new List<RootConfigDTO>();
        for (Historian_Config__mdt r : [
            SELECT DeveloperName, Label, Config_Name__c, Object_Api_Name__c, Tracking_Style__c, Track_Mode__c, Active__c, History_Object_Api__c
            FROM Historian_Config__mdt
            WHERE Active__c = true
            ORDER BY Object_Api_Name__c, Config_Name__c
        ]) {
            RootConfigDTO dto = new RootConfigDTO();
            dto.developerName = r.DeveloperName;
            dto.label = r.Label;
            dto.configName = r.Config_Name__c;
            dto.objectApiName = r.Object_Api_Name__c;
            dto.trackingStyle = r.Tracking_Style__c;
            dto.trackMode = r.Track_Mode__c;
            dto.active = r.Active__c;
            dto.historyObjectApi = r.History_Object_Api__c;
            dto.recordTypes = ''; // Empty for now
            out.add(dto);
        }
        return out;
    }

    @AuraEnabled
    public static List<FieldConfigDTO> listFields(String parentDeveloperName) {
        List<FieldConfigDTO> out = new List<FieldConfigDTO>();
        for (Historian_Field_Config__mdt f : [
            SELECT DeveloperName, Label, Parent_Config__c, Field_Api_Name__c, Include__c
            FROM Historian_Field_Config__mdt WHERE Parent_Config__c = :parentDeveloperName
            ORDER BY Field_Api_Name__c
        ]) {
            FieldConfigDTO dto = new FieldConfigDTO();
            dto.developerName = f.DeveloperName;
            dto.label = f.Label;
            dto.parentDeveloperName = f.Parent_Config__c;
            dto.fieldApiName = f.Field_Api_Name__c;
            dto.include = f.Include__c;
            out.add(dto);
        }
        return out;
    }

    @AuraEnabled(cacheable=true)
    public static List<DeployResultDTO> listRecentDeployResults(Integer maxResults) {
        Integer lim = (maxResults == null || maxResults < 1 || maxResults > 50) ? 10 : maxResults;
        List<DeployResultDTO> out = new List<DeployResultDTO>();
        for (Historian_Deploy_Result__c r : [
            SELECT Request_Id__c, Status__c, State__c, Error_Count__c, Component_FullName__c, Component_Type__c, Problem__c, Completed_On__c, CreatedDate
            FROM Historian_Deploy_Result__c
            ORDER BY CreatedDate DESC
            LIMIT :lim
        ]) {
            DeployResultDTO dto = new DeployResultDTO();
            dto.id = r.Id;
            dto.requestId = r.Request_Id__c;
            dto.status = r.Status__c;
            dto.state = r.State__c;
            dto.errorCount = (Integer) r.Error_Count__c;
            dto.componentFullName = r.Component_FullName__c;
            dto.componentType = r.Component_Type__c;
            dto.problem = r.Problem__c;
            dto.completedOn = r.Completed_On__c;
            dto.createdDate = r.CreatedDate;
            out.add(dto);
        }
        return out;
    }

    @AuraEnabled
    public static RootConfigDTO upsertRoot(String configName, String objectApiName, String trackingStyle, String trackMode, Boolean active, String label, String developerName, String historyObjectApi, String recordTypes) {
        // Create DTO from individual parameters to avoid serialization issues
        RootConfigDTO input = new RootConfigDTO();
        input.configName = configName;
        input.objectApiName = objectApiName;
        input.trackingStyle = trackingStyle;
        input.trackMode = trackMode;
        input.active = active;
        input.label = label;
        input.developerName = developerName;
        input.historyObjectApi = historyObjectApi;
        input.recordTypes = recordTypes;
        // Debug logging
        System.debug('=== UPSERTROOT CALLED ===');
        System.debug('Method signature expects: RootConfigDTO input');
        System.debug('Received input parameter type: ' + (input != null ? String.valueOf(input).substring(0, Math.min(String.valueOf(input).length(), 100)) : 'null'));
        System.debug('upsertRoot input JSON: ' + JSON.serialize(input));
        System.debug('input is null: ' + (input == null));
        
        // Add null check before accessing properties
        if (input == null) {
            System.debug('Input is null - throwing exception');
            throw new AuraHandledException('Input data is null - check LWC parameter binding');
        }
        
        // Log all properties individually 
        System.debug('input.configName: "' + input.configName + '"');
        System.debug('input.configName is null: ' + (input.configName == null));
        System.debug('input.configName is blank: ' + String.isBlank(input.configName));
        System.debug('input.configName length: ' + (input.configName != null ? String.valueOf(input.configName.length()) : 'null'));
        System.debug('input.configName trimmed: "' + (input.configName != null ? input.configName.trim() : 'null') + '"');
        System.debug('input.objectApiName: "' + input.objectApiName + '"');
        System.debug('input.developerName: "' + input.developerName + '"');
        System.debug('input.label: "' + input.label + '"');
        System.debug('input.trackingStyle: "' + input.trackingStyle + '"');
        System.debug('input.trackMode: "' + input.trackMode + '"');
        System.debug('input.active: ' + input.active);
        System.debug('input.historyObjectApi: "' + input.historyObjectApi + '"');
        System.debug('input.recordTypes: "' + input.recordTypes + '"');
        
        // Validate required fields
        if (input.configName == null || String.isBlank(input.configName)) {
            System.debug('Config Name validation failed: ' + input.configName);
            throw new AuraHandledException('Config Name is required');
        }
        if (input.objectApiName == null || String.isBlank(input.objectApiName)) {
            System.debug('Object API Name validation failed: ' + input.objectApiName);
            throw new AuraHandledException('Object API Name is required');
        }
        
        // Generate developerName if not provided
        if (String.isBlank(input.developerName)) {
            String devNameBase = input.objectApiName + '_' + input.configName;
            input.developerName = toDevName(devNameBase);
        }
        
        // Ensure label is set
        if (String.isBlank(input.label)) {
            input.label = input.configName;
        }

        // Set the historian object API name if not provided
        if (String.isBlank(input.historyObjectApi)) {
            input.historyObjectApi = input.objectApiName + '_Historian__c';
            System.debug('Setting default historyObjectApi: ' + input.historyObjectApi);
        }

        // Create Custom Metadata using native Salesforce Metadata API
        try {
            Metadata.CustomMetadata cmd = new Metadata.CustomMetadata();
            cmd.fullName = 'Historian_Config__mdt.' + input.developerName;
            cmd.label = input.label;
            cmd.values = new List<Metadata.CustomMetadataValue>();
            cmd.values.add(newKV('Config_Name__c', input.configName));
            cmd.values.add(newKV('Object_Api_Name__c', input.objectApiName));
            cmd.values.add(newKV('Tracking_Style__c', input.trackingStyle));
            cmd.values.add(newKV('Track_Mode__c', input.trackMode));
            cmd.values.add(newKV('Active__c', input.active));
            cmd.values.add(newKV('History_Object_Api__c', input.historyObjectApi));
            // cmd.values.add(newKV('Record_Types__c', input.recordTypes)); // Field disabled for now
            
            Metadata.DeployContainer dc = new Metadata.DeployContainer();
            dc.addMetadata(cmd);
            
            // Deploy with callback - the callback will handle success/failure tracking
            Id jobId = Metadata.Operations.enqueueDeployment(dc, new HistorianDeployCallback());
            input.requestId = jobId;
            
            System.debug('Native Metadata deployment enqueued with job ID: ' + jobId);
            
            // Check remote site settings before creating historian object
            Boolean remoteSiteReady = checkRemoteSiteSettings();
            
            // Always ensure trigger deployment for config changes
            String historianObjectApi = input.objectApiName + '_Historian__c';
            
            // Check remote site settings before any metadata operations
            if (!remoteSiteReady) {
                System.debug('Remote site settings not ready, deploying them first');
                try {
                    MdapiUtil.ensureRemoteSiteSettings();
                    // Set flag to indicate remote site deployment is in progress
                    input.requestId = 'REMOTE_SITE_DEPLOYING';
                } catch (Exception ex) {
                    System.debug('Error deploying remote site settings: ' + ex.getMessage());
                    throw new AuraHandledException('Remote site settings are required but could not be deployed automatically. Please configure them manually or contact your administrator. Error: ' + ex.getMessage());
                }
            } else {
                // Remote site settings are ready, proceed with historian setup
                if (!Schema.getGlobalDescribe().containsKey(historianObjectApi)) {
                    System.debug('Historian object ' + historianObjectApi + ' does not exist, creating it and trigger');
                } else {
                    System.debug('Historian object ' + historianObjectApi + ' already exists, ensuring trigger is up to date');
                }
                
                try {
                    // Always run the metadata job to ensure triggers are current with field configuration
                    createHistorianObjectWithErrorHandling(input.objectApiName);
                    
                    // Also ensure Flow deployment is initiated for the configuration
                    System.debug('Initiating Flow deployment for configuration: ' + input.objectApiName);
                    try {
                        String flowJobId = deployFlowForObject(input.objectApiName);
                        System.debug('Flow deployment initiated with job ID: ' + flowJobId);
                    } catch (Exception flowEx) {
                        System.debug('Error initiating Flow deployment: ' + flowEx.getMessage());
                        // Don't fail the entire operation if Flow deployment fails
                        // The user can manually deploy later
                    }
                    
                } catch (Exception ex) {
                    System.debug('Error ensuring historian setup: ' + ex.getMessage());
                    throw new AuraHandledException('Failed to ensure historian setup: ' + ex.getMessage() + '. The configuration has been saved but historian setup could not be completed automatically.');
                }
            }
            
        } catch (Exception e) {
            System.debug('Native CMDT Creation Error: ' + e.getMessage());
            throw new AuraHandledException('Failed to create config: ' + e.getMessage());
        }
        
        return input;
    }

    @AuraEnabled
    public static void deleteRoot(String developerName) {
        // Soft-delete by setting Active__c = false (CMDT hard delete requires destructive deployment)
        System.debug('Deactivating config: ' + developerName);
        Metadata.CustomMetadata cmd = new Metadata.CustomMetadata();
        cmd.fullName = 'Historian_Config__mdt.' + developerName;
        cmd.values = new List<Metadata.CustomMetadataValue>();
        cmd.values.add(newKV('Active__c', false));
        Metadata.DeployContainer dc = new Metadata.DeployContainer();
        dc.addMetadata(cmd);
        Metadata.Operations.enqueueDeployment(dc, new HistorianDeployCallback());
    }

    @AuraEnabled
    public static FieldConfigDTO upsertField(FieldConfigDTO input) {
        if (String.isBlank(input.developerName)) {
            input.developerName = toDevName(input.parentDeveloperName + '_' + input.fieldApiName);
        }
        Metadata.CustomMetadata cmd = new Metadata.CustomMetadata();
        cmd.fullName = 'Historian_Field_Config__mdt.' + input.developerName;
        cmd.label = (input.label != null ? input.label : input.fieldApiName);
        cmd.values = new List<Metadata.CustomMetadataValue>();
        cmd.values.add(newKV('Parent_Config__c', input.parentDeveloperName));
        cmd.values.add(newKV('Field_Api_Name__c', input.fieldApiName));
        cmd.values.add(newKV('Include__c', (input.include == null ? true : input.include)));
        Metadata.DeployContainer dc = new Metadata.DeployContainer();
        dc.addMetadata(cmd);
        Metadata.Operations.enqueueDeployment(dc, new HistorianDeployCallback());
        return input;
    }

    @AuraEnabled
    public static void deleteField(String developerName) {
        // Soft-delete by setting Include__c = false
        Metadata.CustomMetadata cmd = new Metadata.CustomMetadata();
        cmd.fullName = 'Historian_Field_Config__mdt.' + developerName;
        cmd.values = new List<Metadata.CustomMetadataValue>();
        cmd.values.add(newKV('Include__c', false));
        Metadata.DeployContainer dc = new Metadata.DeployContainer();
        dc.addMetadata(cmd);
        Metadata.Operations.enqueueDeployment(dc, new HistorianDeployCallback());
    }

    private static String toDevName(String s) {
        if (String.isBlank(s)) return 'Cfg_' + String.valueOf(Crypto.getRandomInteger());
        String cleaned = s.replaceAll('[^A-Za-z0-9_]', '_');
        if (cleaned.length() > 40) cleaned = cleaned.substring(0,40);
        return cleaned;
    }

    private static Boolean checkRemoteSiteSettings() {
        try {
            String orgDomain = URL.getOrgDomainUrl().toExternalForm();
            String remoteSiteName = 'Historian_Metadata_API';
            
            // Use Database.query to avoid direct RemoteSiteSetting reference issues
            List<SObject> existing = Database.query(
                'SELECT Id, Url, IsActive FROM RemoteSiteSetting WHERE DeveloperName = :remoteSiteName LIMIT 1'
            );
            
            if (!existing.isEmpty()) {
                SObject remoteSite = existing[0];
                Boolean isActive = (Boolean) remoteSite.get('IsActive');
                String url = (String) remoteSite.get('Url');
                
                if (isActive && url == orgDomain) {
                    System.debug('Remote site settings are properly configured');
                    return true;
                }
            }
            
            System.debug('Remote site settings missing or incorrect');
            return false;
        } catch (Exception ex) {
            System.debug('Error checking remote site settings: ' + ex.getMessage());
            return false;
        }
    }
    
    private static void createHistorianObjectWithErrorHandling(String objectApiName) {
        String historianObjectApi = objectApiName + '_Historian__c';
        System.debug('Creating historian object with enhanced error handling: ' + historianObjectApi);
        
        try {
            // Validate that the source object exists
            if (!Schema.getGlobalDescribe().containsKey(objectApiName)) {
                throw new AuraHandledException('Source object "' + objectApiName + '" does not exist in this org');
            }
            
            // Use the existing mdapi job approach which we know works
            HistorianConfigService.ConfigSummary cfg = new HistorianConfigService.ConfigSummary();
            cfg.objectApi = objectApiName;
            cfg.configName = 'default';
            
            // Check if we have required permissions before enqueuing
            if (!Schema.sObjectType.AsyncApexJob.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to create background jobs for historian object creation');
            }
            
            // Enqueue the existing job that uses mdapi
            Id jobId = System.enqueueJob(new HistorianMetadataJob(objectApiName, cfg));
            System.debug('Historian object creation job enqueued with ID: ' + jobId);
            
            // Log successful job creation
            createDeploymentResultRecord('HISTORIAN_OBJECT_JOB', jobId, objectApiName + '_Historian__c', 'CustomObject', 'Queued', 0, null);
            
        } catch (AsyncException ex) {
            System.debug('AsyncException during historian creation job: ' + ex.getMessage());
            throw new AuraHandledException('Failed to queue historian object creation job: ' + ex.getMessage() + '. This may be due to too many active jobs or system limitations.');
        } catch (System.LimitException ex) {
            System.debug('LimitException during historian creation: ' + ex.getMessage());
            throw new AuraHandledException('System limits exceeded while creating historian object: ' + ex.getMessage());
        } catch (Exception ex) {
            System.debug('Unexpected error enqueuing historian creation job: ' + ex.getMessage());
            throw new AuraHandledException('Unexpected error creating historian object: ' + ex.getMessage());
        }
    }
    
    private static void createDeploymentResultRecord(String requestId, Id jobId, String componentName, String componentType, String status, Integer errorCount, String problem) {
        try {
            Historian_Deploy_Result__c result = new Historian_Deploy_Result__c(
                Request_Id__c = requestId + '_' + jobId,
                Status__c = status,
                State__c = 'InProgress',
                Error_Count__c = errorCount,
                Component_FullName__c = componentName,
                Component_Type__c = componentType,
                Problem__c = problem
            );
            insert result;
            System.debug('Created deployment result record: ' + result.Id);
        } catch (Exception ex) {
            System.debug('Error creating deployment result record: ' + ex.getMessage());
            // Don't throw - this is for tracking only
        }
    }

    private static Metadata.CustomMetadataValue newKV(String field, Object value) {
        Metadata.CustomMetadataValue v = new Metadata.CustomMetadataValue();
        v.field = field;
        if (value == null) {
            v.value = null;
        } else if (value instanceof Boolean) {
            v.value = (Boolean) value; // keep boolean type
        } else {
            v.value = String.valueOf(value);
        }
        return v;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getRecordTypesForObject(String objectApiName) {
        List<Map<String, String>> recordTypes = new List<Map<String, String>>();
        
        if (String.isBlank(objectApiName)) {
            return recordTypes;
        }
        
        try {
            // Validate that the object exists
            if (!Schema.getGlobalDescribe().containsKey(objectApiName)) {
                throw new AuraHandledException('Object "' + objectApiName + '" does not exist');
            }
            
            Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(objectApiName);
            Schema.DescribeSObjectResult objectDescribe = sObjectType.getDescribe();
            
            // Check if the object supports record types
            List<Schema.RecordTypeInfo> recordTypeInfos = objectDescribe.getRecordTypeInfos();
            
            for (Schema.RecordTypeInfo rtInfo : recordTypeInfos) {
                // Skip the default "Master" record type as it's not a real record type
                if (rtInfo.isAvailable() && !rtInfo.isMaster()) {
                    Map<String, String> recordTypeMap = new Map<String, String>();
                    recordTypeMap.put('value', rtInfo.getDeveloperName());
                    recordTypeMap.put('label', rtInfo.getName());
                    recordTypes.add(recordTypeMap);
                }
            }
            
            System.debug('Found ' + recordTypes.size() + ' record types for object: ' + objectApiName);
            
        } catch (Exception ex) {
            System.debug('Error retrieving record types for object ' + objectApiName + ': ' + ex.getMessage());
            throw new AuraHandledException('Failed to retrieve record types: ' + ex.getMessage());
        }
        
        return recordTypes;
    }
    
    @AuraEnabled
    public static Boolean validateRecordTypeDeveloperNames(String objectApiName, String recordTypesList) {
        if (String.isBlank(objectApiName) || String.isBlank(recordTypesList)) {
            return true; // Empty record types list is valid (means "all record types")
        }
        
        try {
            // Get all valid record types for the object
            List<Map<String, String>> availableRecordTypes = getRecordTypesForObject(objectApiName);
            Set<String> validDeveloperNames = new Set<String>();
            for (Map<String, String> rt : availableRecordTypes) {
                validDeveloperNames.add(rt.get('value'));
            }
            
            // Parse the comma-separated list and validate each developer name
            List<String> requestedRecordTypes = recordTypesList.split(',');
            for (String rtDevName : requestedRecordTypes) {
                String cleanedName = rtDevName.trim();
                if (String.isNotBlank(cleanedName) && !validDeveloperNames.contains(cleanedName)) {
                    throw new AuraHandledException('Invalid record type developer name: "' + cleanedName + '". Available record types: ' + String.join(new List<String>(validDeveloperNames), ', '));
                }
            }
            
            return true;
        } catch (Exception ex) {
            System.debug('Error validating record type developer names: ' + ex.getMessage());
            throw new AuraHandledException('Record type validation failed: ' + ex.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static RootConfigDTO getHistorianConfigForObject(String objectApiName) {
        if (String.isBlank(objectApiName)) {
            return null;
        }
        
        List<Historian_Config__mdt> configs = [
            SELECT DeveloperName, Label, Config_Name__c, Object_Api_Name__c, 
                   Tracking_Style__c, Track_Mode__c, Active__c, History_Object_Api__c
            FROM Historian_Config__mdt
            WHERE Object_Api_Name__c = :objectApiName AND Active__c = true
            LIMIT 1
        ];
        
        if (configs.isEmpty()) {
            return null;
        }
        
        Historian_Config__mdt config = configs[0];
        RootConfigDTO dto = new RootConfigDTO();
        dto.developerName = config.DeveloperName;
        dto.label = config.Label;
        dto.configName = config.Config_Name__c;
        dto.objectApiName = config.Object_Api_Name__c;
        dto.trackingStyle = config.Tracking_Style__c;
        dto.trackMode = config.Track_Mode__c;
        dto.active = config.Active__c;
        dto.historyObjectApi = config.History_Object_Api__c;
        
        return dto;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<SObject> getHistorianRecords(String recordId, String configName, String objectApiName, Integer maxResults) {
        if (String.isBlank(recordId) || String.isBlank(objectApiName)) {
            return new List<SObject>();
        }
        
        // Get the historian configuration to determine the history object name
        RootConfigDTO config = getHistorianConfigForObject(objectApiName);
        if (config == null || String.isBlank(config.historyObjectApi)) {
            return new List<SObject>();
        }
        
        String historyObjectName = config.historyObjectApi;
        Integer limitValue = maxResults != null ? maxResults : 100;
        
        try {
            // Build dynamic SOQL query for the history object
            String soql = 'SELECT Id, CreatedDate, CreatedBy.Name, CreatedBy.Id, ' +
                         'Field_Changed_Api__c, Field_Changed_Label__c, Prior_Value__c, New_Value__c, Parent_Record__c ' +
                         'FROM ' + historyObjectName + ' ' +
                         'WHERE Parent_Record__c = :recordId ' +
                         'ORDER BY CreatedDate DESC ' +
                         'LIMIT :limitValue';
            
            return Database.query(soql);
            
        } catch (Exception e) {
            System.debug('Error querying historian records: ' + e.getMessage());
            // Return empty list if there's an error (e.g., object doesn't exist yet)
            return new List<SObject>();
        }
    }
    
    @AuraEnabled  
    public static String deployTriggerDirectly(String objectApiName) {
        System.debug('deployTriggerDirectly called for: ' + objectApiName);
        
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
            
            // Create the trigger using a more direct approach
            String triggerName = objectApiName + 'HistorianTrigger';
            String triggerBody = buildDirectTriggerBody(triggerName, objectApiName);
            
            // Deploy using custom metadata deployment (simpler than full MetadataService)
            return deployTriggerViaCustomMetadata(triggerName, triggerBody);
            
        } catch (Exception ex) {
            System.debug('Error in deployTriggerDirectly: ' + ex.getMessage());
            throw new AuraHandledException('Failed to deploy trigger: ' + ex.getMessage());
        }
    }
    
    private static String buildDirectTriggerBody(String triggerName, String objectApiName) {
        return 'trigger ' + triggerName + ' on ' + objectApiName + ' (after update) {\n' +
               '    // Auto-generated historian trigger\n' +
               '    System.debug(\'Historian trigger executed for ' + objectApiName + '\');\n' +
               '    \n' +
               '    if (Trigger.isAfter && Trigger.isUpdate) {\n' +
               '        // TODO: Add historian change tracking logic\n' +
               '        System.debug(\'Processing ' + objectApiName + ' changes: \' + Trigger.new.size());\n' +
               '    }\n' +
               '}';
    }
    
    private static String deployTriggerViaCustomMetadata(String triggerName, String triggerBody) {
        // For now, return a placeholder job ID since direct trigger deployment
        // requires more complex metadata API setup
        String jobId = 'DIRECT_TRIGGER_' + System.currentTimeMillis();
        
        // Log the trigger that would be deployed
        System.debug('=== TRIGGER TO DEPLOY ===');
        System.debug('Name: ' + triggerName);
        System.debug('Body: ' + triggerBody);
        System.debug('========================');
        
        // Create a deployment result record
        createDeploymentResultRecord(jobId, null, triggerName, 'ApexTrigger', 'Simulated', 0, 'Direct trigger deployment simulated');
        
        return jobId;
    }
    
    @AuraEnabled
    public static Map<String, Object> diagnoseTriggerDeployment(String objectApiName) {
        Map<String, Object> diagnostic = new Map<String, Object>();
        
        try {
            // Check object exists
            diagnostic.put('objectExists', Schema.getGlobalDescribe().containsKey(objectApiName));
            
            // Check for active configs
            List<Historian_Config__mdt> configs = [
                SELECT DeveloperName, Object_Api_Name__c, Active__c
                FROM Historian_Config__mdt
                WHERE Object_Api_Name__c = :objectApiName
            ];
            diagnostic.put('totalConfigs', configs.size());
            diagnostic.put('activeConfigs', 0);
            
            for (Historian_Config__mdt config : configs) {
                if (config.Active__c) {
                    diagnostic.put('activeConfigs', (Integer)diagnostic.get('activeConfigs') + 1);
                }
            }
            
            // Check for historian object
            String historianObjectName = objectApiName + '_Historian__c';
            diagnostic.put('historianObjectExists', Schema.getGlobalDescribe().containsKey(historianObjectName));
            
            // Check for existing trigger (would need Tooling API or other approach)
            String triggerName = objectApiName + 'HistorianTrigger';
            diagnostic.put('expectedTriggerName', triggerName);
            diagnostic.put('triggerCheckStatus', 'Cannot check trigger existence without Tooling API access');
            
            // Check AsyncApexJob permissions
            diagnostic.put('canCreateAsyncJobs', Schema.sObjectType.AsyncApexJob.isAccessible());
            
            // Recent deployment results
            List<Historian_Deploy_Result__c> recentResults = [
                SELECT Request_Id__c, Status__c, Component_Type__c, Component_FullName__c, Problem__c, CreatedDate
                FROM Historian_Deploy_Result__c
                WHERE Component_FullName__c LIKE :('%' + objectApiName + '%')
                ORDER BY CreatedDate DESC
                LIMIT 5
            ];
            diagnostic.put('recentDeployments', recentResults.size());
            
            List<Map<String, String>> deploymentDetails = new List<Map<String, String>>();
            for (Historian_Deploy_Result__c result : recentResults) {
                Map<String, String> detail = new Map<String, String>();
                detail.put('requestId', result.Request_Id__c);
                detail.put('status', result.Status__c);
                detail.put('componentType', result.Component_Type__c);
                detail.put('componentName', result.Component_FullName__c);
                detail.put('problem', result.Problem__c);
                detail.put('createdDate', String.valueOf(result.CreatedDate));
                deploymentDetails.add(detail);
            }
            diagnostic.put('deploymentDetails', deploymentDetails);
            
            diagnostic.put('success', true);
            diagnostic.put('message', 'Diagnostic completed successfully');
            
        } catch (Exception ex) {
            diagnostic.put('success', false);
            diagnostic.put('error', ex.getMessage());
            diagnostic.put('errorType', ex.getTypeName());
        }
        
        return diagnostic;
    }

    @AuraEnabled
    public static String deployFlowForObject(String objectApiName) {
        System.debug('deployFlowForObject called with objectApiName: ' + objectApiName);
        
        if (String.isBlank(objectApiName)) {
            throw new AuraHandledException('Object API Name is required');
        }
        
        try {
            // Validate that the object exists
            if (!Schema.getGlobalDescribe().containsKey(objectApiName)) {
                throw new AuraHandledException('Object "' + objectApiName + '" does not exist in this org');
            }
            
            // Check if there are active configurations for this object
            List<Historian_Config__mdt> configs = [
                SELECT DeveloperName, Object_Api_Name__c, Active__c
                FROM Historian_Config__mdt
                WHERE Object_Api_Name__c = :objectApiName AND Active__c = true
                LIMIT 1
            ];
            
            if (configs.isEmpty()) {
                throw new AuraHandledException('No active historian configurations found for object: ' + objectApiName);
            }
            
            // Create configuration summary for the HistorianMetadataJob
            HistorianConfigService.ConfigSummary cfg = new HistorianConfigService.ConfigSummary();
            cfg.objectApi = objectApiName;
            cfg.configName = 'flow_deployment';
            
            // Check if we have required permissions before enqueuing
            if (!Schema.sObjectType.AsyncApexJob.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to create background jobs for Flow deployment');
            }
            
            // Enqueue the HistorianMetadataJob to deploy/update the Flow
            Id jobId = System.enqueueJob(new HistorianMetadataJob(objectApiName, cfg));
            System.debug('Flow deployment job enqueued with ID: ' + jobId);
            
            // Create deployment result record for tracking
            createDeploymentResultRecord('FLOW_DEPLOY', jobId, objectApiName + '_Historian_Flow', 'Flow', 'Queued', 0, null);
            
            return String.valueOf(jobId);
            
        } catch (AsyncException ex) {
            System.debug('AsyncException during Flow deployment: ' + ex.getMessage());
            throw new AuraHandledException('Failed to queue Flow deployment job: ' + ex.getMessage());
        } catch (System.LimitException ex) {
            System.debug('LimitException during Flow deployment: ' + ex.getMessage());
            throw new AuraHandledException('System limits exceeded while deploying Flow: ' + ex.getMessage());
        } catch (Exception ex) {
            System.debug('Unexpected error deploying Flow: ' + ex.getMessage());
            throw new AuraHandledException('Failed to deploy Flow: ' + ex.getMessage());
        }
    }
    
    /**
     * Get comprehensive diagnosis of trigger deployment issues for LibrarianLWC
     */
    @AuraEnabled
    public static Map<String, Object> getTriggerDeploymentDiagnosis() {
        Map<String, Object> diagnosis = new Map<String, Object>();
        
        try {
            // Get all active configs and their trigger status
            List<Historian_Config__mdt> configs = [
                SELECT Object_Api_Name__c, DeveloperName, Active__c, Config_Name__c
                FROM Historian_Config__mdt
                WHERE Active__c = true
            ];
            
            diagnosis.put('totalActiveConfigs', configs.size());
            
            List<Map<String, Object>> configStatus = new List<Map<String, Object>>();
            Integer triggerDeployedCount = 0;
            Integer triggerNotDeployedCount = 0;
            
            for (Historian_Config__mdt config : configs) {
                Map<String, Object> status = new Map<String, Object>();
                status.put('objectApi', config.Object_Api_Name__c);
                status.put('configName', config.Config_Name__c);
                status.put('developerName', config.DeveloperName);
                
                try {
                    // Check Flow deployment status
                    Boolean triggerDeployed = FlowDetectionService.isFlowDeployed(config.Object_Api_Name__c);
                    status.put('triggerDeployed', triggerDeployed);
                    
                    if (triggerDeployed) {
                        triggerDeployedCount++;
                    } else {
                        triggerNotDeployedCount++;
                    }
                    
                    // Check object existence
                    String historyObjectName = config.Object_Api_Name__c + '_Historian__c';
                    Boolean historyObjectExists = Schema.getGlobalDescribe().containsKey(historyObjectName);
                    status.put('historyObjectExists', historyObjectExists);
                    
                    // Check recent deployments
                    String triggerName = config.Object_Api_Name__c + 'HistorianTrigger';
                    List<Historian_Deploy_Result__c> recentDeployments = [
                        SELECT Status__c, State__c, CreatedDate, Problem__c
                        FROM Historian_Deploy_Result__c
                        WHERE Component_FullName__c = :triggerName
                        ORDER BY CreatedDate DESC
                        LIMIT 1
                    ];
                    
                    if (!recentDeployments.isEmpty()) {
                        status.put('lastDeploymentStatus', recentDeployments[0].Status__c);
                        status.put('lastDeploymentState', recentDeployments[0].State__c);
                        status.put('lastDeploymentDate', recentDeployments[0].CreatedDate);
                    } else {
                        status.put('lastDeploymentStatus', 'No deployments found');
                    }
                    
                } catch (Exception ex) {
                    status.put('error', ex.getMessage());
                }
                
                configStatus.add(status);
            }
            
            diagnosis.put('configDetails', configStatus);
            diagnosis.put('triggersDeployed', triggerDeployedCount);
            diagnosis.put('triggersNotDeployed', triggerNotDeployedCount);
            
            // Check system readiness
            Map<String, Object> systemStatus = new Map<String, Object>();
            systemStatus.put('remoteSiteSettingsReady', checkRemoteSiteSettings());
            systemStatus.put('canCreateAsyncJobs', Schema.sObjectType.AsyncApexJob.isAccessible());
            
            diagnosis.put('systemStatus', systemStatus);
            diagnosis.put('success', true);
            diagnosis.put('timestamp', System.now());
            
        } catch (Exception ex) {
            diagnosis.put('success', false);
            diagnosis.put('error', ex.getMessage());
            diagnosis.put('errorType', ex.getTypeName());
        }
        
        return diagnosis;
    }
    
    /**
     * Force refresh of trigger deployment status - useful for LibrarianLWC
     */
    @AuraEnabled
    public static Map<String, Boolean> refreshTriggerStatusForAllObjects() {
        Map<String, Boolean> statusMap = new Map<String, Boolean>();
        
        try {
            // Get all objects with active configs
            List<Historian_Config__mdt> configs = [
                SELECT Object_Api_Name__c
                FROM Historian_Config__mdt
                WHERE Active__c = true
            ];
            
            Set<String> uniqueObjects = new Set<String>();
            for (Historian_Config__mdt config : configs) {
                uniqueObjects.add(config.Object_Api_Name__c);
            }
            
            List<String> objectList = new List<String>(uniqueObjects);
            statusMap = FlowDetectionService.getFlowStatusMap(objectList);
            
            System.debug('Refreshed trigger status for ' + statusMap.size() + ' objects');
            
        } catch (Exception ex) {
            System.debug('Error refreshing trigger status: ' + ex.getMessage());
        }
        
        return statusMap;
    }
    
}
