public with sharing class MdapiUtil {
    public static final String API_VERSION = '61.0';
    
    public static String metadataEndpoint() {
        String base = URL.getOrgDomainUrl().toExternalForm();
        if (base.endsWith('/')) base = base.substring(0, base.length()-1);
        return base + '/services/Soap/m/' + API_VERSION;
    }

    public static MetadataService.MetadataPort newService() {
        MetadataService.MetadataPort service = new MetadataService.MetadataPort();
        service.endpoint_x = metadataEndpoint();
        service.SessionHeader = new MetadataService.SessionHeader_element();
        service.SessionHeader.sessionId = UserInfo.getSessionId();
        return service;
    }
    
    public static Boolean ensureRemoteSiteSettings() {
        String orgDomain = URL.getOrgDomainUrl().toExternalForm();
        String remoteSiteName = 'Historian_Metadata_API';
        
        try {
            // Use SOQL query for RemoteSiteSetting - this is allowed in Apex
            List<SObject> existing = Database.query(
                'SELECT Id, Url, IsActive FROM RemoteSiteSetting WHERE DeveloperName = :remoteSiteName LIMIT 1'
            );
            
            if (!existing.isEmpty()) {
                SObject remoteSite = existing[0];
                Boolean isActive = (Boolean) remoteSite.get('IsActive');
                String url = (String) remoteSite.get('Url');
                
                if (isActive && url == orgDomain) {
                    System.debug('Remote site settings already configured correctly');
                    return true;
                }
            }
            
            System.debug('Remote site settings missing or incorrect, manual deployment required');
            // TODO: Deploy RemoteSiteDeploymentJob automatically when available
            return false;
        } catch (Exception e) {
            System.debug('Error checking remote site settings: ' + e.getMessage());
            return false;
        }
    }
}
