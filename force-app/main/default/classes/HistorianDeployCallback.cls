global with sharing class HistorianDeployCallback implements Metadata.DeployCallback {
    
    // Store trigger deployment context
    private String triggerName;
    private String objectApiName;
    
    /**
     * Set trigger information for enhanced callback handling
     */
    public void setTriggerInfo(String triggerName, String objectApiName) {
        this.triggerName = triggerName;
        this.objectApiName = objectApiName;
    }
    
    global void handleResult(Metadata.DeployResult result, Metadata.DeployCallbackContext context) {
        try {
            System.debug('HistorianDeployCallback.handleResult called');
            System.debug('Deployment status: ' + result.status);
            System.debug('Deployment done: ' + result.done);
            System.debug('Deployment success: ' + result.success);
            
            Historian_Deploy_Result__c rec = new Historian_Deploy_Result__c();
            
            // Set basic deployment information
            rec.Status__c = String.valueOf(result.status);
            rec.State__c = result.done ? 'Completed' : 'InProgress';
            rec.Error_Count__c = (result.numberComponentErrors != null) ? Integer.valueOf(result.numberComponentErrors) : 0;
            rec.Completed_On__c = System.now();
            
            // Set trigger-specific information if available
            if (String.isNotBlank(this.triggerName)) {
                rec.Component_FullName__c = this.triggerName;
                rec.Component_Type__c = 'ApexTrigger';
                rec.Request_Id__c = 'MDAPI_DEPLOY_' + System.currentTimeMillis();
            }
            
            // Handle deployment success
            if (result.done && result.success) {
                System.debug('Deployment completed successfully');
                
                if (String.isNotBlank(this.objectApiName)) {
                    // Verify the trigger was actually deployed
                    try {
                        Boolean triggerExists = TriggerDetectionService.isTriggerDeployed(this.objectApiName);
                        if (triggerExists) {
                            rec.Problem__c = 'Trigger deployed and verified successfully for ' + this.objectApiName;
                            System.debug('Trigger deployment verified: ' + this.triggerName);
                        } else {
                            rec.Problem__c = 'Trigger deployment completed but verification failed for ' + this.objectApiName;
                            rec.Error_Count__c = 1;
                            System.debug('WARNING: Trigger deployment completed but verification failed: ' + this.triggerName);
                        }
                    } catch (Exception verifyEx) {
                        rec.Problem__c = 'Trigger deployed but verification error: ' + verifyEx.getMessage();
                        System.debug('Error during trigger verification: ' + verifyEx.getMessage());
                    }
                } else {
                    rec.Problem__c = 'Deployment completed successfully';
                }
            }
            // Handle deployment failure
            else if (result.done && !result.success) {
                System.debug('Deployment failed');
                rec.Status__c = 'Failed';
                rec.State__c = 'Failed';
                
                String problemDetails = 'Deployment failed';
                
                if (result.details != null && result.details.componentFailures != null) {
                    List<Metadata.DeployMessage> failures = (List<Metadata.DeployMessage>) result.details.componentFailures;
                    if (failures != null && !failures.isEmpty()) {
                        Metadata.DeployMessage m = failures[0];
                        
                        // Use trigger info if we have it, otherwise use metadata info
                        if (String.isBlank(rec.Component_FullName__c)) {
                            rec.Component_FullName__c = m.fullName;
                        }
                        if (String.isBlank(rec.Component_Type__c)) {
                            rec.Component_Type__c = m.componentType;
                        }
                        
                        problemDetails = '';
                        if (m.problem != null) problemDetails += m.problem;
                        if (m.problemType != null) problemDetails += ' (' + m.problemType + ')';
                        if (m.lineNumber != null && m.lineNumber > 0) problemDetails += ' [Line ' + m.lineNumber + ']';
                        
                        System.debug('Component failure details: ' + problemDetails);
                    }
                }
                
                rec.Problem__c = problemDetails;
            }
            // Handle in-progress deployment
            else {
                System.debug('Deployment still in progress');
                rec.Problem__c = 'Deployment in progress...';
            }
            
            // Attempt to insert the deployment result record
            insert rec;
            System.debug('Deployment result record created: ' + rec.Id);
            
        } catch (Exception e) {
            // Log error but don't throw to avoid callback failure
            System.debug('Error in HistorianDeployCallback: ' + e.getMessage());
            System.debug('Exception stack trace: ' + e.getStackTraceString());
            
            // Try to create a minimal error record
            try {
                Historian_Deploy_Result__c errorRec = new Historian_Deploy_Result__c(
                    Status__c = 'CallbackError',
                    State__c = 'Failed',
                    Error_Count__c = 1,
                    Component_FullName__c = this.triggerName,
                    Component_Type__c = 'ApexTrigger',
                    Problem__c = 'Callback processing error: ' + e.getMessage(),
                    Completed_On__c = System.now()
                );
                insert errorRec;
            } catch (Exception insertEx) {
                System.debug('Failed to insert error record: ' + insertEx.getMessage());
            }
        }
    }
}
