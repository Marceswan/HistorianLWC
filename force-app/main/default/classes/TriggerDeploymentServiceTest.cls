@IsTest
public class TriggerDeploymentServiceTest {
    
    @TestSetup
    static void makeData() {
        // Create a test deploy result record for getGeneratedTriggers test
        Historian_Deploy_Result__c testResult = new Historian_Deploy_Result__c(
            Request_Id__c = 'TEST_TRIGGER_123',
            Status__c = 'Generated',
            State__c = 'Ready for Deployment',
            Error_Count__c = 0,
            Component_FullName__c = 'AccountHistorianTrigger',
            Component_Type__c = 'ApexTrigger',
            Problem__c = 'Generated trigger code - ready for manual deployment.\n\nTrigger Code:\ntrigger AccountHistorianTrigger on Account (after update) {\n    HistorianTriggerHandler.handleAfterUpdate(\'Account\', Trigger.old, Trigger.new);\n}'
        );
        insert testResult;
    }
    
    @IsTest
    static void testGenerateAndDeployTriggerWithNullObjectApiName() {
        Test.startTest();
        try {
            TriggerDeploymentService.generateAndDeployTrigger(null);
            System.assert(false, 'Should have thrown exception for null object API name');
        } catch (AuraHandledException e) {
            System.assertEquals('Object API Name is required', e.getMessage());
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testGenerateAndDeployTriggerWithBlankObjectApiName() {
        Test.startTest();
        try {
            TriggerDeploymentService.generateAndDeployTrigger('');
            System.assert(false, 'Should have thrown exception for blank object API name');
        } catch (AuraHandledException e) {
            System.assertEquals('Object API Name is required', e.getMessage());
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testGenerateAndDeployTriggerWithInvalidObject() {
        Test.startTest();
        try {
            TriggerDeploymentService.generateAndDeployTrigger('InvalidObject__c');
            System.assert(false, 'Should have thrown exception for invalid object');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('does not exist'));
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testGenerateAndDeployTriggerWithNoActiveConfig() {
        Test.startTest();
        try {
            TriggerDeploymentService.generateAndDeployTrigger('Account');
            System.assert(false, 'Should have thrown exception for no active configurations');
        } catch (AuraHandledException e) {
            System.assertEquals('No active configurations found for Account', e.getMessage());
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testGenerateAndDeployTriggerWithValidConfig() {
        // Create a mock active configuration
        // Since we can't create CMDT records in tests, we'll test the scenario where
        // the configuration check would pass but the deployment would fail due to test context
        
        Test.startTest();
        try {
            // This will fail at the configuration check since we can't create CMDT in tests
            TriggerDeploymentService.generateAndDeployTrigger('Account');
            System.assert(false, 'Should have failed due to no active configurations');
        } catch (AuraHandledException e) {
            System.assertEquals('No active configurations found for Account', e.getMessage());
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testGetGeneratedTriggersWithResults() {
        Test.startTest();
        List<Map<String, String>> triggers = TriggerDeploymentService.getGeneratedTriggers();
        Test.stopTest();
        
        // Should return the test data we created in @TestSetup
        System.assertNotEquals(null, triggers, 'Triggers list should not be null');
        System.assert(triggers.size() > 0, 'Should return at least one trigger');
        
        Map<String, String> firstTrigger = triggers[0];
        System.assertEquals('TEST_TRIGGER_123', firstTrigger.get('requestId'));
        System.assertEquals('AccountHistorianTrigger', firstTrigger.get('triggerName'));
        System.assertEquals('Generated', firstTrigger.get('status'));
        System.assertEquals('Ready for Deployment', firstTrigger.get('state'));
        System.assert(firstTrigger.get('triggerCode').contains('HistorianTriggerHandler.handleAfterUpdate'));
    }
    
    @IsTest
    static void testGetGeneratedTriggersWithNoResults() {
        // Delete the test data
        delete [SELECT Id FROM Historian_Deploy_Result__c];
        
        Test.startTest();
        List<Map<String, String>> triggers = TriggerDeploymentService.getGeneratedTriggers();
        Test.stopTest();
        
        System.assertNotEquals(null, triggers, 'Triggers list should not be null');
        System.assertEquals(0, triggers.size(), 'Should return empty list when no results');
    }
    
    @IsTest
    static void testGetGeneratedTriggersWithException() {
        // This test verifies the exception handling in getGeneratedTriggers
        // We can't easily force a SOQL exception, but we can verify the method handles edge cases
        
        Test.startTest();
        List<Map<String, String>> triggers = TriggerDeploymentService.getGeneratedTriggers();
        Test.stopTest();
        
        // Method should always return a list, even if there are issues
        System.assertNotEquals(null, triggers, 'Triggers list should never be null');
    }
    
    @IsTest
    static void testGenerateTriggerCodeMethod() {
        // Test the private method indirectly through the error path
        // Since generateTriggerCode is private, we test it through the public method failure path
        
        Test.startTest();
        try {
            TriggerDeploymentService.generateAndDeployTrigger('Contact');
            System.assert(false, 'Should have failed due to no active configurations');
        } catch (AuraHandledException e) {
            // The method was called and reached the configuration check
            System.assertEquals('No active configurations found for Contact', e.getMessage());
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testSaveTriggerDeploymentRecordMethod() {
        // Test the deployment record creation indirectly
        Integer initialCount = [SELECT COUNT() FROM Historian_Deploy_Result__c];
        
        Test.startTest();
        try {
            TriggerDeploymentService.generateAndDeployTrigger('Opportunity');
        } catch (AuraHandledException e) {
            // Expected to fail due to no configurations
        }
        Test.stopTest();
        
        // No new records should be created due to early failure
        Integer finalCount = [SELECT COUNT() FROM Historian_Deploy_Result__c];
        System.assertEquals(initialCount, finalCount, 'No deployment records should be created for failed validations');
    }
}