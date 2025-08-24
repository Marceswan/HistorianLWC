@IsTest
private class HistorianPermissionServiceTest {
    
    @IsTest
    static void testGetHistorianPermissionsInfo() {
        Test.startTest();
        
        Map<String, Object> result = HistorianPermissionService.getHistorianPermissionsInfo();
        
        Test.stopTest();
        
        // Verify the result contains expected keys
        System.assert(result.containsKey('historianObjects'), 'Result should contain historianObjects key');
        System.assert(result.containsKey('objectCount'), 'Result should contain objectCount key');
        System.assert(result.containsKey('permissionSetExists'), 'Result should contain permissionSetExists key');
        System.assert(result.containsKey('assignmentCount'), 'Result should contain assignmentCount key');
        
        // Verify object count is a number
        Object objectCount = result.get('objectCount');
        System.assert(objectCount instanceof Integer, 'Object count should be an integer');
        
        // Verify historianObjects is a list
        Object historianObjects = result.get('historianObjects');
        System.assert(historianObjects instanceof List<String>, 'Historian objects should be a list of strings');
    }
    
    @IsTest
    static void testAssignPermissionSetToAllUsers() {
        Test.startTest();
        
        // This will return a message about permission set not existing since we haven't created one
        String result = HistorianPermissionService.assignPermissionSetToAllUsers();
        
        Test.stopTest();
        
        System.assert(result.contains('not found'), 'Should indicate permission set not found');
    }
    
    @IsTest
    static void testEnsureHistorianPermissions() {
        Test.startTest();
        
        try {
            // Mock the metadata service call by catching the exception
            String result = HistorianPermissionService.ensureHistorianPermissions();
            
            // If no Historian objects exist, should get appropriate message
            System.assert(result.contains('No Historian objects found') || result.contains('Successfully configured'), 
                         'Should get appropriate message about Historian objects');
            
        } catch (AuraHandledException e) {
            // Expected if no remote site settings are configured or other metadata issues
            System.assert(e.getMessage().contains('Error configuring Historian permissions'), 
                         'Should get appropriate error message');
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testPermissionServiceWithMockedData() {
        // Test the service methods without actually creating metadata
        Test.startTest();
        
        // Test getting info about permissions
        Map<String, Object> info = HistorianPermissionService.getHistorianPermissionsInfo();
        System.assertNotEquals(null, info, 'Info should not be null');
        
        // Verify the structure
        System.assert(info.containsKey('historianObjects'), 'Should contain historian objects');
        System.assert(info.containsKey('objectCount'), 'Should contain object count');
        System.assert(info.containsKey('permissionSetExists'), 'Should contain permission set exists flag');
        
        Test.stopTest();
    }
}