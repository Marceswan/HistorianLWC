trigger OpportunityHistorianTrigger on Opportunity (after update) {
    // Auto-generated historian trigger for Opportunity
    System.debug('OpportunityHistorianTrigger executed');
    
    if (Trigger.isAfter && Trigger.isUpdate) {
        try {
            // Query the Historian Config metadata for this object
            String objectApiName = 'Opportunity';
            List<Historian_Config__mdt> configs = [
                SELECT Id, DeveloperName, Object_Api_Name__c, Track_Mode__c, 
                       Tracking_Style__c, Active__c, History_Object_Api__c
                FROM Historian_Config__mdt 
                WHERE Object_Api_Name__c = :objectApiName 
                  AND Active__c = true
                LIMIT 1
            ];
            
            if (!configs.isEmpty()) {
                Historian_Config__mdt config = configs[0];
                System.debug('Found active historian config: ' + config.DeveloperName);
                
                // Log the changes for testing
                System.debug('Processing Opportunity changes: ' + Trigger.new.size() + ' records');
                
                for (Opportunity oldOpp : (List<Opportunity>)Trigger.old) {
                    Opportunity newOpp = (Opportunity)Trigger.newMap.get(oldOpp.Id);
                    
                    // Log specific field changes
                    if (oldOpp.Amount != newOpp.Amount) {
                        System.debug('Opportunity ' + newOpp.Name + ' Amount changed from ' + oldOpp.Amount + ' to ' + newOpp.Amount);
                    }
                    if (oldOpp.StageName != newOpp.StageName) {
                        System.debug('Opportunity ' + newOpp.Name + ' Stage changed from ' + oldOpp.StageName + ' to ' + newOpp.StageName);
                    }
                    if (oldOpp.CloseDate != newOpp.CloseDate) {
                        System.debug('Opportunity ' + newOpp.Name + ' Close Date changed from ' + oldOpp.CloseDate + ' to ' + newOpp.CloseDate);
                    }
                }
                
                // TODO: Call HistorianChangeService.createHistorianRecords() when available
            } else {
                System.debug('No active historian configuration found for Opportunity');
            }
        } catch (Exception e) {
            System.debug('Error in OpportunityHistorianTrigger: ' + e.getMessage());
            // Log error but don't fail the transaction
        }
    }
}