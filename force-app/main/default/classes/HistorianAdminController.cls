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
}
