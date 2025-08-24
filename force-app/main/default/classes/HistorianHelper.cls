public with sharing class HistorianHelper {
    public class Inputs {
        @InvocableVariable(required=true)
        public Id TargetRecordId;

        @InvocableVariable
        public String TargetSObjectApiName;

        @InvocableVariable
        public String ConfigName;

        // Optional: Flow can pass JSON of old/new values (e.g., from $Record__Prior and $Record)
        @InvocableVariable
        public String OldValuesJson;

        @InvocableVariable
        public String NewValuesJson;
    }

    public class Outputs {
        @InvocableVariable
        public Integer createdRows;

        @InvocableVariable
        public String configUsed;

        @InvocableVariable
        public String trackScope; // AllFields or PerField
    }

    @InvocableMethod(label='Historian: Track Changes' description='Creates Historian rows for changes based on selected configuration.')
    public static List<Outputs> run(List<Inputs> batched) {
        List<Outputs> results = new List<Outputs>();
        for (Inputs input : batched) {
            Outputs out = new Outputs();
            try {
                String sobjectApi = input.TargetSObjectApiName;
                if (sobjectApi == null && input.TargetRecordId != null) {
                    sobjectApi = input.TargetRecordId.getSObjectType().getDescribe().getName();
                }
                HistorianConfigService.ConfigSummary cfg = HistorianConfigService.getActiveConfig(sobjectApi, input.ConfigName);
                out.configUsed = cfg != null ? cfg.configName : null;
                out.trackScope = cfg != null ? (cfg.allFields ? 'AllFields' : 'PerField') : null;
                Map<String, Object> oldVals;
                Map<String, Object> newVals;
                if (input.OldValuesJson != null) oldVals = (Map<String, Object>) JSON.deserializeUntyped(input.OldValuesJson);
                if (input.NewValuesJson != null) newVals = (Map<String, Object>) JSON.deserializeUntyped(input.NewValuesJson);
                Integer created = HistorianChangeService.applyChanges(input.TargetRecordId, cfg, oldVals, newVals);
                out.createdRows = created;
            } catch (Exception e) {
                out.createdRows = 0;
                out.configUsed = input.ConfigName;
                out.trackScope = 'Error: ' + e.getMessage();
            }
            results.add(out);
        }
        return results;
    }
}
