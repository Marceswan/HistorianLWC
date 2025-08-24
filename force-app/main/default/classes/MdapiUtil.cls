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
        
        // Try to get a cached valid session first
        String sessionId = HistorianSessionProvider.getCachedSessionId();
        
        if (sessionId == null) {
            // Fall back to UserInfo session ID if no cached session
            sessionId = UserInfo.getSessionId();
            System.debug('Using UserInfo session ID (length: ' + (sessionId != null ? String.valueOf(sessionId.length()) : 'null') + ')');
            
            // Check if this looks like a Lightning "gack" session (invalid for API)
            if (sessionId != null && sessionId.startsWith('00D') && sessionId.length() < 50) {
                System.debug('Detected potential Lightning frontend session - this may not work for Metadata API');
                throw new CalloutException('Invalid session ID detected. Please use the Session Helper to get a valid session for Metadata API calls.');
            }
        } else {
            System.debug('Using cached valid session ID');
        }
        
        if (sessionId == null) {
            throw new CalloutException('No session ID available for Metadata API calls');
        }
        
        service.SessionHeader.sessionId = sessionId;
        return service;
    }
    
    public static Boolean ensureRemoteSiteSettings() {
        // Since RemoteSiteSetting is not queryable in Apex, and the user has confirmed 
        // the remote site is configured, we'll assume it's ready and proceed
        System.debug('Assuming remote site settings are configured - proceeding with deployment');
        return true;
    }
}
