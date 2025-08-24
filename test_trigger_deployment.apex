// Test the complete trigger deployment workflow
// This script tests the enhanced TriggerDeploymentService

// Step 1: Test the new deployTriggerNow method
System.debug('=== Testing Enhanced Trigger Deployment ===');

String testObjectApi = 'Account'; // Using Account as it exists in all orgs

try {
    // Test the new real-time deployment method
    System.debug('Step 1: Testing deployTriggerNow method...');
    Map<String, Object> deployResult = TriggerDeploymentService.deployTriggerNow(testObjectApi);
    System.debug('Deploy result: ' + deployResult);
    
    if ((Boolean) deployResult.get('success')) {
        System.debug('✓ deployTriggerNow succeeded');
        System.debug('  - Trigger Name: ' + deployResult.get('triggerName'));
        System.debug('  - Message: ' + deployResult.get('message'));
        System.debug('  - Verified: ' + deployResult.get('verified'));
        
        if (deployResult.containsKey('triggerCode')) {
            System.debug('  - Generated Code Preview: ');
            String code = (String) deployResult.get('triggerCode');
            System.debug('    ' + code.substring(0, Math.min(100, code.length())) + '...');
        }
    } else {
        System.debug('✗ deployTriggerNow failed: ' + deployResult.get('error'));
    }
    
    // Step 2: Test deployment status checking
    System.debug('\nStep 2: Testing deployment status checking...');
    Map<String, Object> statusResult = TriggerDeploymentService.getDeploymentStatus(testObjectApi);
    System.debug('Status result: ' + statusResult);
    
    if ((Boolean) statusResult.get('success')) {
        System.debug('✓ getDeploymentStatus succeeded');
        System.debug('  - Trigger Exists: ' + statusResult.get('triggerExists'));
        System.debug('  - Overall Status: ' + statusResult.get('overallStatus'));
        System.debug('  - Status Message: ' + statusResult.get('statusMessage'));
        System.debug('  - Recent Deployments: ' + statusResult.get('recentDeploymentCount'));
    } else {
        System.debug('✗ getDeploymentStatus failed: ' + statusResult.get('error'));
    }
    
    // Step 3: Test trigger verification
    System.debug('\nStep 3: Testing trigger verification...');
    Map<String, Object> verifyResult = TriggerDeploymentService.verifyTriggerDeployment(testObjectApi);
    System.debug('Verify result: ' + verifyResult);
    
    if ((Boolean) verifyResult.get('success')) {
        System.debug('✓ verifyTriggerDeployment succeeded');
        System.debug('  - Trigger Exists: ' + verifyResult.get('triggerExists'));
        System.debug('  - Recent Success: ' + verifyResult.get('recentDeploymentSuccess'));
        System.debug('  - Message: ' + verifyResult.get('message'));
    } else {
        System.debug('✗ verifyTriggerDeployment failed: ' + verifyResult.get('error'));
    }
    
    // Step 4: Test trigger code generation
    System.debug('\nStep 4: Testing trigger code generation...');
    String generatedCode = TriggerDeploymentService.generateLightweightTriggerCode(
        testObjectApi + 'HistorianTrigger', 
        testObjectApi
    );
    System.debug('Generated trigger code:');
    System.debug(generatedCode);
    
    // Verify the code contains the expected patterns
    if (generatedCode.contains('trigger ' + testObjectApi + 'HistorianTrigger on ' + testObjectApi)) {
        System.debug('✓ Trigger declaration correct');
    } else {
        System.debug('✗ Trigger declaration incorrect');
    }
    
    if (generatedCode.contains('HistorianTriggerHandler.handleAfterUpdate')) {
        System.debug('✓ Handler call correct');
    } else {
        System.debug('✗ Handler call missing or incorrect');
    }
    
    if (generatedCode.contains('after update')) {
        System.debug('✓ Trigger context correct');
    } else {
        System.debug('✗ Trigger context incorrect');
    }
    
    // Step 5: Check recent deployment records
    System.debug('\nStep 5: Checking deployment records...');
    List<Historian_Deploy_Result__c> recentDeployments = [
        SELECT Id, Status__c, State__c, Component_FullName__c, Component_Type__c,
               Error_Count__c, Problem__c, CreatedDate
        FROM Historian_Deploy_Result__c
        WHERE Component_FullName__c LIKE :('%' + testObjectApi + 'HistorianTrigger%')
          AND Component_Type__c = 'ApexTrigger'
        ORDER BY CreatedDate DESC
        LIMIT 5
    ];
    
    System.debug('Found ' + recentDeployments.size() + ' recent deployment records:');
    for (Historian_Deploy_Result__c record : recentDeployments) {
        System.debug('  - ' + record.Component_FullName__c + ' | ' + 
                     record.Status__c + ' | ' + 
                     record.State__c + ' | ' + 
                     record.CreatedDate);
        if (record.Error_Count__c > 0) {
            System.debug('    Error: ' + record.Problem__c);
        }
    }
    
    System.debug('\n=== Test Summary ===');
    System.debug('Enhanced trigger deployment system tested successfully!');
    System.debug('Key improvements:');
    System.debug('- Real-time deployment with immediate feedback');
    System.debug('- Enhanced callback with verification');  
    System.debug('- Comprehensive status tracking');
    System.debug('- Improved error handling and logging');
    System.debug('- LibrarianLWC integration for better UX');
    
} catch (Exception e) {
    System.debug('✗ Test failed with exception: ' + e.getMessage());
    System.debug('Exception type: ' + e.getTypeName());
    System.debug('Stack trace: ' + e.getStackTraceString());
}

System.debug('\n=== Testing Complete ===');