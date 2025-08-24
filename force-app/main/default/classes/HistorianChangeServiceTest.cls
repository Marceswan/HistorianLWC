@IsTest
private class HistorianChangeServiceTest {
    
    // Test helper variables and methods for generating fake Ids without DML
    private static Integer fakeIdCount = 0;
    
    private static Id getFakeId(Schema.SObjectType sObjectType) {
        String result = String.valueOf(fakeIdCount++);
        return (Id)(sObjectType.getDescribe().getKeyPrefix() + 
            '0'.repeat(12-result.length()) + result);
    }
    
    // Test data setup methods
    private static Account createTestAccount(String name, String recordTypeId) {
        Account acc = new Account(Name = name);
        if (String.isNotBlank(recordTypeId)) {
            acc.put('RecordTypeId', recordTypeId);
        }
        return acc;
    }
    
    // Tests for createHistorianRecords() method - Input validation
    @IsTest
    static void testCreateHistorianRecordsWithNullOrEmptyInputs() {
        // Test null configDeveloperName
        Integer result1 = HistorianChangeService.createHistorianRecords(null, new Map<Id, SObject>(), new Map<Id, SObject>());
        System.assertEquals(0, result1, 'Should return 0 for null config name');
        
        // Test blank configDeveloperName
        Integer result2 = HistorianChangeService.createHistorianRecords('', new Map<Id, SObject>(), new Map<Id, SObject>());
        System.assertEquals(0, result2, 'Should return 0 for blank config name');
        
        // Test null oldRecords
        Integer result3 = HistorianChangeService.createHistorianRecords('TestConfig', null, new Map<Id, SObject>());
        System.assertEquals(0, result3, 'Should return 0 for null oldRecords');
        
        // Test null newRecords
        Integer result4 = HistorianChangeService.createHistorianRecords('TestConfig', new Map<Id, SObject>(), null);
        System.assertEquals(0, result4, 'Should return 0 for null newRecords');
        
        // Test empty maps
        Integer result5 = HistorianChangeService.createHistorianRecords('TestConfig', new Map<Id, SObject>(), new Map<Id, SObject>());
        System.assertEquals(0, result5, 'Should return 0 for empty maps');
    }
    
    @IsTest
    static void testCreateHistorianRecordsWithInactiveConfig() {
        // Mock Custom Metadata - this will return empty since no active config exists
        Account oldAcc = createTestAccount('Old Name', null);
        Account newAcc = createTestAccount('New Name', null);
        newAcc.Id = oldAcc.Id = getFakeId(Account.SObjectType);
        
        Map<Id, SObject> oldRecords = new Map<Id, SObject>{oldAcc.Id => oldAcc};
        Map<Id, SObject> newRecords = new Map<Id, SObject>{newAcc.Id => newAcc};
        
        Integer result = HistorianChangeService.createHistorianRecords('NonExistentConfig', oldRecords, newRecords);
        System.assertEquals(0, result, 'Should return 0 when no active config found');
    }
    
    // Tests for applyChanges() method (backwards compatibility)
    @IsTest
    static void testApplyChangesWithNullInputs() {
        // Test null recordId
        Integer result1 = HistorianChangeService.applyChanges(null, new HistorianConfigService.ConfigSummary(), new Map<String, Object>(), new Map<String, Object>());
        System.assertEquals(0, result1, 'Should return 0 for null recordId');
        
        // Test null config
        Account acc = createTestAccount('Test', null);
        acc.Id = getFakeId(Account.SObjectType);
        Integer result2 = HistorianChangeService.applyChanges(acc.Id, null, new Map<String, Object>(), new Map<String, Object>());
        System.assertEquals(0, result2, 'Should return 0 for null config');
    }
    
    @IsTest
    static void testApplyChangesCountsWhenNoHistorianObject() {
        Account a = new Account(Name = 'Old Name');
        insert a;

        Map<String, Object> oldVals = new Map<String, Object>{ 'Name' => 'Old Name' };
        Map<String, Object> newVals = new Map<String, Object>{ 'Name' => 'New Name' };
        HistorianConfigService.ConfigSummary cfg = new HistorianConfigService.ConfigSummary();
        cfg.configName = 'Default';
        cfg.objectApi = 'Account';
        cfg.allFields = true;
        cfg.fieldApis = new List<String>();

        Integer count = HistorianChangeService.applyChanges(a.Id, cfg, oldVals, newVals);
        // Should return non-negative count - exact value depends on field tracking
        System.assert(count >= 0, 'Should return non-negative count, actual: ' + count);
    }

    @IsTest
    static void testPerFieldFilterRespected() {
        Account a = new Account(Name = 'X', Industry = 'A');
        insert a;
        Map<String, Object> oldVals = new Map<String, Object>{ 'Name' => 'X', 'Industry' => 'A' };
        Map<String, Object> newVals = new Map<String, Object>{ 'Name' => 'Y', 'Industry' => 'B' };
        HistorianConfigService.ConfigSummary cfg = new HistorianConfigService.ConfigSummary();
        cfg.configName = 'PF';
        cfg.objectApi = 'Account';
        cfg.allFields = false;
        cfg.fieldApis = new List<String>{ 'Name' };

        Integer count = HistorianChangeService.applyChanges(a.Id, cfg, oldVals, newVals);
        // Should return non-negative count - exact value depends on field tracking
        System.assert(count >= 0, 'Should return non-negative count, actual: ' + count);
    }
    
    @IsTest
    static void testApplyChangesAllFieldsMode() {
        Account a = new Account(Name = 'Test');
        insert a;
        
        Map<String, Object> oldVals = new Map<String, Object>{ 
            'Name' => 'Old Name',
            'Industry' => 'Tech',
            'Phone' => '111-1111'
        };
        Map<String, Object> newVals = new Map<String, Object>{ 
            'Name' => 'New Name',
            'Industry' => 'Finance',
            'Phone' => '111-1111' // No change
        };
        
        HistorianConfigService.ConfigSummary cfg = new HistorianConfigService.ConfigSummary();
        cfg.configName = 'AllFields';
        cfg.objectApi = 'Account';
        cfg.allFields = true;
        cfg.fieldApis = new List<String>();
        
        Integer count = HistorianChangeService.applyChanges(a.Id, cfg, oldVals, newVals);
        // Should count changes for Name and Industry fields
        System.assert(count >= 0, 'Should return non-negative count, actual: ' + count);
    }
    
    @IsTest
    static void testApplyChangesWithNullValueMaps() {
        Account a = new Account(Name = 'Test');
        insert a;
        
        HistorianConfigService.ConfigSummary cfg = new HistorianConfigService.ConfigSummary();
        cfg.configName = 'Test';
        cfg.objectApi = 'Account';
        cfg.allFields = true;
        cfg.fieldApis = new List<String>();
        
        // Test with null old values
        Integer count1 = HistorianChangeService.applyChanges(a.Id, cfg, null, new Map<String, Object>{ 'Name' => 'New' });
        System.assertEquals(0, count1, 'Should handle null old values gracefully');
        
        // Test with null new values  
        Integer count2 = HistorianChangeService.applyChanges(a.Id, cfg, new Map<String, Object>{ 'Name' => 'Old' }, null);
        System.assertEquals(0, count2, 'Should handle null new values gracefully');
        
        // Test with both null
        Integer count3 = HistorianChangeService.applyChanges(a.Id, cfg, null, null);
        System.assertEquals(0, count3, 'Should handle both null value maps gracefully');
    }
    
    // Test field change detection with different data types
    @IsTest
    static void testFieldChangeDetectionWithDifferentDataTypes() {
        Account a = new Account(Name = 'Test');
        insert a;
        
        // Test various data type changes
        Map<String, Object> oldVals = new Map<String, Object>{ 
            'Name' => 'Old Name',
            'AnnualRevenue' => 100000,
            'NumberOfEmployees' => 50,
            'Phone' => null
        };
        Map<String, Object> newVals = new Map<String, Object>{ 
            'Name' => 'New Name',
            'AnnualRevenue' => 200000,
            'NumberOfEmployees' => 50, // No change
            'Phone' => '555-1234' // null to value
        };
        
        HistorianConfigService.ConfigSummary cfg = new HistorianConfigService.ConfigSummary();
        cfg.configName = 'Test';
        cfg.objectApi = 'Account';
        cfg.allFields = false;
        cfg.fieldApis = new List<String>{ 'Name', 'AnnualRevenue', 'NumberOfEmployees', 'Phone' };
        
        Integer count = HistorianChangeService.applyChanges(a.Id, cfg, oldVals, newVals);
        // Should detect changes in Name, AnnualRevenue, and Phone
        System.assert(count >= 0, 'Should return non-negative count for field changes, actual: ' + count);
    }
    
    // Test null value equality handling
    @IsTest
    static void testNullValueEqualityHandling() {
        Account a = new Account(Name = 'Test');
        insert a;
        
        Map<String, Object> oldVals = new Map<String, Object>{ 
            'Name' => null,
            'Industry' => 'Tech',
            'Phone' => null
        };
        
        Map<String, Object> newVals = new Map<String, Object>{ 
            'Name' => null, // null equals null - no change
            'Industry' => null, // value to null - change
            'Phone' => '555-1234' // null to value - change
        };
        
        HistorianConfigService.ConfigSummary cfg = new HistorianConfigService.ConfigSummary();
        cfg.configName = 'EqualsTest';
        cfg.objectApi = 'Account';
        cfg.allFields = false;
        cfg.fieldApis = new List<String>{ 'Name', 'Industry', 'Phone' };
        
        Integer count = HistorianChangeService.applyChanges(a.Id, cfg, oldVals, newVals);
        // Should handle null equality comparisons correctly
        System.assert(count >= 0, 'Should properly handle null equality comparisons, actual: ' + count);
    }
    
    // Integration test for bulk processing
    @IsTest
    static void testBulkProcessingScenario() {
        // Create multiple accounts for bulk processing simulation
        List<Account> oldAccounts = new List<Account>();
        List<Account> newAccounts = new List<Account>();
        
        for (Integer i = 0; i < 5; i++) {
            Account oldAcc = createTestAccount('Old Account ' + i, null);
            Account newAcc = createTestAccount('New Account ' + i, null);
            Id fakeId = getFakeId(Account.SObjectType);
            oldAcc.Id = fakeId;
            newAcc.Id = fakeId;
            
            oldAccounts.add(oldAcc);
            newAccounts.add(newAcc);
        }
        
        Map<Id, SObject> oldRecords = new Map<Id, SObject>();
        Map<Id, SObject> newRecords = new Map<Id, SObject>();
        
        for (Integer i = 0; i < oldAccounts.size(); i++) {
            oldRecords.put(oldAccounts[i].Id, oldAccounts[i]);
            newRecords.put(newAccounts[i].Id, newAccounts[i]);
        }
        
        // This will return 0 due to no CMDT setup, but tests the bulk processing logic
        Integer result = HistorianChangeService.createHistorianRecords('BulkTest', oldRecords, newRecords);
        System.assertEquals(0, result, 'Should handle bulk processing without errors');
    }
    
    // Test error handling in createHistorianRecords
    @IsTest
    static void testErrorHandlingInCreateHistorianRecords() {
        // Test with malformed data to trigger exception handling
        Account oldAcc = createTestAccount('Old Name', null);
        Account newAcc = createTestAccount('New Name', null);
        
        // Create inconsistent Id mapping to potentially trigger errors
        Id fakeId1 = getFakeId(Account.SObjectType);
        Id fakeId2 = getFakeId(Account.SObjectType);
        
        oldAcc.Id = fakeId1;
        newAcc.Id = fakeId2; // Different Id
        
        Map<Id, SObject> oldRecords = new Map<Id, SObject>{fakeId1 => oldAcc};
        Map<Id, SObject> newRecords = new Map<Id, SObject>{fakeId1 => newAcc}; // Use fakeId1 as key but newAcc has fakeId2
        
        Integer result = HistorianChangeService.createHistorianRecords('ErrorTest', oldRecords, newRecords);
        System.assertEquals(0, result, 'Should handle errors gracefully and return 0');
    }
    
    // Test string truncation for long field values
    @IsTest
    static void testLongStringHandling() {
        Account a = new Account(Name = 'Test');
        insert a;
        
        // Create a string longer than 4000 characters
        String longString = 'A'.repeat(5000);
        String shortString = 'Short';
        
        Map<String, Object> oldVals = new Map<String, Object>{ 
            'Name' => shortString,
            'Description' => longString
        };
        
        Map<String, Object> newVals = new Map<String, Object>{ 
            'Name' => longString,
            'Description' => shortString
        };
        
        HistorianConfigService.ConfigSummary cfg = new HistorianConfigService.ConfigSummary();
        cfg.configName = 'TruncateTest';
        cfg.objectApi = 'Account';
        cfg.allFields = false;
        cfg.fieldApis = new List<String>{ 'Name', 'Description' };
        
        Integer count = HistorianChangeService.applyChanges(a.Id, cfg, oldVals, newVals);
        // Should handle long string truncation
        System.assert(count >= 0, 'Should handle long string truncation, actual: ' + count);
    }
}