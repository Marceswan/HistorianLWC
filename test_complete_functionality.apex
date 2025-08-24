// Test the complete historian object creation with record type support
System.debug('=== Testing complete historian functionality ===');

// Test 1: Verify Opportunity_Historian__c exists
Boolean opportunityHistorianExists = Schema.getGlobalDescribe().containsKey('Opportunity_Historian__c');
System.debug('Opportunity_Historian__c exists: ' + opportunityHistorianExists);

// Test 2: Check remote site settings
try {
    Boolean remoteSiteReady = MdapiUtil.ensureRemoteSiteSettings();
    System.debug('Remote site settings ready: ' + remoteSiteReady);
} catch (Exception e) {
    System.debug('Remote site check error: ' + e.getMessage());
}

// Test 3: Test record type functionality for Account object
try {
    String accountObjectApi = 'Account';
    Schema.SObjectType accountType = Schema.getGlobalDescribe().get(accountObjectApi);
    if (accountType != null) {
        Schema.DescribeSObjectResult accountDescribe = accountType.getDescribe();
        Map<String,Schema.RecordTypeInfo> recordTypeMap = accountDescribe.getRecordTypeInfosByDeveloperName();
        System.debug('Account record types available: ' + recordTypeMap.size());
        for (String rtName : recordTypeMap.keySet()) {
            System.debug('Record type: ' + rtName + ' - Available: ' + recordTypeMap.get(rtName).isAvailable());
        }
    }
} catch (Exception e) {
    System.debug('Record type test error: ' + e.getMessage());
}

System.debug('=== Complete functionality test finished ===');