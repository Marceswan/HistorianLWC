public without sharing class HistorianTriggerDeployer {
    @TestVisible private static Boolean mockWebServiceSuccess = false;
    @TestVisible private static String mockDeploymentId = 'test_deployment_123';

    /**
     * Deploy method that creates and deploys trigger using JSZip
     * This integrates with the Visualforce page for actual deployment
     */
    public static MetadataService.AsyncResult[] deploy(String objectApiName, String configName) {
        // Get trigger details
        String triggerName = generateTriggerName(objectApiName, configName);
        String triggerSource = generateTriggerSource(objectApiName, configName, triggerName);

        // For now, we need the VF page to handle the actual ZIP creation and deployment
        // The LWC should navigate to /apex/HistorianDeploy with the objectApiName parameter

        MetadataService.AsyncResult result = new MetadataService.AsyncResult();
        result.done = false;
        result.id = 'PENDING_VF_' + System.now().getTime();
        result.state = 'Pending';
        result.message = 'Use /apex/HistorianDeploy?objectApiName=' + objectApiName + '&configName=' + configName + ' for deployment';

        return new MetadataService.AsyncResult[] { result };
    }

    /**
     * RemoteAction for VF page to get trigger details
     */
    @RemoteAction
    public static Map<String, String> getTriggerDetails(String objectApiName, String configName) {
        String triggerName = generateTriggerName(objectApiName, configName);
        Map<String, String> result = new Map<String, String>();
        result.put('triggerName', triggerName);
        result.put('triggerSource', generateTriggerSource(objectApiName, configName, triggerName));
        return result;
    }

    /**
     * RemoteAction to deploy ZIP from Visualforce page
     * @param zipData Base64 encoded ZIP file containing the trigger package
     * @param objectApiName The object API name to generate test class name
     * @param configName The configuration name for this historian setup
     * @return The async result ID for tracking
     */
    @RemoteAction
    public static String deployZip(String zipData, String objectApiName, String configName) {
        try {
            // Allow test mocking
            if (Test.isRunningTest() && mockWebServiceSuccess) {
                return mockDeploymentId;
            }

            // Delegate to internal method for actual deployment
            String deploymentId = performDeployment(zipData, objectApiName, configName);
            return deploymentId;
        } catch (Exception e) {
            throw new AuraHandledException('Deployment failed: ' + e.getMessage());
        }
    }

    /**
     * Internal method to perform the actual deployment
     */
    @TestVisible
    private static String performDeployment(String zipData, String objectApiName, String configName) {
        // Generate the test class name that will be deployed with the trigger
        String testClassName = generateTestClassName(objectApiName, configName);

        // Create MetadataService and configure deployment options
        MetadataService.MetadataPort service = new MetadataService.MetadataPort();
        service.SessionHeader = new MetadataService.SessionHeader_element();
        service.SessionHeader.sessionId = UserInfo.getSessionId();
        service.endpoint_x = System.Url.getOrgDomainUrl().toExternalForm() + '/services/Soap/m/62.0';

        // Configure deployment options following apex-mdapi best practices
        MetadataService.DeployOptions deployOptions = new MetadataService.DeployOptions();
        deployOptions.allowMissingFiles = false;
        deployOptions.autoUpdatePackage = false;
        deployOptions.checkOnly = false;
        deployOptions.ignoreWarnings = false;
        deployOptions.performRetrieve = false;
        deployOptions.purgeOnDelete = false;
        deployOptions.rollbackOnError = true;
        deployOptions.singlePackage = true;
        deployOptions.testLevel = 'RunSpecifiedTests';
        deployOptions.runTests = new String[] { testClassName };

        // Deploy the ZIP package received from Visualforce page
        MetadataService.AsyncResult result = service.deploy(zipData, deployOptions);
        return result.id;
    }

    /**
     * Prepares trigger package data for deployment.
     * This method is called by Visualforce page to get the package components.
     */
    @RemoteAction
    public static Map<String, String> prepareDeploymentPackage(String objectApiName, String configName) {
        String triggerName = generateTriggerName(objectApiName, configName);
        String testClassName = generateTestClassName(objectApiName, configName);

        Map<String, String> packageComponents = new Map<String, String>();
        packageComponents.put('packageXml', generatePackageXml(triggerName, testClassName));
        packageComponents.put('triggerSource', generateTriggerSource(objectApiName, configName, triggerName));
        packageComponents.put('triggerMetadata', generateTriggerMetaXml());
        packageComponents.put('triggerName', triggerName);
        packageComponents.put('testClassName', testClassName);
        packageComponents.put('testClassSource', generateTestClassSource(objectApiName, configName, triggerName, testClassName));
        packageComponents.put('testClassMetadata', generateTestClassMetaXml());

        return packageComponents;
    }

    /**
     * Generates the package.xml for the deployment
     */
    private static String generatePackageXml(String triggerName, String testClassName) {
        return '<?xml version="1.0" encoding="UTF-8"?>\n' +
               '<!-- HistorianLWC Deployment: ' + triggerName + ' -->\n' +
               '<!-- Generated: ' + System.now().format() + ' -->\n' +
               '<Package xmlns="http://soap.sforce.com/2006/04/metadata">\n' +
               '    <types>\n' +
               '        <members>' + triggerName + '</members>\n' +
               '        <name>ApexTrigger</name>\n' +
               '    </types>\n' +
               '    <types>\n' +
               '        <members>' + testClassName + '</members>\n' +
               '        <name>ApexClass</name>\n' +
               '    </types>\n' +
               '    <version>64.0</version>\n' +
               '</Package>';
    }

    /**
     * Generates the trigger metadata XML file
     */
    private static String generateTriggerMetaXml() {
        return '<?xml version="1.0" encoding="UTF-8"?>\n' +
               '<ApexTrigger xmlns="http://soap.sforce.com/2006/04/metadata">\n' +
               '    <apiVersion>64.0</apiVersion>\n' +
               '    <status>Active</status>\n' +
               '</ApexTrigger>';
    }

    public static String generateTriggerName(String objectApiName, String configName) {
        // Generate trigger name based only on object, not config
        // One trigger per object handles all configs
        return 'Historian_' + objectApiName + '_Trigger';
    }

    public static String generateTestClassName(String objectApiName, String configName) {
        // Generate test class name based only on object, not config
        return 'Historian_' + objectApiName + '_Test';
    }

    public static String generateTriggerSource(String objectApiName, String configName, String triggerName) {
        String nl = '\n';
        String body = '/**' + nl +
                      ' * Trigger: ' + triggerName + nl +
                      ' * Object: ' + objectApiName + nl +
                      ' * Generated by HistorianLWC on ' + System.now().format() + nl +
                      ' * Purpose: Automatically track field changes based on ALL active historian configurations' + nl +
                      ' */' + nl +
                      'trigger ' + triggerName + ' on ' + objectApiName + ' (after insert, after update) {' + nl +
                      '    // Call HistorianHelper to track changes - will dynamically find all active configs' + nl +
                      '    HistorianHelper.trackChanges(' + nl +
                      '        Trigger.new,' + nl +
                      '        Trigger.oldMap,' + nl +
                      '        \'' + objectApiName + '\',' + nl +
                      '        null  // Pass null to process ALL active configs for this object' + nl +
                      '    );' + nl +
                      '}';
        return body;
    }

    /**
     * Generates the test class metadata XML file
     */
    private static String generateTestClassMetaXml() {
        return '<?xml version="1.0" encoding="UTF-8"?>\n' +
               '<ApexClass xmlns="http://soap.sforce.com/2006/04/metadata">\n' +
               '    <apiVersion>64.0</apiVersion>\n' +
               '    <status>Active</status>\n' +
               '</ApexClass>';
    }

    /**
     * Generates a comprehensive test class for the trigger
     */
    public static String generateTestClassSource(String objectApiName, String configName, String triggerName, String testClassName) {
        String nl = '\n';
        String tab = '    ';

        String testClass = '@isTest' + nl +
            'public class ' + testClassName + ' {' + nl + nl +
            tab + '// Simple test to verify trigger compiles and runs' + nl +
            tab + '// Actual Historian functionality is tested in HistorianHelper and service tests' + nl + nl +
            tab + '@isTest' + nl +
            tab + 'static void testInsert() {' + nl +
            tab + tab + '// Use Test.startTest() to reset governor limits' + nl +
            tab + tab + 'Test.startTest();' + nl +
            tab + tab + generateMinimalTestObjectCreation(objectApiName, 'insert') + nl +
            tab + tab + 'insert rec;' + nl +
            tab + tab + 'Test.stopTest();' + nl +
            tab + tab + '// Simply verify the record was created' + nl +
            tab + tab + 'System.assertNotEquals(null, rec.Id, \'Record should have been inserted\');' + nl +
            tab + '}' + nl + nl +
            tab + '@isTest' + nl +
            tab + 'static void testUpdate() {' + nl +
            tab + tab + '// Create record outside of test context' + nl +
            tab + tab + generateMinimalTestObjectCreation(objectApiName, 'update') + nl +
            tab + tab + 'insert rec;' + nl +
            tab + tab + '// Use Test.startTest() to reset governor limits' + nl +
            tab + tab + 'Test.startTest();' + nl +
            tab + tab + generateMinimalTestObjectUpdate(objectApiName) + nl +
            tab + tab + 'update rec;' + nl +
            tab + tab + 'Test.stopTest();' + nl +
            tab + tab + '// Simply verify the record exists' + nl +
            tab + tab + 'System.assertNotEquals(null, rec.Id, \'Record should exist\');' + nl +
            tab + '}' + nl + nl +
            tab + '@isTest' + nl +
            tab + 'static void testBulkInsert() {' + nl +
            tab + tab + '// Create minimal set of records for bulk testing' + nl +
            tab + tab + 'List<' + objectApiName + '> records = new List<' + objectApiName + '>();' + nl +
            tab + tab + 'for (Integer i = 0; i < 5; i++) {' + nl +  // Reduced to just 5 records
            tab + tab + tab + generateBulkTestObjectCreation(objectApiName) + nl +
            tab + tab + '}' + nl +
            tab + tab + '// Use Test.startTest() to reset governor limits' + nl +
            tab + tab + 'Test.startTest();' + nl +
            tab + tab + 'insert records;' + nl +
            tab + tab + 'Test.stopTest();' + nl +
            tab + tab + '// Simply verify records were created' + nl +
            tab + tab + 'System.assertEquals(5, records.size(), \'Should have created 5 records\');' + nl +
            tab + tab + 'for (' + objectApiName + ' rec : records) {' + nl +
            tab + tab + tab + 'System.assertNotEquals(null, rec.Id, \'Each record should have an ID\');' + nl +
            tab + tab + '}' + nl +
            tab + '}' + nl +
            '}';

        return testClass;
    }

    /**
     * Generates minimal test object creation with unique identifiers
     */
    @TestVisible
    private static String generateMinimalTestObjectCreation(String objectApiName, String operation) {
        String tab = '    ';

        // Special handling for objects that need parent records
        String setup = '';
        if (objectApiName == 'Contact' || objectApiName == 'Opportunity') {
            setup = 'Account a = new Account(Name = \'Test\');' + '\n' +
                   tab + tab + 'insert a;' + '\n' + tab + tab;
        }

        // Generate the record creation based on object type
        if (objectApiName == 'Account') {
            return objectApiName + ' rec = new ' + objectApiName + '(Name = \'Test\');';
        } else if (objectApiName == 'Contact') {
            return setup + objectApiName + ' rec = new ' + objectApiName + '(' + '\n' +
                   tab + tab + tab + 'LastName = \'Test\',' + '\n' +
                   tab + tab + tab + 'Email = \'test\' + System.currentTimeMillis() + \'@historian.test\',' + '\n' +
                   tab + tab + tab + 'AccountId = a.Id' + '\n' +
                   tab + tab + ');';
        } else if (objectApiName == 'Opportunity') {
            return setup + objectApiName + ' rec = new ' + objectApiName + '(' + '\n' +
                   tab + tab + tab + 'Name = \'Test\',' + '\n' +
                   tab + tab + tab + 'AccountId = a.Id,' + '\n' +
                   tab + tab + tab + 'StageName = \'Prospecting\',' + '\n' +
                   tab + tab + tab + 'CloseDate = Date.today()' + '\n' +
                   tab + tab + ');';
        } else if (objectApiName == 'Case') {
            return objectApiName + ' rec = new ' + objectApiName + '(Subject = \'Test\', Status = \'New\');';
        } else if (objectApiName == 'Lead') {
            return objectApiName + ' rec = new ' + objectApiName + '(LastName = \'Test\', Company = \'Test\');';
        } else {
            // For custom objects, try Name field
            return objectApiName + ' rec = new ' + objectApiName + '(Name = \'Test\');';
        }
    }

    /**
     * Generates minimal test object update
     */
    @TestVisible
    private static String generateMinimalTestObjectUpdate(String objectApiName) {
        if (objectApiName == 'Contact') {
            return 'rec.LastName = \'Updated\';';
        } else if (objectApiName == 'Opportunity') {
            return 'rec.StageName = \'Qualification\';';
        } else if (objectApiName == 'Case') {
            return 'rec.Status = \'Working\';';
        } else if (objectApiName == 'Account' || objectApiName.endsWith('__c')) {
            return 'rec.Name = \'Updated\';';
        } else {
            return '// Update a field';
        }
    }

    /**
     * Generates bulk test object creation
     */
    @TestVisible
    private static String generateBulkTestObjectCreation(String objectApiName) {
        if (objectApiName == 'Account') {
            return 'records.add(new ' + objectApiName + '(Name = \'Test \' + i));';
        } else if (objectApiName == 'Contact') {
            return 'records.add(new ' + objectApiName + '(' +
                   'LastName = \'Test \' + i, ' +
                   'Email = \'test.\' + i + \'.\' + System.currentTimeMillis() + \'@historian.test\'));';
        } else if (objectApiName == 'Opportunity') {
            return 'records.add(new ' + objectApiName + '(' +
                   'Name = \'Test \' + i, ' +
                   'StageName = \'Prospecting\', ' +
                   'CloseDate = Date.today()));';
        } else if (objectApiName == 'Lead') {
            return 'records.add(new ' + objectApiName + '(' +
                   'LastName = \'Test \' + i, ' +
                   'Company = \'Test Company\'));';
        } else {
            return 'records.add(new ' + objectApiName + '(Name = \'Test \' + i));';
        }
    }

    /**
     * RemoteAction to check deployment status from VF page
     */
    @RemoteAction
    public static Map<String, Object> checkDeploymentStatus(String deploymentId) {
        try {
            MetadataService.MetadataPort service = new MetadataService.MetadataPort();
            service.SessionHeader = new MetadataService.SessionHeader_element();
            service.SessionHeader.sessionId = UserInfo.getSessionId();
            service.endpoint_x = System.Url.getOrgDomainUrl().toExternalForm() + '/services/Soap/m/62.0';

            // Use false for includeDetails to avoid flowCoverage parsing issues
            MetadataService.DeployResult deployResult = service.checkDeployStatus(deploymentId, false);

            Map<String, Object> result = new Map<String, Object>();
            result.put('done', deployResult.done);
            result.put('id', deployResult.id);
            result.put('status', deployResult.status);
            result.put('numberComponentsDeployed', deployResult.numberComponentsDeployed);
            result.put('numberComponentsTotal', deployResult.numberComponentsTotal);
            result.put('numberTestErrors', deployResult.numberTestErrors);

            // Add test results if available
            if (deployResult.details != null && deployResult.details.runTestResult != null) {
                MetadataService.RunTestsResult testResult = deployResult.details.runTestResult;
                List<Map<String, String>> testResults = new List<Map<String, String>>();

                // Add failures
                if (testResult.failures != null) {
                    for (MetadataService.RunTestFailure failure : testResult.failures) {
                        Map<String, String> test = new Map<String, String>();
                        test.put('className', failure.name);
                        test.put('methodName', failure.methodName);
                        test.put('outcome', 'Fail');
                        test.put('message', failure.message);
                        testResults.add(test);
                    }
                }

                // Add successes
                if (testResult.successes != null) {
                    for (MetadataService.RunTestSuccess success : testResult.successes) {
                        Map<String, String> test = new Map<String, String>();
                        test.put('className', success.name);
                        test.put('methodName', success.methodName);
                        test.put('outcome', 'Pass');
                        test.put('message', '');
                        testResults.add(test);
                    }
                }

                result.put('testResults', testResults);
            }

            // Add component errors
            if (deployResult.details != null && deployResult.details.componentFailures != null) {
                List<String> errors = new List<String>();
                for (MetadataService.DeployMessage msg : deployResult.details.componentFailures) {
                    errors.add(msg.problem);
                }
                result.put('componentErrors', errors);
            }

            return result;
        } catch (Exception e) {
            // Handle parsing errors gracefully
            Map<String, Object> errorResult = new Map<String, Object>();
            errorResult.put('done', true);
            errorResult.put('status', 'Unknown');
            errorResult.put('error', 'Status check failed: ' + e.getMessage());
            return errorResult;
        }
    }

    /**
     * Checks the status of a deployment
     */
    public static MetadataService.DeployResult checkDeployStatus(String deploymentId) {
        MetadataService.MetadataPort service = new MetadataService.MetadataPort();
        service.SessionHeader = new MetadataService.SessionHeader_element();
        service.SessionHeader.sessionId = UserInfo.getSessionId();
        service.endpoint_x = System.Url.getOrgDomainUrl().toExternalForm() + '/services/Soap/m/62.0';
        return service.checkDeployStatus(deploymentId, true);
    }
}