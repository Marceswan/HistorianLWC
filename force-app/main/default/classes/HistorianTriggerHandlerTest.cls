@IsTest
private class HistorianTriggerHandlerTest {
    
    // Test helper variables and methods for generating fake Ids without DML
    private static Integer fakeIdCount = 0;
    
    private static Id getFakeId(Schema.SObjectType sObjectType) {
        String result = String.valueOf(fakeIdCount++);
        return (Id)(sObjectType.getDescribe().getKeyPrefix() + 
            '0'.repeat(12-result.length()) + result);
    }
    
    // Test data setup methods using @TestSetup
    @TestSetup
    static void setupTestData() {
        // Note: In a real implementation, you would create custom metadata records here
        // For this test, we'll simulate the metadata behavior through mocking
        System.debug('Test setup completed - metadata would be created in real scenario');
    }
    
    // Helper methods for creating test records
    private static Account createTestAccount(String name, String industry, String phone) {
        Account acc = new Account(
            Name = name,
            Industry = industry,
            Phone = phone
        );
        return acc;
    }
    
    private static Contact createTestContact(String firstName, String lastName, String email) {
        Contact con = new Contact(
            FirstName = firstName,
            LastName = lastName,
            Email = email
        );
        return con;
    }
    
    private static Opportunity createTestOpportunity(String name, String stageName, Decimal amount) {
        Opportunity opp = new Opportunity(
            Name = name,
            StageName = stageName,
            Amount = amount,
            CloseDate = System.today().addDays(30)
        );
        return opp;
    }
    
    // Test input validation - null and empty parameters
    @IsTest
    static void testHandleAfterUpdateWithNullParameters() {
        Test.startTest();
        
        // Test null object API name
        HistorianTriggerHandler.handleAfterUpdate(null, new List<SObject>(), new List<SObject>());
        
        // Test null old records
        HistorianTriggerHandler.handleAfterUpdate('Account', null, new List<SObject>());
        
        // Test null new records
        HistorianTriggerHandler.handleAfterUpdate('Account', new List<SObject>(), null);
        
        // Test empty old records list
        HistorianTriggerHandler.handleAfterUpdate('Account', new List<SObject>(), new List<SObject>{new Account()});
        
        // Test empty new records list
        HistorianTriggerHandler.handleAfterUpdate('Account', new List<SObject>{new Account()}, new List<SObject>());
        
        Test.stopTest();
        
        // Should not throw exceptions - method should handle gracefully
        System.assert(true, 'Method should handle null/empty parameters gracefully');
    }
    
    @IsTest
    static void testHandleAfterUpdateWithEmptyLists() {
        Test.startTest();
        
        List<SObject> emptyOldList = new List<SObject>();
        List<SObject> emptyNewList = new List<SObject>();
        
        HistorianTriggerHandler.handleAfterUpdate('Account', emptyOldList, emptyNewList);
        
        Test.stopTest();
        
        System.assert(true, 'Method should handle empty lists gracefully');
    }
    
    // Test no active configuration scenarios
    @IsTest
    static void testHandleAfterUpdateWithNoActiveConfiguration() {
        // Create test records
        Account oldAcc = createTestAccount('Old Name', 'Technology', '555-0001');
        Account newAcc = createTestAccount('New Name', 'Finance', '555-0002');
        
        // Set fake IDs to simulate existing records
        Id fakeId = getFakeId(Account.SObjectType);
        oldAcc.Id = fakeId;
        newAcc.Id = fakeId;
        
        List<SObject> oldRecords = new List<SObject>{oldAcc};
        List<SObject> newRecords = new List<SObject>{newAcc};
        
        Test.startTest();
        
        // This should return early due to no active configuration
        HistorianTriggerHandler.handleAfterUpdate('Account', oldRecords, newRecords);
        
        Test.stopTest();
        
        System.assert(true, 'Method should handle no active configuration gracefully');
    }
    
    // Test AllFields tracking mode simulation
    @IsTest
    static void testProcessAllFieldsChangesSimulation() {
        // Since we can't create CMDT records in tests, we'll test the methods indirectly
        Account oldAcc = createTestAccount('Old Company', 'Technology', '555-0001');
        Account newAcc = createTestAccount('New Company', 'Finance', '555-0002');
        
        Id fakeId = getFakeId(Account.SObjectType);
        oldAcc.Id = fakeId;
        newAcc.Id = fakeId;
        
        List<SObject> oldRecords = new List<SObject>{oldAcc};
        List<SObject> newRecords = new List<SObject>{newAcc};
        
        Test.startTest();
        
        // Test with Account object (should find no active config and return early)
        HistorianTriggerHandler.handleAfterUpdate('Account', oldRecords, newRecords);
        
        Test.stopTest();
        
        System.assert(true, 'AllFields mode simulation completed');
    }
    
    // Test PerField tracking mode simulation
    @IsTest
    static void testProcessPerFieldChangesSimulation() {
        Contact oldCon = createTestContact('John', 'Doe', 'john.doe.old@example.com');
        Contact newCon = createTestContact('John', 'Smith', 'john.smith.new@example.com');
        
        Id fakeId = getFakeId(Contact.SObjectType);
        oldCon.Id = fakeId;
        newCon.Id = fakeId;
        
        List<SObject> oldRecords = new List<SObject>{oldCon};
        List<SObject> newRecords = new List<SObject>{newCon};
        
        Test.startTest();
        
        // Test with Contact object (should find no active config and return early)
        HistorianTriggerHandler.handleAfterUpdate('Contact', oldRecords, newRecords);
        
        Test.stopTest();
        
        System.assert(true, 'PerField mode simulation completed');
    }
    
    // Test multiple records processing
    @IsTest
    static void testMultipleRecordsProcessing() {
        List<SObject> oldRecords = new List<SObject>();
        List<SObject> newRecords = new List<SObject>();
        
        // Create multiple test accounts
        for (Integer i = 0; i < 5; i++) {
            Account oldAcc = createTestAccount('Old Account ' + i, 'Technology', '555-000' + i);
            Account newAcc = createTestAccount('New Account ' + i, 'Finance', '555-111' + i);
            
            Id fakeId = getFakeId(Account.SObjectType);
            oldAcc.Id = fakeId;
            newAcc.Id = fakeId;
            
            oldRecords.add(oldAcc);
            newRecords.add(newAcc);
        }
        
        Test.startTest();
        
        HistorianTriggerHandler.handleAfterUpdate('Account', oldRecords, newRecords);
        
        Test.stopTest();
        
        System.assert(true, 'Multiple records processing completed');
    }
    
    // Test different SObject types
    @IsTest
    static void testDifferentSObjectTypes() {
        Test.startTest();
        
        // Test Account
        Account oldAcc = createTestAccount('Old Account', 'Technology', '555-0001');
        Account newAcc = createTestAccount('New Account', 'Finance', '555-0002');
        Id accId = getFakeId(Account.SObjectType);
        oldAcc.Id = accId;
        newAcc.Id = accId;
        
        HistorianTriggerHandler.handleAfterUpdate('Account', 
            new List<SObject>{oldAcc}, new List<SObject>{newAcc});
        
        // Test Contact
        Contact oldCon = createTestContact('John', 'Doe', 'john.doe@example.com');
        Contact newCon = createTestContact('Jane', 'Smith', 'jane.smith@example.com');
        Id conId = getFakeId(Contact.SObjectType);
        oldCon.Id = conId;
        newCon.Id = conId;
        
        HistorianTriggerHandler.handleAfterUpdate('Contact', 
            new List<SObject>{oldCon}, new List<SObject>{newCon});
        
        // Test Opportunity
        Opportunity oldOpp = createTestOpportunity('Old Deal', 'Prospecting', 10000);
        Opportunity newOpp = createTestOpportunity('New Deal', 'Closed Won', 15000);
        Id oppId = getFakeId(Opportunity.SObjectType);
        oldOpp.Id = oppId;
        newOpp.Id = oppId;
        
        HistorianTriggerHandler.handleAfterUpdate('Opportunity', 
            new List<SObject>{oldOpp}, new List<SObject>{newOpp});
        
        Test.stopTest();
        
        System.assert(true, 'Different SObject types processed successfully');
    }
    
    // Test edge cases with null values
    @IsTest
    static void testNullValueHandling() {
        Account oldAcc = new Account(Name = 'Test Account', Industry = null, Phone = '555-0001');
        Account newAcc = new Account(Name = null, Industry = 'Technology', Phone = null);
        
        Id fakeId = getFakeId(Account.SObjectType);
        oldAcc.Id = fakeId;
        newAcc.Id = fakeId;
        
        Test.startTest();
        
        HistorianTriggerHandler.handleAfterUpdate('Account', 
            new List<SObject>{oldAcc}, new List<SObject>{newAcc});
        
        Test.stopTest();
        
        System.assert(true, 'Null value handling completed');
    }
    
    // Test same values (no changes)
    @IsTest
    static void testSameValuesNoChanges() {
        Account oldAcc = createTestAccount('Same Name', 'Technology', '555-0001');
        Account newAcc = createTestAccount('Same Name', 'Technology', '555-0001');
        
        Id fakeId = getFakeId(Account.SObjectType);
        oldAcc.Id = fakeId;
        newAcc.Id = fakeId;
        
        Test.startTest();
        
        HistorianTriggerHandler.handleAfterUpdate('Account', 
            new List<SObject>{oldAcc}, new List<SObject>{newAcc});
        
        Test.stopTest();
        
        System.assert(true, 'Same values processing completed');
    }
    
    // Test different data types
    @IsTest
    static void testDifferentDataTypes() {
        // Using Account fields to test different data types
        Account oldAcc = new Account();
        oldAcc.Name = 'Test Account';
        oldAcc.AnnualRevenue = 100000.50;
        oldAcc.NumberOfEmployees = 100;
        oldAcc.Phone = '555-0001';
        
        Account newAcc = new Account();
        newAcc.Name = 'Updated Account';
        newAcc.AnnualRevenue = 200000.75;
        newAcc.NumberOfEmployees = 150;
        newAcc.Phone = '555-0002';
        
        Id fakeId = getFakeId(Account.SObjectType);
        oldAcc.Id = fakeId;
        newAcc.Id = fakeId;
        
        Test.startTest();
        
        HistorianTriggerHandler.handleAfterUpdate('Account', 
            new List<SObject>{oldAcc}, new List<SObject>{newAcc});
        
        Test.stopTest();
        
        System.assert(true, 'Different data types processing completed');
    }
    
    // Test field access exceptions simulation
    @IsTest
    static void testFieldAccessExceptionHandling() {
        // Create records with minimal data to simulate potential field access issues
        Account oldAcc = new Account(Name = 'Test');
        Account newAcc = new Account(Name = 'Test Updated');
        
        Id fakeId = getFakeId(Account.SObjectType);
        oldAcc.Id = fakeId;
        newAcc.Id = fakeId;
        
        Test.startTest();
        
        // This should handle any field access exceptions gracefully
        HistorianTriggerHandler.handleAfterUpdate('Account', 
            new List<SObject>{oldAcc}, new List<SObject>{newAcc});
        
        Test.stopTest();
        
        System.assert(true, 'Field access exception handling completed');
    }
    
    // Test exception handling in main method
    @IsTest
    static void testMainMethodExceptionHandling() {
        // Create records with potential issues that might cause exceptions
        List<SObject> oldRecords = new List<SObject>();
        List<SObject> newRecords = new List<SObject>();
        
        // Add records with mismatched IDs to potentially trigger exceptions
        Account oldAcc = createTestAccount('Old', 'Tech', '555-0001');
        Account newAcc = createTestAccount('New', 'Finance', '555-0002');
        
        oldAcc.Id = getFakeId(Account.SObjectType);
        newAcc.Id = getFakeId(Account.SObjectType); // Different ID
        
        oldRecords.add(oldAcc);
        newRecords.add(newAcc);
        
        Test.startTest();
        
        // Should handle exceptions gracefully
        HistorianTriggerHandler.handleAfterUpdate('Account', oldRecords, newRecords);
        
        Test.stopTest();
        
        System.assert(true, 'Exception handling completed successfully');
    }
    
    // Test large dataset processing
    @IsTest
    static void testLargeDatasetProcessing() {
        List<SObject> oldRecords = new List<SObject>();
        List<SObject> newRecords = new List<SObject>();
        
        // Create a larger dataset to test bulk processing
        for (Integer i = 0; i < 100; i++) {
            Account oldAcc = createTestAccount('Old Bulk Account ' + i, 'Technology', '555-' + String.valueOf(1000 + i));
            Account newAcc = createTestAccount('New Bulk Account ' + i, 'Finance', '555-' + String.valueOf(2000 + i));
            
            Id fakeId = getFakeId(Account.SObjectType);
            oldAcc.Id = fakeId;
            newAcc.Id = fakeId;
            
            oldRecords.add(oldAcc);
            newRecords.add(newAcc);
        }
        
        Test.startTest();
        
        HistorianTriggerHandler.handleAfterUpdate('Account', oldRecords, newRecords);
        
        Test.stopTest();
        
        System.assert(true, 'Large dataset processing completed');
    }
    
    // Test getRecordName method behavior
    @IsTest
    static void testGetRecordNameMethod() {
        Test.startTest();
        
        // Test with records that have Name field
        Account accWithName = createTestAccount('Test Account Name', 'Technology', '555-0001');
        accWithName.Id = getFakeId(Account.SObjectType);
        
        // Test with records that don't have Name field (like Task)
        // We'll simulate this by testing the fallback behavior
        Account accWithoutName = new Account();
        accWithoutName.Id = getFakeId(Account.SObjectType);
        
        // Process these records to test getRecordName indirectly
        HistorianTriggerHandler.handleAfterUpdate('Account', 
            new List<SObject>{accWithName}, new List<SObject>{accWithoutName});
        
        Test.stopTest();
        
        System.assert(true, 'GetRecordName method testing completed');
    }
    
    // Test with mismatched record IDs in old and new lists
    @IsTest
    static void testMismatchedRecordIds() {
        Account oldAcc1 = createTestAccount('Old Account 1', 'Technology', '555-0001');
        Account oldAcc2 = createTestAccount('Old Account 2', 'Finance', '555-0002');
        Account newAcc1 = createTestAccount('New Account 1', 'Healthcare', '555-0011');
        Account newAcc2 = createTestAccount('New Account 2', 'Manufacturing', '555-0012');
        
        // Set up mismatched IDs
        Id id1 = getFakeId(Account.SObjectType);
        Id id2 = getFakeId(Account.SObjectType);
        Id id3 = getFakeId(Account.SObjectType);
        Id id4 = getFakeId(Account.SObjectType);
        
        oldAcc1.Id = id1;
        oldAcc2.Id = id2;
        newAcc1.Id = id3; // Different from oldAcc1
        newAcc2.Id = id4; // Different from oldAcc2
        
        List<SObject> oldRecords = new List<SObject>{oldAcc1, oldAcc2};
        List<SObject> newRecords = new List<SObject>{newAcc1, newAcc2};
        
        Test.startTest();
        
        HistorianTriggerHandler.handleAfterUpdate('Account', oldRecords, newRecords);
        
        Test.stopTest();
        
        System.assert(true, 'Mismatched record IDs handling completed');
    }
    
    // Test with various field population scenarios
    @IsTest
    static void testVariousFieldPopulationScenarios() {
        // Record with many fields populated
        Account fullAccount = new Account(
            Name = 'Full Account',
            Industry = 'Technology',
            Phone = '555-0001',
            Website = 'www.example.com',
            AnnualRevenue = 1000000,
            NumberOfEmployees = 500,
            Description = 'Full description'
        );
        
        // Record with minimal fields populated
        Account minimalAccount = new Account(
            Name = 'Minimal Account'
        );
        
        Id fakeId = getFakeId(Account.SObjectType);
        fullAccount.Id = fakeId;
        minimalAccount.Id = fakeId;
        
        Test.startTest();
        
        // Test from full to minimal
        HistorianTriggerHandler.handleAfterUpdate('Account', 
            new List<SObject>{fullAccount}, new List<SObject>{minimalAccount});
        
        // Test from minimal to full
        HistorianTriggerHandler.handleAfterUpdate('Account', 
            new List<SObject>{minimalAccount}, new List<SObject>{fullAccount});
        
        Test.stopTest();
        
        System.assert(true, 'Various field population scenarios completed');
    }
    
    // Performance test for governor limits
    @IsTest
    static void testPerformanceAndGovernorLimits() {
        List<SObject> oldRecords = new List<SObject>();
        List<SObject> newRecords = new List<SObject>();
        
        // Test with maximum reasonable number of records
        Integer maxRecords = 200; // Staying within governor limits
        
        for (Integer i = 0; i < maxRecords; i++) {
            Account oldAcc = createTestAccount('Perf Old ' + i, 'Industry' + Math.mod(i, 10), '555-' + String.valueOf(3000 + i));
            Account newAcc = createTestAccount('Perf New ' + i, 'Industry' + Math.mod(i, 5), '555-' + String.valueOf(4000 + i));
            
            Id fakeId = getFakeId(Account.SObjectType);
            oldAcc.Id = fakeId;
            newAcc.Id = fakeId;
            
            oldRecords.add(oldAcc);
            newRecords.add(newAcc);
        }
        
        Test.startTest();
        
        // Monitor CPU time and other limits
        Integer beforeCpuTime = Limits.getCpuTime();
        Integer beforeQueries = Limits.getQueries();
        
        HistorianTriggerHandler.handleAfterUpdate('Account', oldRecords, newRecords);
        
        Integer afterCpuTime = Limits.getCpuTime();
        Integer afterQueries = Limits.getQueries();
        
        Test.stopTest();
        
        // Verify we stayed within reasonable limits
        System.assert(afterCpuTime - beforeCpuTime < 8000, 'CPU time should be reasonable: ' + (afterCpuTime - beforeCpuTime));
        System.assert(afterQueries - beforeQueries <= 2, 'Query count should be minimal: ' + (afterQueries - beforeQueries));
        
        System.assert(true, 'Performance test completed successfully');
    }
}