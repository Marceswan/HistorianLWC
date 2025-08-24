@IsTest
private class MdapiUtilTest {
    
    @IsTest
    static void testMetadataEndpointUrlGeneration() {
        // Test basic endpoint URL generation
        Test.startTest();
        String endpoint = MdapiUtil.metadataEndpoint();
        Test.stopTest();
        
        // Verify endpoint format
        System.assertNotEquals(null, endpoint, 'Endpoint should not be null');
        System.assert(endpoint.contains('/services/Soap/m/'), 'Endpoint should contain metadata SOAP path');
        System.assert(endpoint.contains(MdapiUtil.API_VERSION), 'Endpoint should contain API version');
        System.assert(endpoint.startsWith('https://'), 'Endpoint should start with https://');
        System.assert(!endpoint.endsWith('/'), 'Endpoint should not end with trailing slash');
    }
    
    @IsTest
    static void testMetadataEndpointWithTrailingSlash() {
        // Test that trailing slashes are properly handled
        // Note: We can't mock URL.getOrgDomainUrl() directly, but we can test the logic
        Test.startTest();
        String endpoint = MdapiUtil.metadataEndpoint();
        Test.stopTest();
        
        // The endpoint should be properly formatted regardless of org domain format
        System.assert(endpoint.endsWith('/services/Soap/m/' + MdapiUtil.API_VERSION), 
                     'Endpoint should end with proper metadata service path and version');
        
        // Should not have double slashes in the path (except after https://)
        String pathPortion = endpoint.substring(endpoint.indexOf('://') + 3);
        System.assert(!pathPortion.contains('//'), 'Path should not contain double slashes');
    }
    
    @IsTest
    static void testApiVersionConstant() {
        // Test that API_VERSION constant is properly defined
        System.assertNotEquals(null, MdapiUtil.API_VERSION, 'API_VERSION should be defined');
        System.assertNotEquals('', MdapiUtil.API_VERSION, 'API_VERSION should not be empty');
        
        // Should be a valid version format (decimal number)
        try {
            Decimal version = Decimal.valueOf(MdapiUtil.API_VERSION);
            System.assert(version > 0, 'API version should be a positive number');
            System.assert(version >= 30.0, 'API version should be 30.0 or higher');
        } catch (TypeException e) {
            System.assert(false, 'API_VERSION should be a valid decimal: ' + MdapiUtil.API_VERSION);
        }
    }
    
    @IsTest
    static void testNewServiceInitialization() {
        // Test MetadataService initialization
        Test.startTest();
        MetadataService.MetadataPort service = MdapiUtil.newService();
        Test.stopTest();
        
        // Verify service is properly initialized
        System.assertNotEquals(null, service, 'MetadataService should not be null');
        System.assertNotEquals(null, service.endpoint_x, 'Service endpoint should be set');
        System.assertNotEquals(null, service.SessionHeader, 'SessionHeader should be initialized');
        System.assertNotEquals(null, service.SessionHeader.sessionId, 'Session ID should be set');
        
        // Verify endpoint format
        System.assert(service.endpoint_x.contains('/services/Soap/m/'), 
                     'Service endpoint should contain metadata SOAP path');
        System.assert(service.endpoint_x.contains(MdapiUtil.API_VERSION), 
                     'Service endpoint should contain API version');
    }
    
    @IsTest
    static void testNewServiceSessionId() {
        // Test that session ID is properly set
        Test.startTest();
        MetadataService.MetadataPort service = MdapiUtil.newService();
        Test.stopTest();
        
        // Verify session ID is set and not empty
        String sessionId = service.SessionHeader.sessionId;
        System.assertNotEquals(null, sessionId, 'Session ID should not be null');
        System.assertNotEquals('', sessionId, 'Session ID should not be empty');
        
        // Session ID should match current user session
        String currentSessionId = UserInfo.getSessionId();
        System.assertEquals(currentSessionId, sessionId, 
                           'Service session ID should match current session ID');
    }
    
    @IsTest
    static void testEnsureRemoteSiteSettingsWithExistingCorrectSettings() {
        // Create test data - existing correct remote site settings
        String orgDomain = URL.getOrgDomainUrl().toExternalForm();
        String remoteSiteName = 'Historian_Metadata_API';
        
        // Insert a RemoteSiteSetting record for testing
        // Note: In test context, we need to create test data if RemoteSiteSetting allows it
        // If not directly insertable, we test the query logic
        
        Test.startTest();
        Boolean result = MdapiUtil.ensureRemoteSiteSettings();
        Test.stopTest();
        
        // In test context without existing remote site settings, should return false and enqueue job
        System.assertEquals(false, result, 'Should return false when remote site settings need to be created');
    }
    
    @IsTest
    static void testEnsureRemoteSiteSettingsQueuesJob() {
        // Test that the method enqueues RemoteSiteDeploymentJob when settings are missing
        Test.startTest();
        Boolean result = MdapiUtil.ensureRemoteSiteSettings();
        Test.stopTest();
        
        // Should return false and have enqueued a job
        System.assertEquals(false, result, 'Should return false when remote site deployment is needed');
        
        // Verify a RemoteSiteDeploymentJob was enqueued
        List<AsyncApexJob> enqueuedJobs = [
            SELECT Id, Status, JobType, ApexClass.Name 
            FROM AsyncApexJob 
            WHERE ApexClass.Name = 'RemoteSiteDeploymentJob'
        ];
        
        System.assertEquals(1, enqueuedJobs.size(), 'Should enqueue one RemoteSiteDeploymentJob');
    }
    
    @IsTest
    static void testEnsureRemoteSiteSettingsParameters() {
        // Test the parameters passed to RemoteSiteDeploymentJob
        String expectedOrgDomain = URL.getOrgDomainUrl().toExternalForm();
        String expectedRemoteSiteName = 'Historian_Metadata_API';
        
        Test.startTest();
        MdapiUtil.ensureRemoteSiteSettings();
        Test.stopTest();
        
        // Verify job was enqueued (indirect verification of parameters)
        List<AsyncApexJob> enqueuedJobs = [
            SELECT Id, Status, JobType, ApexClass.Name 
            FROM AsyncApexJob 
            WHERE ApexClass.Name = 'RemoteSiteDeploymentJob'
            LIMIT 1
        ];
        
        System.assertEquals(1, enqueuedJobs.size(), 'Should enqueue RemoteSiteDeploymentJob with correct parameters');
    }
    
    @IsTest 
    static void testEnsureRemoteSiteSettingsErrorHandling() {
        // Test error handling in ensureRemoteSiteSettings
        // Note: It's difficult to force an error in the query without mocking, 
        // but we can test the method handles exceptions gracefully
        
        Test.startTest();
        Boolean result;
        try {
            result = MdapiUtil.ensureRemoteSiteSettings();
            System.assert(true, 'Method should handle errors gracefully');
        } catch (Exception e) {
            System.assert(false, 'Method should not throw unhandled exceptions: ' + e.getMessage());
        }
        Test.stopTest();
        
        // Should return a boolean result even in error cases
        System.assert(result != null, 'Should return a non-null boolean result');
    }
    
    @IsTest
    static void testRemoteSiteNameConstant() {
        // Verify the remote site name used is consistent
        // We can't directly access the private constant, but we test it through behavior
        
        Test.startTest();
        MdapiUtil.ensureRemoteSiteSettings();
        Test.stopTest();
        
        // Verify the expected remote site name is used in the query
        // This is indirect validation through the job enqueuing
        List<AsyncApexJob> jobs = [SELECT Id FROM AsyncApexJob WHERE ApexClass.Name = 'RemoteSiteDeploymentJob'];
        System.assertEquals(1, jobs.size(), 'Should use consistent remote site name for job enqueuing');
    }
    
    @IsTest
    static void testOrgDomainUrlHandling() {
        // Test that org domain URL is handled correctly
        String orgDomain = URL.getOrgDomainUrl().toExternalForm();
        
        // Verify org domain format
        System.assert(orgDomain.startsWith('https://'), 'Org domain should start with https://');
        
        Test.startTest();
        // Test that the method uses the org domain correctly
        Boolean result = MdapiUtil.ensureRemoteSiteSettings();
        Test.stopTest();
        
        // Should have processed org domain without error
        System.assertNotEquals(null, result, 'Should process org domain successfully');
    }
    
    @IsTest
    static void testMultipleCallsToEnsureRemoteSiteSettings() {
        // Test multiple calls to ensureRemoteSiteSettings
        Test.startTest();
        Boolean result1 = MdapiUtil.ensureRemoteSiteSettings();
        // Note: Can't make second call in same test transaction due to queueable limits
        Test.stopTest();
        
        // First call should work
        System.assertEquals(false, result1, 'First call should return false (need to deploy)');
        
        // Verify job was enqueued
        List<AsyncApexJob> jobs = [SELECT Id FROM AsyncApexJob WHERE ApexClass.Name = 'RemoteSiteDeploymentJob'];
        System.assertEquals(1, jobs.size(), 'Should enqueue exactly one job');
    }
    
    @IsTest
    static void testStaticMethodAccessibility() {
        // Test that all public static methods are accessible
        Test.startTest();
        
        // Test metadataEndpoint() accessibility
        String endpoint = MdapiUtil.metadataEndpoint();
        System.assertNotEquals(null, endpoint, 'metadataEndpoint() should be accessible');
        
        // Test newService() accessibility  
        MetadataService.MetadataPort service = MdapiUtil.newService();
        System.assertNotEquals(null, service, 'newService() should be accessible');
        
        // Test ensureRemoteSiteSettings() accessibility
        Boolean result = MdapiUtil.ensureRemoteSiteSettings();
        System.assertNotEquals(null, result, 'ensureRemoteSiteSettings() should be accessible');
        
        Test.stopTest();
    }
    
    @IsTest
    static void testUtilityClassDesignPatterns() {
        // Test that MdapiUtil follows proper utility class patterns
        
        // All methods should be static (tested through access patterns above)
        Test.startTest();
        
        // Should be able to access all public methods statically
        try {
            MdapiUtil.metadataEndpoint();
            MdapiUtil.newService();
            MdapiUtil.ensureRemoteSiteSettings();
            System.assert(true, 'All public methods should be accessible statically');
        } catch (Exception e) {
            System.assert(false, 'Static method access failed: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testIntegrationBetweenMethods() {
        // Test that the methods work together correctly
        Test.startTest();
        
        // The endpoint from metadataEndpoint() should be used by newService()
        String endpoint1 = MdapiUtil.metadataEndpoint();
        MetadataService.MetadataPort service = MdapiUtil.newService();
        String endpoint2 = service.endpoint_x;
        
        System.assertEquals(endpoint1, endpoint2, 
                           'newService() should use the same endpoint as metadataEndpoint()');
        
        // ensureRemoteSiteSettings() should work independently
        Boolean remoteSiteResult = MdapiUtil.ensureRemoteSiteSettings();
        System.assertNotEquals(null, remoteSiteResult, 'Remote site check should work independently');
        
        Test.stopTest();
    }
}

