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
            
            // Check if historian object exists for this config, if not create it
            String historianObjectApi = input.objectApiName + '_Historian__c';
            if (!Schema.getGlobalDescribe().containsKey(historianObjectApi)) {
                System.debug('Historian object ' + historianObjectApi + ' does not exist, creating it');
                
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
                    // Remote site settings are ready, proceed with historian object creation
                    try {
                        createHistorianObjectWithErrorHandling(input.objectApiName);
                    } catch (Exception ex) {
                        System.debug('Error creating historian object: ' + ex.getMessage());
                        throw new AuraHandledException('Failed to create historian object: ' + ex.getMessage() + '. The configuration has been saved but the historian object could not be created automatically.');
                    }
                }
            } else {
                System.debug('Historian object ' + historianObjectApi + ' already exists');
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
    
}
