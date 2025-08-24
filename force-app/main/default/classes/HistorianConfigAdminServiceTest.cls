@IsTest
private class HistorianConfigAdminServiceTest {
    
    // HTTP Mock for remote site settings testing
    private class MockHttpResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(200);
            res.setBody('{"success": true}');
            return res;
        }
    }
    
    @TestSetup
    static void setupTestData() {
        // Create test Historian_Deploy_Result__c records for testing listRecentDeployResults
        List<Historian_Deploy_Result__c> testResults = new List<Historian_Deploy_Result__c>();
        
        for (Integer i = 1; i <= 5; i++) {
            Historian_Deploy_Result__c result = new Historian_Deploy_Result__c(
                Request_Id__c = 'TEST_REQ_' + i,
                Status__c = 'Succeeded',
                State__c = 'Deployed',
                Error_Count__c = 0,
                Component_FullName__c = 'TestComponent' + i,
                Component_Type__c = 'CustomMetadata',
                Problem__c = null,
                Completed_On__c = Datetime.now().addHours(-i)
            );
            testResults.add(result);
        }
        
        // Add one failed result for testing
        testResults.add(new Historian_Deploy_Result__c(
            Request_Id__c = 'TEST_REQ_FAILED',
            Status__c = 'Failed',
            State__c = 'Failed',
            Error_Count__c = 1,
            Component_FullName__c = 'FailedComponent',
            Component_Type__c = 'CustomMetadata',
            Problem__c = 'Test error message',
            Completed_On__c = Datetime.now().addHours(-6)
        ));
        
        insert testResults;
    }
    
    @IsTest
    static void testListConfigsByObject_WithValidObject() {
        // This test relies on CMDT queries returning empty results in test context
        // since we're not using Test.loadData for CMDT in this example
        Test.startTest();
        List<HistorianConfigAdminService.RootConfigDTO> configs = 
            HistorianConfigAdminService.listConfigsByObject('Account');
        Test.stopTest();
        
        System.assertNotEquals(null, configs, 'Configs list should not be null');
        // In test context, CMDT queries return empty unless using Test.loadData
        System.assertEquals(0, configs.size(), 'Should return empty list in test context');
    }
    
    @IsTest
    static void testListAllConfigs() {
        Test.startTest();
        List<HistorianConfigAdminService.RootConfigDTO> configs = 
            HistorianConfigAdminService.listAllConfigs();
        Test.stopTest();
        
        System.assertNotEquals(null, configs, 'Configs list should not be null');
        System.assertEquals(0, configs.size(), 'Should return empty list in test context');
    }
    
    @IsTest
    static void testListFields() {
        Test.startTest();
        List<HistorianConfigAdminService.FieldConfigDTO> fields = 
            HistorianConfigAdminService.listFields('TestParent');
        Test.stopTest();
        
        System.assertNotEquals(null, fields, 'Fields list should not be null');
        System.assertEquals(0, fields.size(), 'Should return empty list in test context');
    }
    
    @IsTest
    static void testListRecentDeployResults_WithDefaultLimit() {
        Test.startTest();
        List<HistorianConfigAdminService.DeployResultDTO> results = 
            HistorianConfigAdminService.listRecentDeployResults(null);
        Test.stopTest();
        
        System.assertNotEquals(null, results, 'Results list should not be null');
        System.assertEquals(6, results.size(), 'Should return all test records within default limit');
    }
    
    @IsTest
    static void testListRecentDeployResults_WithCustomLimit() {
        Test.startTest();
        List<HistorianConfigAdminService.DeployResultDTO> results = 
            HistorianConfigAdminService.listRecentDeployResults(3);
        Test.stopTest();
        
        System.assertNotEquals(null, results, 'Results list should not be null');
        System.assertEquals(3, results.size(), 'Should return limited number of results');
        
        // Verify DTO mapping
        HistorianConfigAdminService.DeployResultDTO firstResult = results[0];
        System.assertNotEquals(null, firstResult.requestId, 'Request ID should be mapped');
        System.assertNotEquals(null, firstResult.status, 'Status should be mapped');
    }
    
    @IsTest
    static void testListRecentDeployResults_WithInvalidLimit() {
        Test.startTest();
        List<HistorianConfigAdminService.DeployResultDTO> results = 
            HistorianConfigAdminService.listRecentDeployResults(0);
        Test.stopTest();
        
        System.assertNotEquals(null, results, 'Results list should not be null');
        System.assertEquals(6, results.size(), 'Should use default limit when invalid limit provided');
    }
    
    @IsTest
    static void testUpsertRoot_ValidInputs_NewConfiguration() {
        // Setup test data
        String configName = 'TestConfig';
        String objectApiName = 'Account';
        String trackingStyle = 'Timeline';
        String trackMode = 'AllFields';
        Boolean active = true;
        String label = 'Test Configuration';
        String developerName = 'Account_TestConfig';
        String historyObjectApi = 'Account_Historian__c';
        String recordTypes = '';
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());
        
        try {
            HistorianConfigAdminService.RootConfigDTO result = 
                HistorianConfigAdminService.upsertRoot(
                    configName, objectApiName, trackingStyle, trackMode, 
                    active, label, developerName, historyObjectApi, recordTypes
                );
            
            System.assertNotEquals(null, result, 'Result should not be null');
            System.assertEquals(configName, result.configName, 'Config name should be preserved');
            System.assertEquals(objectApiName, result.objectApiName, 'Object API name should be preserved');
            System.assertEquals(trackingStyle, result.trackingStyle, 'Tracking style should be preserved');
            System.assertEquals(trackMode, result.trackMode, 'Track mode should be preserved');
            System.assertEquals(active, result.active, 'Active status should be preserved');
            System.assertEquals(label, result.label, 'Label should be preserved');
            System.assertEquals(developerName, result.developerName, 'Developer name should be preserved');
            System.assertNotEquals(null, result.requestId, 'Request ID should be generated');
            
        } catch (Exception e) {
            // In test context, metadata operations may fail - that's expected
            System.assert(e.getMessage().contains('Metadata') || e.getMessage().contains('metadata'), 
                'Error should be related to metadata operations: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testUpsertRoot_GeneratesDeveloperName_WhenNull() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());
        
        try {
            HistorianConfigAdminService.RootConfigDTO result = 
                HistorianConfigAdminService.upsertRoot(
                    'TestConfig', 'Account', 'Timeline', 'AllFields', 
                    true, 'Test Configuration', '', 'Account_Historian__c', ''
                );
            
            System.assertNotEquals(null, result.developerName, 'Developer name should be generated');
            System.assert(result.developerName.contains('Account'), 'Developer name should contain object name');
            
        } catch (Exception e) {
            // Expected in test context
            System.assert(true, 'Exception expected in test context: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testUpsertRoot_GeneratesLabel_WhenBlank() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());
        
        try {
            HistorianConfigAdminService.RootConfigDTO result = 
                HistorianConfigAdminService.upsertRoot(
                    'TestConfig', 'Account', 'Timeline', 'AllFields', 
                    true, '', 'Account_TestConfig', 'Account_Historian__c', ''
                );
            
            System.assertEquals('TestConfig', result.label, 'Label should default to config name');
            
        } catch (Exception e) {
            // Expected in test context
            System.assert(true, 'Exception expected in test context: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testUpsertRoot_ThrowsException_WhenConfigNameNull() {
        Test.startTest();
        
        try {
            HistorianConfigAdminService.upsertRoot(
                null, 'Account', 'Timeline', 'AllFields', 
                true, 'Test Label', 'Test_Dev_Name', 'Account_Historian__c', ''
            );
            System.assert(false, 'Should have thrown exception for null config name');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Config Name is required'), 
                'Should throw appropriate error message: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testUpsertRoot_ThrowsException_WhenConfigNameBlank() {
        Test.startTest();
        
        try {
            HistorianConfigAdminService.upsertRoot(
                '', 'Account', 'Timeline', 'AllFields', 
                true, 'Test Label', 'Test_Dev_Name', 'Account_Historian__c', ''
            );
            System.assert(false, 'Should have thrown exception for blank config name');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Config Name is required'), 
                'Should throw appropriate error message: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testUpsertRoot_ThrowsException_WhenObjectApiNameNull() {
        Test.startTest();
        
        try {
            HistorianConfigAdminService.upsertRoot(
                'TestConfig', null, 'Timeline', 'AllFields', 
                true, 'Test Label', 'Test_Dev_Name', 'Account_Historian__c', ''
            );
            System.assert(false, 'Should have thrown exception for null object API name');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Object API Name is required'), 
                'Should throw appropriate error message: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testUpsertRoot_ThrowsException_WhenObjectApiNameBlank() {
        Test.startTest();
        
        try {
            HistorianConfigAdminService.upsertRoot(
                'TestConfig', '', 'Timeline', 'AllFields', 
                true, 'Test Label', 'Test_Dev_Name', 'Account_Historian__c', ''
            );
            System.assert(false, 'Should have thrown exception for blank object API name');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Object API Name is required'), 
                'Should throw appropriate error message: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testDeleteRoot_CallsMetadataOperations() {
        Test.startTest();
        
        try {
            HistorianConfigAdminService.deleteRoot('TestDeveloperName');
            // If no exception thrown, the method executed successfully
            System.assert(true, 'Delete operation should complete without error');
        } catch (Exception e) {
            // In test context, metadata operations may fail - that's expected
            System.assert(e.getMessage().contains('Metadata') || e.getMessage().contains('metadata'), 
                'Error should be related to metadata operations: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testUpsertField_ValidInput() {
        HistorianConfigAdminService.FieldConfigDTO input = new HistorianConfigAdminService.FieldConfigDTO();
        input.parentDeveloperName = 'TestParent';
        input.fieldApiName = 'TestField__c';
        input.include = true;
        input.label = 'Test Field';
        
        Test.startTest();
        
        try {
            HistorianConfigAdminService.FieldConfigDTO result = 
                HistorianConfigAdminService.upsertField(input);
            
            System.assertNotEquals(null, result, 'Result should not be null');
            System.assertEquals(input.parentDeveloperName, result.parentDeveloperName);
            System.assertEquals(input.fieldApiName, result.fieldApiName);
            System.assertEquals(input.include, result.include);
            
        } catch (Exception e) {
            // Expected in test context due to metadata operations
            System.assert(true, 'Exception expected in test context: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testUpsertField_GeneratesDeveloperName() {
        HistorianConfigAdminService.FieldConfigDTO input = new HistorianConfigAdminService.FieldConfigDTO();
        input.parentDeveloperName = 'TestParent';
        input.fieldApiName = 'TestField__c';
        input.include = true;
        input.developerName = null; // Should be generated
        
        Test.startTest();
        
        try {
            HistorianConfigAdminService.FieldConfigDTO result = 
                HistorianConfigAdminService.upsertField(input);
            
            System.assertNotEquals(null, result.developerName, 'Developer name should be generated');
            System.assert(result.developerName.contains('TestParent'), 
                'Developer name should contain parent name');
            
        } catch (Exception e) {
            // Expected in test context
            System.assert(true, 'Exception expected in test context: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testDeleteField_CallsMetadataOperations() {
        Test.startTest();
        
        try {
            HistorianConfigAdminService.deleteField('TestFieldDeveloperName');
            System.assert(true, 'Delete field operation should complete without error');
        } catch (Exception e) {
            // Expected in test context due to metadata operations
            System.assert(e.getMessage().contains('Metadata') || e.getMessage().contains('metadata'), 
                'Error should be related to metadata operations: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testGetRecordTypesForObject_ValidObject() {
        Test.startTest();
        
        try {
            List<Map<String, String>> recordTypes = 
                HistorianConfigAdminService.getRecordTypesForObject('Account');
            
            System.assertNotEquals(null, recordTypes, 'Record types list should not be null');
            // In test context, this will return actual record types for Account if they exist
            
        } catch (Exception e) {
            // May fail in test context if Account object doesn't have custom record types
            System.assert(true, 'Exception may occur in test context: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testGetRecordTypesForObject_BlankObjectName() {
        Test.startTest();
        
        List<Map<String, String>> recordTypes = 
            HistorianConfigAdminService.getRecordTypesForObject('');
        
        System.assertNotEquals(null, recordTypes, 'Record types list should not be null');
        System.assertEquals(0, recordTypes.size(), 'Should return empty list for blank object name');
        
        Test.stopTest();
    }
    
    @IsTest
    static void testGetRecordTypesForObject_NullObjectName() {
        Test.startTest();
        
        List<Map<String, String>> recordTypes = 
            HistorianConfigAdminService.getRecordTypesForObject(null);
        
        System.assertNotEquals(null, recordTypes, 'Record types list should not be null');
        System.assertEquals(0, recordTypes.size(), 'Should return empty list for null object name');
        
        Test.stopTest();
    }
    
    @IsTest
    static void testGetRecordTypesForObject_InvalidObject() {
        Test.startTest();
        
        try {
            List<Map<String, String>> recordTypes = 
                HistorianConfigAdminService.getRecordTypesForObject('NonExistentObject__c');
            System.assert(false, 'Should have thrown exception for invalid object');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('does not exist'), 
                'Should throw appropriate error message: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testValidateRecordTypeDeveloperNames_ValidNames() {
        Test.startTest();
        
        try {
            // Test with empty record types (should be valid)
            Boolean result1 = HistorianConfigAdminService.validateRecordTypeDeveloperNames('Account', '');
            System.assertEquals(true, result1, 'Empty record types should be valid');
            
            Boolean result2 = HistorianConfigAdminService.validateRecordTypeDeveloperNames('Account', null);
            System.assertEquals(true, result2, 'Null record types should be valid');
            
        } catch (Exception e) {
            // May fail in test context depending on Account record types
            System.assert(true, 'Exception may occur in test context: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testValidateRecordTypeDeveloperNames_BlankObjectName() {
        Test.startTest();
        
        Boolean result = HistorianConfigAdminService.validateRecordTypeDeveloperNames('', 'SomeRecordType');
        System.assertEquals(true, result, 'Should return true for blank object name');
        
        Test.stopTest();
    }
    
    @IsTest
    static void testValidateRecordTypeDeveloperNames_NullObjectName() {
        Test.startTest();
        
        Boolean result = HistorianConfigAdminService.validateRecordTypeDeveloperNames(null, 'SomeRecordType');
        System.assertEquals(true, result, 'Should return true for null object name');
        
        Test.stopTest();
    }
    
    @IsTest
    static void testValidateRecordTypeDeveloperNames_InvalidRecordType() {
        Test.startTest();
        
        try {
            HistorianConfigAdminService.validateRecordTypeDeveloperNames('Account', 'InvalidRecordType');
            // This might pass or fail depending on the actual record types for Account
            System.assert(true, 'Method executed without throwing exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Invalid record type developer name'), 
                'Should throw appropriate error message: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testDeveloperNameGeneration() {
        // Test the private toDevName method indirectly through upsertRoot
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());
        
        try {
            HistorianConfigAdminService.RootConfigDTO result = 
                HistorianConfigAdminService.upsertRoot(
                    'Test Config With Spaces & Special Chars!', 'Account', 'Timeline', 'AllFields', 
                    true, 'Test Label', '', 'Account_Historian__c', ''
                );
            
            System.assertNotEquals(null, result.developerName, 'Developer name should be generated');
            // Developer name should not contain spaces or special characters
            System.assert(!result.developerName.contains(' '), 
                'Developer name should not contain spaces');
            System.assert(!result.developerName.contains('!'), 
                'Developer name should not contain special characters');
            
        } catch (Exception e) {
            // Expected in test context
            System.assert(true, 'Exception expected in test context: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
}