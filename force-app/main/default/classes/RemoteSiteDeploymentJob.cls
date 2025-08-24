public with sharing class RemoteSiteDeploymentJob implements Queueable, Database.AllowsCallouts {
    private String remoteSiteName;
    private String orgDomain;
    
    public RemoteSiteDeploymentJob(String remoteSiteName, String orgDomain) {
        this.remoteSiteName = remoteSiteName;
        this.orgDomain = orgDomain;
    }
    
    public void execute(QueueableContext context) {
        System.debug('=== RemoteSiteDeploymentJob.execute started ===');
        System.debug('remoteSiteName: ' + remoteSiteName);
        System.debug('orgDomain: ' + orgDomain);
        
        if (Test.isRunningTest()) {
            System.debug('Test is running, returning to avoid callouts');
            return;
        }
        
        try {
            MetadataService.MetadataPort service = MdapiUtil.newService();
            
            MetadataService.RemoteSiteSetting remoteSite = new MetadataService.RemoteSiteSetting();
            remoteSite.fullName = remoteSiteName;
            remoteSite.url = orgDomain;
            remoteSite.isActive = true;
            remoteSite.disableProtocolSecurity = false;
            remoteSite.description = 'Historian Metadata API access for automatic object creation';
            
            MetadataService.SaveResult[] results = service.createMetadata(new MetadataService.Metadata[] { remoteSite });
            
            if (results != null && results.size() > 0) {
                MetadataService.SaveResult result = results[0];
                if (result.success) {
                    System.debug('Successfully created remote site setting: ' + result.fullName);
                } else {
                    System.debug('Failed to create remote site setting: ' + result.fullName);
                    if (result.errors != null) {
                        for (MetadataService.Error err : result.errors) {
                            System.debug('Error: ' + err.message + ' (statusCode: ' + err.statusCode + ')');
                        }
                    }
                }
            }
        } catch (Exception e) {
            System.debug('Exception during remote site deployment: ' + e.getMessage());
            System.debug('Exception type: ' + e.getTypeName());
        }
    }
}