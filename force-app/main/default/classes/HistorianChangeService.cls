public with sharing class HistorianChangeService {
    public static Integer applyChanges(Id recordId, HistorianConfigService.ConfigSummary cfg, Map<String, Object> oldVals, Map<String, Object> newVals) {
        if (recordId == null || cfg == null) return 0;

        String objectApi = recordId.getSObjectType().getDescribe().getName();
        Set<String> tracked = new Set<String>();
        if (cfg.allFields == true) {
            // Track all updatable fields
            Schema.DescribeSObjectResult d = recordId.getSObjectType().getDescribe();
            for (Schema.SObjectField f : d.fields.getMap().values()) {
                Schema.DescribeFieldResult fr = f.getDescribe();
                if (fr.isUpdateable()) tracked.add(fr.getName());
            }
        } else if (cfg.fieldApis != null) {
            tracked.addAll(cfg.fieldApis);
        }

        Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(objectApi).getDescribe().fields.getMap();
        Set<String> candidates = new Set<String>();
        if (oldVals != null) candidates.addAll(oldVals.keySet());
        if (newVals != null) candidates.addAll(newVals.keySet());
        if (!tracked.isEmpty()) candidates.retainAll(tracked);

        String historianApi = objectApi + '_Historian__c';
        Schema.SObjectType histType = Schema.getGlobalDescribe().get(historianApi);

        List<SObject> rows = new List<SObject>();
        for (String api : candidates) {
            try {
                Schema.DescribeFieldResult fr = fieldMap.containsKey(api) ? fieldMap.get(api).getDescribe() : null;
                String oldStr = stringify(oldVals != null ? oldVals.get(api) : null);
                String newStr = stringify(newVals != null ? newVals.get(api) : null);
                if (equalsSafe(oldStr, newStr)) continue; // no change

                if (histType == null) {
                    // Object not provisioned; count change without DML
                    rows.add((SObject) null);
                    continue;
                }
                SObject row = histType.newSObject();
                row.put('Parent_Record__c', recordId);
                row.put('Changed_On__c', System.now());
                row.put('Changed_By__c', UserInfo.getUserId());
                row.put('Field_Changed_Api__c', api);
                row.put('Field_Changed_Label__c', fr != null ? fr.getLabel() : api);

                // Short fields (4k) store truncated; complete fields store full
                row.put('Prior_Value__c', truncateForShort(oldStr));
                row.put('New_Value__c', truncateForShort(newStr));
                row.put('Complete_Prior_Value__c', oldStr);
                row.put('Complete_New_Value__c', newStr);
                rows.add(row);
            } catch (Exception e) {
                // continue best-effort
            }
        }
        if (histType == null) {
            return rows.size();
        }
        if (!rows.isEmpty()) {
            try { insert rows; } catch (DmlException dmle) { /* swallow to avoid breaking flow */ }
        }
        return rows.size();
    }

    private static String stringify(Object v) {
        if (v == null) return null;
        if (v instanceof String) return (String) v;
        if (v instanceof Boolean) return String.valueOf((Boolean) v);
        if (v instanceof Integer) return String.valueOf((Integer) v);
        if (v instanceof Long) return String.valueOf((Long) v);
        if (v instanceof Decimal) return String.valueOf((Decimal) v);
        if (v instanceof Double) return String.valueOf((Double) v);
        if (v instanceof Date) return ((Date) v).format();
        if (v instanceof Datetime) return ((Datetime) v).formatGmt('yyyy-MM-dd HH:mm:ss');
        if (v instanceof Time) return String.valueOf((Time) v);
        return JSON.serialize(v);
    }

    private static String truncateForShort(String s) {
        if (s == null) return null;
        Integer max = 4000; // LTA short fields set to ~4k
        return s.length() > max ? s.substring(0, max) : s;
    }

    private static Boolean equalsSafe(String a, String b) {
        return (a == null && b == null) || (a != null && a.equals(b));
    }
}
