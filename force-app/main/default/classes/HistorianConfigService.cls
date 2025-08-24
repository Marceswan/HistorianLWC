public with sharing class HistorianConfigService {
    public class ConfigSummary {
        @AuraEnabled public String configName;
        @AuraEnabled public String objectApi;
        @AuraEnabled public Boolean allFields;
        @AuraEnabled public List<String> fieldApis;
    }

    @AuraEnabled(cacheable=true)
    public static List<ConfigSummary> listActiveConfigs(String objectApi) {
        List<ConfigSummary> out = new List<ConfigSummary>();
        try {
            List<Historian_Config__mdt> roots = [
                SELECT DeveloperName, Config_Name__c, Object_Api_Name__c, Active__c, Track_Mode__c
                FROM Historian_Config__mdt
                WHERE Active__c = true AND Object_Api_Name__c = :objectApi
            ];
            for (Historian_Config__mdt r : roots) {
                ConfigSummary cs = new ConfigSummary();
                cs.configName = r.Config_Name__c;
                cs.objectApi = r.Object_Api_Name__c;
                cs.allFields = (r.Track_Mode__c == 'AllFields');
                cs.fieldApis = new List<String>();
                if (!cs.allFields) {
                    for (Historian_Field_Config__mdt fc : [
                        SELECT Field_Api_Name__c, Include__c, Parent_Config__c
                        FROM Historian_Field_Config__mdt
                        WHERE Parent_Config__c = :r.DeveloperName AND Include__c = true
                    ]) {
                        cs.fieldApis.add(fc.Field_Api_Name__c);
                    }
                }
                out.add(cs);
            }
        } catch (Exception e) {
            // return empty on error to avoid breaking flows
        }
        return out;
    }

    public static ConfigSummary getActiveConfig(String objectApi, String configName) {
        List<ConfigSummary> configs = listActiveConfigs(objectApi);
        if (String.isNotBlank(configName)) {
            for (ConfigSummary c : configs) if (c.configName == configName) return c;
        }
        return configs.isEmpty() ? defaultAllFields(objectApi) : configs[0];
    }

    private static ConfigSummary defaultAllFields(String objectApi) {
        ConfigSummary cs = new ConfigSummary();
        cs.configName = 'Default';
        cs.objectApi = objectApi;
        cs.allFields = true;
        cs.fieldApis = new List<String>();
        return cs;
    }
}
