global with sharing class HistorianDeployCallback implements Metadata.DeployCallback {
    global void handleResult(Metadata.DeployResult result, Metadata.DeployCallbackContext context) {
        try {
            Historian_Deploy_Result__c rec = new Historian_Deploy_Result__c();
            // Request Id may not be available; omit if not supported
            rec.Status__c = String.valueOf(result.status);
            rec.Error_Count__c = (result.numberComponentErrors != null) ? Integer.valueOf(result.numberComponentErrors) : 0;
            rec.Completed_On__c = System.now();

            if (result.details != null && result.details.componentFailures != null) {
                List<Metadata.DeployMessage> failures = (List<Metadata.DeployMessage>) result.details.componentFailures;
                if (failures != null && !failures.isEmpty()) {
                    Metadata.DeployMessage m = failures[0];
                    rec.Component_FullName__c = m.fullName;
                    rec.Component_Type__c = m.componentType;
                    String problem = '';
                    if (m.problem != null) problem += m.problem;
                    if (m.problemType != null) problem += ' (' + m.problemType + ')';
                    rec.Problem__c = problem;
                }
            }
            insert rec;
        } catch (Exception e) {
            // Swallow to avoid callback failure
        }
    }
}
