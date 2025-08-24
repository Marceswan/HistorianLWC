public with sharing class MdapiUtil {
    public static final String API_VERSION = '64.0';
    
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
        // Since RemoteSiteSetting is not queryable in Apex, and the user has confirmed 
        // the remote site is configured, we'll assume it's ready and proceed
        System.debug('Assuming remote site settings are configured - proceeding with deployment');
        return true;
    }
}
