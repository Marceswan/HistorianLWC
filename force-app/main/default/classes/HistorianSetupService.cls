public with sharing class HistorianSetupService {
    @AuraEnabled(cacheable=false)
    public static Boolean mdapiRemoteSiteOk() {
        if (Test.isRunningTest()) return true;
        try {
            MetadataService.MetadataPort svc = MdapiUtil.newService();
            // Minimal listMetadata call to validate endpoint + session + remote site
            MetadataService.ListMetadataQuery q = new MetadataService.ListMetadataQuery();
            q.type_x = 'CustomObject';
            MetadataService.FileProperties[] props = svc.listMetadata(new MetadataService.ListMetadataQuery[] { q }, 42.0d);
            return true;
        } catch (Exception e) {
            return false;
        }
    }
}
