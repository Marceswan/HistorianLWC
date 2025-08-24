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
    public static RootConfigDTO upsertRoot(RootConfigDTO input) {
        // Debug logging
        System.debug('upsertRoot input: ' + JSON.serialize(input));
        System.debug('configName: ' + input.configName);
        System.debug('objectApiName: ' + input.objectApiName);
        
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
        
        // Upsert via MD-API wrapper for CustomMetadata
        try {
            MetadataService.MetadataPort service = MdapiUtil.newService();
            MetadataService.CustomMetadata cmd = new MetadataService.CustomMetadata();
            cmd.fullName = 'Historian_Config__mdt.' + input.developerName;
            cmd.label = input.label;
            cmd.protected_x = false;
            cmd.values = new List<MetadataService.CustomMetadataValue>();
            cmd.values.add(newMdapiKV('Config_Name__c', input.configName));
            cmd.values.add(newMdapiKV('Object_Api_Name__c', input.objectApiName));
            cmd.values.add(newMdapiKV('Tracking_Style__c', input.trackingStyle));
            cmd.values.add(newMdapiKV('Track_Mode__c', input.trackMode));
            cmd.values.add(newMdapiKV('Active__c', String.valueOf(input.active)));
            cmd.values.add(newMdapiKV('History_Object_Api__c', input.historyObjectApi));
            
            List<MetadataService.UpsertResult> results = service.upsertMetadata(
                new MetadataService.Metadata[] { cmd }
            );
            
            // Handle results and create deploy result record
            handleMdapiResults(results, 'Historian Config Creation');
            input.requestId = 'mdapi-' + System.now().getTime();
            
        } catch (Exception e) {
            System.debug('MD-API CMDT Creation Error: ' + e.getMessage());
            throw new AuraHandledException('Failed to create config: ' + e.getMessage());
        }
        
        return input;
    }

    @AuraEnabled
    public static void deleteRoot(String developerName) {
        // Soft-delete by setting Active__c = false via metadata
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
    
    private static MetadataService.CustomMetadataValue newMdapiKV(String field, String value) {
        MetadataService.CustomMetadataValue v = new MetadataService.CustomMetadataValue();
        v.field = field;
        v.value = value;
        return v;
    }
    
    private static void handleMdapiResults(List<MetadataService.UpsertResult> results, String operation) {
        for (MetadataService.UpsertResult result : results) {
            Historian_Deploy_Result__c deployResult = new Historian_Deploy_Result__c();
            deployResult.Status__c = result.success ? 'Succeeded' : 'Failed';
            deployResult.Operation__c = operation;
            deployResult.Component_Full_Name__c = result.fullName;
            
            if (!result.success && result.errors != null) {
                String errorMsg = '';
                for (MetadataService.Error error : result.errors) {
                    errorMsg += error.statusCode + ': ' + error.message + '\n';
                }
                deployResult.Error_Message__c = errorMsg.left(255);
                deployResult.Error_Count__c = result.errors.size();
            }
            
            try {
                insert deployResult;
            } catch (Exception e) {
                System.debug('Failed to insert deploy result: ' + e.getMessage());
            }
        }
    }
}
