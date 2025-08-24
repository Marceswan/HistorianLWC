@isTest
public class TriggerDetectionServiceTest {
    
    @isTest
    static void testIsTriggerDeployed() {
        Test.startTest();
        
        // Test with null/blank object name
        Boolean result1 = TriggerDetectionService.isTriggerDeployed(null);
        System.assertEquals(false, result1, 'Should return false for null object name');
        
        Boolean result2 = TriggerDetectionService.isTriggerDeployed('');
        System.assertEquals(false, result2, 'Should return false for blank object name');
        
        // Test with valid object name (will return false since no triggers exist in test context)
        Boolean result3 = TriggerDetectionService.isTriggerDeployed('Account');
        System.assertEquals(false, result3, 'Should return false in test context');
        
        Test.stopTest();
    }
    
    @isTest
    static void testGetTriggerStatusMap() {
        Test.startTest();
        
        List<String> objectNames = new List<String>{'Account', 'Contact', 'Opportunity'};
        Map<String, Boolean> statusMap = TriggerDetectionService.getTriggerStatusMap(objectNames);
        
        System.assertNotEquals(null, statusMap, 'Status map should not be null');
        System.assertEquals(3, statusMap.size(), 'Should return status for all requested objects');
        
        // All should be false in test context
        for (String objectName : objectNames) {
            System.assertEquals(false, statusMap.get(objectName), 'Should return false for ' + objectName + ' in test context');
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testGetTriggerDetails() {
        Test.startTest();
        
        // Test with valid object name
        Map<String, Object> details = TriggerDetectionService.getTriggerDetails('Account');
        
        System.assertNotEquals(null, details, 'Details should not be null');
        System.assertEquals('Account', details.get('objectApiName'), 'Should return correct object name');
        System.assertEquals('AccountHistorianTrigger', details.get('triggerName'), 'Should return correct trigger name');
        System.assertEquals(false, details.get('exists'), 'Should return false in test context');
        
        // Test with blank object name
        Map<String, Object> detailsBlank = TriggerDetectionService.getTriggerDetails('');
        System.assertEquals(false, detailsBlank.get('exists'), 'Should return false for blank object name');
        System.assertEquals('Object API Name is required', detailsBlank.get('error'), 'Should return appropriate error message');
        
        Test.stopTest();
    }
    
    @isTest
    static void testGetAllHistorianTriggers() {
        Test.startTest();
        
        // This will return empty list in test context since no configs exist
        List<Map<String, String>> triggers = TriggerDetectionService.getAllHistorianTriggers();
        
        System.assertNotEquals(null, triggers, 'Triggers list should not be null');
        // Should be empty since no historian configs exist in test context
        System.assertEquals(0, triggers.size(), 'Should return empty list when no configs exist');
        
        Test.stopTest();
    }
    
    @isTest
    static void testVerifyTriggerDeployment() {
        Test.startTest();
        
        // Test with valid object name
        Boolean result = TriggerDetectionService.verifyTriggerDeployment('Account');
        System.assertEquals(false, result, 'Should return false in test context');
        
        // Test with blank object name
        Boolean resultBlank = TriggerDetectionService.verifyTriggerDeployment('');
        System.assertEquals(false, resultBlank, 'Should return false for blank object name');
        
        Test.stopTest();
    }
    
    @isTest 
    static void testErrorHandling() {
        Test.startTest();
        
        // Test with non-existent object
        Map<String, Object> details = TriggerDetectionService.getTriggerDetails('NonExistentObject__c');
        
        // Should handle gracefully and return exists = false
        System.assertEquals(false, details.get('exists'), 'Should return false for non-existent object');
        
        Test.stopTest();
    }
}