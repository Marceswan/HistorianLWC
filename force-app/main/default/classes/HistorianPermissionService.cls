public with sharing class HistorianPermissionService {
    
    /**
     * Ensures all profiles have read/write access to Historian objects
     * This method creates or updates permission sets to grant access to *_Historian__c objects
     */
    @AuraEnabled
    public static String ensureHistorianPermissions() {
        try {
            List<String> historianObjects = getHistorianObjects();
            
            if (historianObjects.isEmpty()) {
                return 'No Historian objects found to configure permissions for.';
            }
            
            // Create or update a general permission set for Historian objects
            createOrUpdateHistorianPermissionSet(historianObjects);
            
            return 'Successfully configured permissions for ' + historianObjects.size() + ' Historian objects: ' + String.join(historianObjects, ', ');
            
        } catch (Exception e) {
            System.debug('Error in ensureHistorianPermissions: ' + e.getMessage());
            throw new AuraHandledException('Error configuring Historian permissions: ' + e.getMessage());
        }
    }
    
    /**
     * Gets all custom objects that end with _Historian__c
     */
    private static List<String> getHistorianObjects() {
        List<String> historianObjects = new List<String>();
        
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        
        for (String objectName : globalDescribe.keySet()) {
            if (objectName.endsWith('_Historian__c')) {
                historianObjects.add(objectName);
            }
        }
        
        return historianObjects;
    }
    
    /**
     * Creates or updates the Historian Objects permission set using Metadata API
     */
    private static void createOrUpdateHistorianPermissionSet(List<String> historianObjects) {
        // Use Metadata API to create/update permission set
        MetadataService.MetadataPort service = MdapiUtil.newService();
        
        // Create permission set metadata
        MetadataService.PermissionSet permSet = new MetadataService.PermissionSet();
        permSet.fullName = 'Historian_Objects_Access';
        permSet.label = 'Historian Objects Access';
        permSet.description = 'Provides read/write access to all Historian objects';
        permSet.hasActivationRequired = false;
        
        // Add object permissions for each Historian object
        List<MetadataService.PermissionSetObjectPermissions> objectPermissions = new List<MetadataService.PermissionSetObjectPermissions>();
        
        for (String historianObject : historianObjects) {
            MetadataService.PermissionSetObjectPermissions objPerm = new MetadataService.PermissionSetObjectPermissions();
            objPerm.object_x = historianObject;
            objPerm.allowRead = true;
            objPerm.allowCreate = true;
            objPerm.allowEdit = true;
            objPerm.allowDelete = true;
            objPerm.viewAllRecords = true;
            objPerm.modifyAllRecords = true;
            
            objectPermissions.add(objPerm);
            
            // Add field permissions for all fields
            addFieldPermissions(permSet, historianObject);
        }
        
        permSet.objectPermissions = objectPermissions;
        
        // Deploy the permission set
        try {
            MetadataService.UpsertResult[] results = service.upsertMetadata(new MetadataService.Metadata[] { permSet });
            
            if (results != null && results.size() > 0 && !results[0].success) {
                String errorMessage = 'Permission set deployment failed';
                if (results[0].errors != null && results[0].errors.size() > 0) {
                    errorMessage += ': ' + results[0].errors[0].message;
                }
                throw new AuraHandledException(errorMessage);
            }
            
            System.debug('Successfully created/updated Historian_Objects_Access permission set');
            
        } catch (Exception e) {
            System.debug('Error deploying permission set: ' + e.getMessage());
            throw new AuraHandledException('Failed to deploy permission set: ' + e.getMessage());
        }
    }
    
    /**
     * Adds field permissions for all fields in a Historian object
     */
    private static void addFieldPermissions(MetadataService.PermissionSet permSet, String objectName) {
        try {
            Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
            if (objType != null) {
                Map<String, Schema.SObjectField> fieldsMap = objType.getDescribe().fields.getMap();
                
                List<MetadataService.PermissionSetFieldPermissions> fieldPermissions = new List<MetadataService.PermissionSetFieldPermissions>();
                
                for (String fieldName : fieldsMap.keySet()) {
                    Schema.DescribeFieldResult fieldDesc = fieldsMap.get(fieldName).getDescribe();
                    
                    // Skip system fields and non-custom fields for permission sets
                    if (fieldDesc.isCustom() && fieldDesc.isAccessible()) {
                        MetadataService.PermissionSetFieldPermissions fieldPerm = new MetadataService.PermissionSetFieldPermissions();
                        fieldPerm.field = objectName + '.' + fieldDesc.getName();
                        fieldPerm.readable = true;
                        fieldPerm.editable = fieldDesc.isUpdateable();
                        
                        fieldPermissions.add(fieldPerm);
                    }
                }
                
                if (permSet.fieldPermissions == null) {
                    permSet.fieldPermissions = new List<MetadataService.PermissionSetFieldPermissions>();
                }
                permSet.fieldPermissions.addAll(fieldPermissions);
            }
        } catch (Exception e) {
            System.debug('Error adding field permissions for ' + objectName + ': ' + e.getMessage());
            // Continue processing other objects even if one fails
        }
    }
    
    /**
     * Alternative method using Permission Set Assignment for existing profiles
     * Call this after creating the permission set to assign it to all profiles
     */
    @AuraEnabled
    public static String assignPermissionSetToAllUsers() {
        try {
            // Get the permission set ID
            List<PermissionSet> permSets = [
                SELECT Id, Name 
                FROM PermissionSet 
                WHERE Name = 'Historian_Objects_Access' 
                LIMIT 1
            ];
            
            if (permSets.isEmpty()) {
                return 'Historian_Objects_Access permission set not found. Please create it first.';
            }
            
            Id permSetId = permSets[0].Id;
            
            // Get all active users
            List<User> activeUsers = [
                SELECT Id 
                FROM User 
                WHERE IsActive = true
            ];
            
            // Check existing assignments
            Set<Id> assignedUserIds = new Set<Id>();
            for (PermissionSetAssignment psa : [
                SELECT AssigneeId 
                FROM PermissionSetAssignment 
                WHERE PermissionSetId = :permSetId
            ]) {
                assignedUserIds.add(psa.AssigneeId);
            }
            
            // Create assignments for users who don't have it
            List<PermissionSetAssignment> assignmentsToCreate = new List<PermissionSetAssignment>();
            
            for (User u : activeUsers) {
                if (!assignedUserIds.contains(u.Id)) {
                    PermissionSetAssignment psa = new PermissionSetAssignment();
                    psa.AssigneeId = u.Id;
                    psa.PermissionSetId = permSetId;
                    assignmentsToCreate.add(psa);
                }
            }
            
            if (!assignmentsToCreate.isEmpty()) {
                insert assignmentsToCreate;
                return 'Successfully assigned Historian Objects Access permission set to ' + assignmentsToCreate.size() + ' users.';
            } else {
                return 'All active users already have the Historian Objects Access permission set assigned.';
            }
            
        } catch (Exception e) {
            System.debug('Error in assignPermissionSetToAllUsers: ' + e.getMessage());
            throw new AuraHandledException('Error assigning permission set: ' + e.getMessage());
        }
    }
    
    /**
     * Gets information about current Historian objects and their permissions
     */
    @AuraEnabled
    public static Map<String, Object> getHistorianPermissionsInfo() {
        Map<String, Object> result = new Map<String, Object>();
        
        try {
            List<String> historianObjects = getHistorianObjects();
            result.put('historianObjects', historianObjects);
            result.put('objectCount', historianObjects.size());
            
            // Check if permission set exists
            List<PermissionSet> permSets = [
                SELECT Id, Name, Label 
                FROM PermissionSet 
                WHERE Name = 'Historian_Objects_Access' 
                LIMIT 1
            ];
            
            result.put('permissionSetExists', !permSets.isEmpty());
            
            if (!permSets.isEmpty()) {
                // Count assignments
                Integer assignmentCount = [
                    SELECT COUNT() 
                    FROM PermissionSetAssignment 
                    WHERE PermissionSetId = :permSets[0].Id
                ];
                result.put('assignmentCount', assignmentCount);
            } else {
                result.put('assignmentCount', 0);
            }
            
            return result;
            
        } catch (Exception e) {
            result.put('error', e.getMessage());
            return result;
        }
    }
}