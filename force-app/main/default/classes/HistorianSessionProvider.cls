public with sharing class HistorianSessionProvider {
    
    private static String cachedSessionId;
    private static String cachedEndpoint;
    private static DateTime cacheExpiry;
    
    @AuraEnabled
    public static Map<String, String> getSessionInfo() {
        Map<String, String> result = new Map<String, String>();
        
        try {
            // Check if we have cached session info that's still valid
            if (cachedSessionId != null && cacheExpiry != null && System.now() < cacheExpiry) {
                result.put('sessionId', cachedSessionId);
                result.put('endpoint', cachedEndpoint);
                result.put('source', 'cache');
                return result;
            }
            
            // Try to get session directly first
            String directSessionId = UserInfo.getSessionId();
            String endpoint = MdapiUtil.metadataEndpoint();
            
            // Test if this session works for Metadata API
            if (isSessionValid(directSessionId, endpoint)) {
                System.debug('Direct session ID is valid for Metadata API');
                cacheSession(directSessionId, endpoint);
                result.put('sessionId', directSessionId);
                result.put('endpoint', endpoint);
                result.put('source', 'direct');
                return result;
            } else {
                System.debug('Direct session ID is not valid - need Visualforce helper');
                result.put('needsVfHelper', 'true');
                result.put('vfHelperUrl', '/apex/historiansessionhelper');
                result.put('error', 'Session from UserInfo.getSessionId() is not valid for Metadata API calls');
                return result;
            }
            
        } catch (Exception e) {
            System.debug('Error getting session info: ' + e.getMessage());
            result.put('error', e.getMessage());
            result.put('needsVfHelper', 'true');
            result.put('vfHelperUrl', '/apex/historiansessionhelper');
            return result;
        }
    }
    
    @AuraEnabled
    public static Map<String, String> setSessionFromVf(String sessionId, String endpoint) {
        Map<String, String> result = new Map<String, String>();
        
        try {
            if (String.isBlank(sessionId)) {
                result.put('error', 'Session ID is required');
                return result;
            }
            
            // Test the provided session
            if (isSessionValid(sessionId, endpoint)) {
                cacheSession(sessionId, endpoint);
                result.put('success', 'true');
                result.put('sessionId', sessionId);
                result.put('endpoint', endpoint);
                System.debug('Successfully cached valid session from VF helper');
            } else {
                result.put('error', 'Provided session ID is not valid for Metadata API');
            }
            
        } catch (Exception e) {
            System.debug('Error setting session from VF: ' + e.getMessage());
            result.put('error', e.getMessage());
        }
        
        return result;
    }
    
    @AuraEnabled
    public static String getCachedSessionId() {
        if (cachedSessionId != null && cacheExpiry != null && System.now() < cacheExpiry) {
            return cachedSessionId;
        }
        return null;
    }
    
    private static Boolean isSessionValid(String sessionId, String endpoint) {
        if (String.isBlank(sessionId) || String.isBlank(endpoint)) {
            return false;
        }
        
        try {
            // Create a test metadata service to validate the session
            MetadataService.MetadataPort testService = new MetadataService.MetadataPort();
            testService.endpoint_x = endpoint;
            testService.SessionHeader = new MetadataService.SessionHeader_element();
            testService.SessionHeader.sessionId = sessionId;
            
            // Try a simple read operation - if it doesn't throw INVALID_SESSION_ID, session is valid
            testService.readMetadata('CustomObject', new String[]{'Account'});
            return true;
            
        } catch (Exception e) {
            if (e.getMessage().contains('INVALID_SESSION_ID')) {
                System.debug('Session validation failed - invalid session');
                return false;
            }
            // Other errors (like permissions) suggest the session is valid
            System.debug('Session validation non-session error (session likely valid): ' + e.getMessage());
            return true;
        }
    }
    
    private static void cacheSession(String sessionId, String endpoint) {
        cachedSessionId = sessionId;
        cachedEndpoint = endpoint;
        // Cache for 4 hours to be safe (sessions usually last much longer)
        cacheExpiry = System.now().addHours(4);
        System.debug('Cached session ID for 4 hours');
    }
    
    @AuraEnabled
    public static void clearCache() {
        cachedSessionId = null;
        cachedEndpoint = null;
        cacheExpiry = null;
        System.debug('Session cache cleared');
    }
}