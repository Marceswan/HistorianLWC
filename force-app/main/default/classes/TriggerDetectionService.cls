public with sharing class TriggerDetectionService {

    /**
     * Check if a trigger is deployed for a specific object
     * @param objectApiName The API name of the object to check
     * @return Boolean indicating if a trigger exists
     */
    public static Boolean isTriggerDeployed(String objectApiName) {
        if (String.isBlank(objectApiName)) {
            return false;
        }

        try {
            // Query for Apex Triggers on the specified object
            // The trigger name pattern is: Historian_<Object>_Trigger
            String triggerName = 'Historian_' + objectApiName + '_Trigger';

            List<ApexTrigger> triggers = [
                SELECT Id, Name, TableEnumOrId, Status
                FROM ApexTrigger
                WHERE Name = :triggerName
                AND Status = 'Active'
                LIMIT 1
            ];

            return !triggers.isEmpty();
        } catch (Exception e) {
            System.debug('Error checking trigger status for ' + objectApiName + ': ' + e.getMessage());
            return false;
        }
    }

    /**
     * Get trigger deployment status for multiple objects at once
     * @param objectApiNames List of object API names to check
     * @return Map of object API name to Boolean deployment status
     */
    public static Map<String, Boolean> getTriggerStatusMap(List<String> objectApiNames) {
        Map<String, Boolean> statusMap = new Map<String, Boolean>();

        if (objectApiNames == null || objectApiNames.isEmpty()) {
            return statusMap;
        }

        try {
            // Build list of expected trigger names
            Set<String> triggerNames = new Set<String>();
            Map<String, String> triggerNameToObject = new Map<String, String>();

            for (String objectApi : objectApiNames) {
                if (String.isNotBlank(objectApi)) {
                    String triggerName = 'Historian_' + objectApi + '_Trigger';
                    triggerNames.add(triggerName);
                    triggerNameToObject.put(triggerName, objectApi);
                    // Initialize all to false
                    statusMap.put(objectApi, false);
                }
            }

            // Query for all triggers at once
            List<ApexTrigger> triggers = [
                SELECT Name
                FROM ApexTrigger
                WHERE Name IN :triggerNames
                AND Status = 'Active'
            ];

            // Mark found triggers as deployed
            for (ApexTrigger trig : triggers) {
                String objectApi = triggerNameToObject.get(trig.Name);
                if (objectApi != null) {
                    statusMap.put(objectApi, true);
                }
            }

        } catch (Exception e) {
            System.debug('Error checking trigger status for multiple objects: ' + e.getMessage());
            // Return empty or partially filled map on error
        }

        return statusMap;
    }

    /**
     * Get details about a deployed trigger
     * @param objectApiName The API name of the object
     * @return ApexTrigger record or null if not found
     */
    public static ApexTrigger getTriggerDetails(String objectApiName) {
        if (String.isBlank(objectApiName)) {
            return null;
        }

        try {
            String triggerName = 'Historian_' + objectApiName + '_Trigger';

            List<ApexTrigger> triggers = [
                SELECT Id, Name, TableEnumOrId, Status, Body, ApiVersion,
                       CreatedDate, LastModifiedDate, CreatedById, LastModifiedById
                FROM ApexTrigger
                WHERE Name = :triggerName
                LIMIT 1
            ];

            return triggers.isEmpty() ? null : triggers[0];
        } catch (Exception e) {
            System.debug('Error getting trigger details for ' + objectApiName + ': ' + e.getMessage());
            return null;
        }
    }
}