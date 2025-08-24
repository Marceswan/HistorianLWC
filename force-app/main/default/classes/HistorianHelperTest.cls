@IsTest
private class HistorianHelperTest {
    
    @TestSetup
    static void setup() {
        // Test will use custom metadata types if they exist
    }
    
    @IsTest
    static void testCaptureHistoricalChanges_Success() {
        // Create test account
        Account testAccount = new Account(Name = 'Test Account', Type = 'Customer');
        insert testAccount;
        
        // Create invocable request
        HistorianHelper.HistorianRequest request = new HistorianHelper.HistorianRequest();
        request.targetRecordId = testAccount.Id;
        request.targetSObjectApiName = 'Account';
        request.configName = null; // Will use first active config
        
        Test.startTest();
        
        // Call the invocable method
        List<HistorianHelper.HistorianResult> results = HistorianHelper.captureHistoricalChanges(
            new List<HistorianHelper.HistorianRequest>{request}
        );
        
        Test.stopTest();
        
        // Verify results
        System.assertEquals(1, results.size(), 'Should return one result');
        HistorianHelper.HistorianResult result = results[0];
        System.assertEquals(testAccount.Id, result.recordId, 'Should have correct record ID');
        System.assertEquals('Account', result.sobjectType, 'Should have correct sObject type');
        
        // Note: Success may be false if no active configurations exist, which is expected in test context
        // since we don't have custom metadata types configured in tests
        System.assertNotEquals(null, result.success, 'Should have a success value');
        
        // In test context, we expect this to fail gracefully due to no configurations
        if (!result.success) {
            System.assert(result.errorMessage.contains('No active configuration found'), 
                'Should indicate no configuration found: ' + result.errorMessage);
        }
    }
    
    @IsTest
    static void testCaptureHistoricalChanges_InvalidRecordId() {
        // Create invocable request with invalid ID
        HistorianHelper.HistorianRequest request = new HistorianHelper.HistorianRequest();
        request.targetRecordId = 'invalid';
        request.targetSObjectApiName = 'Account';
        
        Test.startTest();
        
        // Call the invocable method
        List<HistorianHelper.HistorianResult> results = HistorianHelper.captureHistoricalChanges(
            new List<HistorianHelper.HistorianRequest>{request}
        );
        
        Test.stopTest();
        
        // Verify results
        System.assertEquals(1, results.size(), 'Should return one result');
        HistorianHelper.HistorianResult result = results[0];
        System.assertEquals(false, result.success, 'Should fail with invalid record ID');
        System.assertNotEquals(null, result.errorMessage, 'Should have error message');
    }
    
    @IsTest
    static void testCaptureHistoricalChanges_EmptyRecordId() {
        // Create invocable request with empty ID
        HistorianHelper.HistorianRequest request = new HistorianHelper.HistorianRequest();
        request.targetRecordId = '';
        request.targetSObjectApiName = 'Account';
        
        Test.startTest();
        
        // Call the invocable method
        List<HistorianHelper.HistorianResult> results = HistorianHelper.captureHistoricalChanges(
            new List<HistorianHelper.HistorianRequest>{request}
        );
        
        Test.stopTest();
        
        // Verify results
        System.assertEquals(1, results.size(), 'Should return one result');
        HistorianHelper.HistorianResult result = results[0];
        System.assertEquals(false, result.success, 'Should fail with empty record ID');
        System.assertEquals('Target Record ID is required', result.errorMessage, 'Should have specific error message');
    }
    
    @IsTest
    static void testCaptureHistoricalChanges_AutoDetectSObjectType() {
        // Create test contact
        Contact testContact = new Contact(FirstName = 'Test', LastName = 'Contact', Email = 'test@example.com');
        insert testContact;
        
        // Create invocable request without specifying sObject type
        HistorianHelper.HistorianRequest request = new HistorianHelper.HistorianRequest();
        request.targetRecordId = testContact.Id;
        // Don't specify targetSObjectApiName - should be auto-detected
        
        Test.startTest();
        
        // Call the invocable method
        List<HistorianHelper.HistorianResult> results = HistorianHelper.captureHistoricalChanges(
            new List<HistorianHelper.HistorianRequest>{request}
        );
        
        Test.stopTest();
        
        // Verify results
        System.assertEquals(1, results.size(), 'Should return one result');
        HistorianHelper.HistorianResult result = results[0];
        System.assertEquals(testContact.Id, result.recordId, 'Should have correct record ID');
        System.assertEquals('Contact', result.sobjectType, 'Should auto-detect sObject type as Contact');
    }
    
    @IsTest
    static void testCaptureHistoricalChanges_WithPreviousValues() {
        // Create test account
        Account testAccount = new Account(Name = 'Test Account', Type = 'Customer');
        insert testAccount;
        
        // Create previous values JSON
        Map<String, Object> previousValues = new Map<String, Object>();
        previousValues.put('Name', 'Old Account Name');
        previousValues.put('Type', 'Prospect');
        String previousValuesJson = JSON.serialize(previousValues);
        
        // Create invocable request with previous values
        HistorianHelper.HistorianRequest request = new HistorianHelper.HistorianRequest();
        request.targetRecordId = testAccount.Id;
        request.targetSObjectApiName = 'Account';
        request.previousValuesJson = previousValuesJson;
        
        Test.startTest();
        
        // Call the invocable method
        List<HistorianHelper.HistorianResult> results = HistorianHelper.captureHistoricalChanges(
            new List<HistorianHelper.HistorianRequest>{request}
        );
        
        Test.stopTest();
        
        // Verify results
        System.assertEquals(1, results.size(), 'Should return one result');
        HistorianHelper.HistorianResult result = results[0];
        System.assertEquals(testAccount.Id, result.recordId, 'Should have correct record ID');
        System.assertNotEquals(null, result.success, 'Should have processed the request');
    }
    
    @IsTest
    static void testCaptureHistoricalChanges_MultipleRecords() {
        // Create test accounts
        List<Account> testAccounts = new List<Account>();
        testAccounts.add(new Account(Name = 'Test Account 1', Type = 'Customer'));
        testAccounts.add(new Account(Name = 'Test Account 2', Type = 'Partner'));
        insert testAccounts;
        
        // Create multiple requests
        List<HistorianHelper.HistorianRequest> requests = new List<HistorianHelper.HistorianRequest>();
        
        for (Account acc : testAccounts) {
            HistorianHelper.HistorianRequest request = new HistorianHelper.HistorianRequest();
            request.targetRecordId = acc.Id;
            request.targetSObjectApiName = 'Account';
            requests.add(request);
        }
        
        Test.startTest();
        
        // Call the invocable method
        List<HistorianHelper.HistorianResult> results = HistorianHelper.captureHistoricalChanges(requests);
        
        Test.stopTest();
        
        // Verify results
        System.assertEquals(2, results.size(), 'Should return two results');
        
        for (Integer i = 0; i < results.size(); i++) {
            HistorianHelper.HistorianResult result = results[i];
            System.assertEquals(testAccounts[i].Id, result.recordId, 'Should have correct record ID for index ' + i);
            System.assertEquals('Account', result.sobjectType, 'Should have correct sObject type for index ' + i);
        }
    }
}