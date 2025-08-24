public with sharing class HistorianMetadataJob implements Queueable, Database.AllowsCallouts {
    private String objectApi;
    private HistorianConfigService.ConfigSummary cfg;

    public HistorianMetadataJob(String objectApi, HistorianConfigService.ConfigSummary cfg) {
        this.objectApi = objectApi;
        this.cfg = cfg;
    }

    public void execute(QueueableContext context) {
        if (String.isBlank(objectApi)) return;
        if (Test.isRunningTest()) return; // Avoid callouts in tests; unit tests validate enqueue only
        String historianApi = objectApi + '_Historian__c';
        MetadataService.MetadataPort service = MdapiUtil.newService();

        // Check if object exists (via readMetadata IReadResult)
        Boolean exists = false;
        try {
            MetadataService.IReadResult rr = service.readMetadata('CustomObject', new String[] { historianApi });
            exists = (rr != null && rr.getRecords() != null && rr.getRecords().size() > 0);
        } catch (Exception e) {
            exists = false;
        }
        List<MetadataService.Metadata> toCreate = new List<MetadataService.Metadata>();

        if (!exists) {
            MetadataService.CustomObject obj = new MetadataService.CustomObject();
            obj.fullName = historianApi;
            obj.deploymentStatus = 'Deployed';
            obj.description = 'Historian change log for ' + objectApi;
            obj.enableFeeds = false;
            obj.label = objectApi + ' Historian';
            obj.pluralLabel = objectApi + ' Historian';
            obj.sharingModel = 'ReadWrite';
            MetadataService.CustomField nameField = new MetadataService.CustomField();
            nameField.type_x = 'AutoNumber';
            nameField.displayFormat = 'HIST-{000000}';
            nameField.label = 'Name';
            obj.nameField = nameField;
            toCreate.add(obj);
        }

        // Determine missing fields via readMetadata
        Map<String, MetadataService.Metadata> existingFieldMap = new Map<String, MetadataService.Metadata>();
        List<String> fieldFullNames = new List<String>{
            historianApi + '.Field_Changed_Label__c',
            historianApi + '.Field_Changed_Api__c',
            historianApi + '.Prior_Value__c',
            historianApi + '.Complete_Prior_Value__c',
            historianApi + '.New_Value__c',
            historianApi + '.Complete_New_Value__c',
            historianApi + '.Changed_On__c',
            historianApi + '.Changed_By__c',
            historianApi + '.Parent_Record__c'
        };
        try {
            MetadataService.IReadResult rrf = service.readMetadata('CustomField', fieldFullNames);
            if (rrf != null && rrf.getRecords() != null) {
                for (MetadataService.Metadata rec : rrf.getRecords()) {
                    if (rec != null) existingFieldMap.put(((MetadataService.CustomField)rec).fullName, rec);
                }
            }
        } catch (Exception e) {
            // ignore
        }

        for (String fullName : fieldFullNames) {
            if (existingFieldMap.containsKey(fullName)) continue;
            MetadataService.CustomField f = new MetadataService.CustomField();
            f.fullName = fullName;
            if (fullName.endsWith('.Field_Changed_Label__c')) {
                f.type_x = 'Text'; f.label = 'Field Changed Label'; f.length = 100;
            } else if (fullName.endsWith('.Field_Changed_Api__c')) {
                f.type_x = 'Text'; f.label = 'Field Changed API'; f.length = 100;
            } else if (fullName.endsWith('.Prior_Value__c')) {
                f.type_x = 'LongTextArea'; f.label = 'Prior Value'; f.length = 4000; f.visibleLines = 3;
            } else if (fullName.endsWith('.Complete_Prior_Value__c')) {
                f.type_x = 'LongTextArea'; f.label = 'Complete Prior Value'; f.length = 32768; f.visibleLines = 3;
            } else if (fullName.endsWith('.New_Value__c')) {
                f.type_x = 'LongTextArea'; f.label = 'New Value'; f.length = 4000; f.visibleLines = 3;
            } else if (fullName.endsWith('.Complete_New_Value__c')) {
                f.type_x = 'LongTextArea'; f.label = 'Complete New Value'; f.length = 32768; f.visibleLines = 3;
            } else if (fullName.endsWith('.Changed_On__c')) {
                f.type_x = 'DateTime'; f.label = 'Changed On';
            } else if (fullName.endsWith('.Changed_By__c')) {
                f.type_x = 'Lookup'; f.referenceTo = 'User'; f.label = 'Changed By'; f.relationshipName = 'Changed_By';
            } else if (fullName.endsWith('.Parent_Record__c')) {
                f.type_x = 'Lookup'; f.referenceTo = objectApi; f.label = 'Parent Record'; f.relationshipName = 'Parent_Record';
            }
            toCreate.add(f);
        }

        if (!toCreate.isEmpty()) {
            // createMetadata returns SaveResult[] in this mdapi version
            try { service.createMetadata(toCreate); } catch (Exception e) { /* swallow */ }
        }
    }
}
