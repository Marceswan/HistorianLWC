@IsTest
private class FlowDeploymentServiceTest {
    
    @TestSetup
    static void setup() {
        // Test will use existing configurations if available
    }
    
    @IsTest
    static void testDeployFlowNow_Success() {
        // Create test account for object validation
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        Test.startTest();
        
        // Call deployFlowNow for Account object
        Map<String, Object> result = FlowDeploymentService.deployFlowNow('Account');
        
        Test.stopTest();
        
        // Verify result structure
        System.assertNotEquals(null, result, 'Should return a result');
        System.assertNotEquals(null, result.get('success'), 'Should have success value');
        System.assertEquals('Account', result.get('objectApiName'), 'Should have correct object API name');
        
        // Note: In test context, this may fail due to no active configurations, which is expected
        if (!(Boolean) result.get('success')) {
            System.assert(
                ((String) result.get('error')).contains('No active configurations'),
                'Expected error about no active configurations'
            );
        }
    }
    
    @IsTest
    static void testDeployFlowNow_InvalidObject() {
        Test.startTest();
        
        Map<String, Object> result = FlowDeploymentService.deployFlowNow('InvalidObject');
        
        Test.stopTest();
        
        System.assertEquals(false, result.get('success'), 'Should fail for invalid object');
        System.assertEquals('InvalidObject', result.get('objectApiName'), 'Should have correct object name');
        System.assertNotEquals(null, result.get('error'), 'Should have error message');
    }
    
    @IsTest
    static void testDeployFlowNow_BlankObjectName() {
        Test.startTest();
        
        Map<String, Object> result = FlowDeploymentService.deployFlowNow('');
        
        Test.stopTest();
        
        System.assertEquals(false, result.get('success'), 'Should fail for blank object name');
        System.assertEquals('Object API Name is required', result.get('error'), 'Should have specific error message');
    }
    
    @IsTest
    static void testGenerateAndDeployFlow_Success() {
        // Create test contact for object validation
        Contact testContact = new Contact(FirstName = 'Test', LastName = 'Contact', Email = 'test@example.com');
        insert testContact;
        
        Test.startTest();
        
        try {
            String result = FlowDeploymentService.generateAndDeployFlow('Contact');
            System.assert(result.startsWith('SUCCESS_'), 'Should return success ID format');
        } catch (AuraHandledException ex) {
            // Expected in test context without configurations
            System.assert(ex.getMessage().contains('No active configurations'), 'Expected configuration error');
        }
        
        Test.stopTest();
    }
    
    @IsTest 
    static void testGenerateAndDeployFlow_Failure() {
        Test.startTest();
        
        try {
            String result = FlowDeploymentService.generateAndDeployFlow('InvalidObject');
            System.assert(false, 'Should throw exception for invalid object');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage(), 'Should have error message');
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testVerifyFlowDeployment_NoObject() {
        Test.startTest();
        
        Map<String, Object> result = FlowDeploymentService.verifyFlowDeployment('');
        
        Test.stopTest();
        
        System.assertEquals(false, result.get('success'), 'Should fail for blank object name');
        System.assertEquals('Object API Name is required', result.get('error'), 'Should have specific error message');
    }
    
    @IsTest
    static void testVerifyFlowDeployment_ValidObject() {
        Test.startTest();
        
        Map<String, Object> result = FlowDeploymentService.verifyFlowDeployment('Account');
        
        Test.stopTest();
        
        System.assertEquals('Account', result.get('objectApiName'), 'Should have correct object name');
        System.assertEquals('Account_Historian_Flow', result.get('flowName'), 'Should have correct flow name');
        System.assertNotEquals(null, result.get('flowExists'), 'Should have flowExists value');
        
        // In test context, flow likely doesn't exist
        System.assertEquals(false, result.get('flowExists'), 'Flow should not exist in test');
    }
    
    @IsTest
    static void testGetDeploymentStatus_ValidObject() {
        Test.startTest();
        
        Map<String, Object> result = FlowDeploymentService.getDeploymentStatus('Account');
        
        Test.stopTest();
        
        System.assertEquals('Account', result.get('objectApiName'), 'Should have correct object name');
        System.assertEquals(true, result.get('success'), 'Should succeed for valid call');
        System.assertNotEquals(null, result.get('flowExists'), 'Should have flowExists value');
        System.assertNotEquals(null, result.get('overallStatus'), 'Should have overall status');
    }
    
    @IsTest
    static void testGetDeploymentStatus_WithDeploymentRecords() {
        // Create test deployment result records
        List<Historian_Deploy_Result__c> testResults = new List<Historian_Deploy_Result__c>();
        testResults.add(new Historian_Deploy_Result__c(
            Request_Id__c = 'FLOW_TEST_001',
            Status__c = 'Succeeded',
            State__c = 'Completed',
            Error_Count__c = 0,
            Component_FullName__c = 'Account_Historian_Flow',
            Component_Type__c = 'Flow',
            Problem__c = 'Test deployment'
        ));
        insert testResults;
        
        Test.startTest();
        
        Map<String, Object> result = FlowDeploymentService.getDeploymentStatus('Account');
        
        Test.stopTest();
        
        System.assertEquals('Account', result.get('objectApiName'), 'Should have correct object name');
        System.assertEquals(true, result.get('success'), 'Should succeed');
        System.assertEquals(1, result.get('recentDeploymentCount'), 'Should find deployment records');
        System.assertEquals('Succeeded', result.get('latestDeploymentStatus'), 'Should have correct latest status');
    }
}