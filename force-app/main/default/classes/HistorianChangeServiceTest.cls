@IsTest
private class HistorianChangeServiceTest {
    @IsTest
    static void testApplyChangesCountsWhenNoHistorianObject() {
        Account a = new Account(Name = 'Old Name');
        insert a;

        Map<String, Object> oldVals = new Map<String, Object>{ 'Name' => 'Old Name' };
        Map<String, Object> newVals = new Map<String, Object>{ 'Name' => 'New Name' };
        HistorianConfigService.ConfigSummary cfg = new HistorianConfigService.ConfigSummary();
        cfg.configName = 'Default';
        cfg.objectApi = 'Account';
        cfg.allFields = true;
        cfg.fieldApis = new List<String>();

        Integer count = HistorianChangeService.applyChanges(a.Id, cfg, oldVals, newVals);
        System.assertEquals(1, count, 'Should count one change even if historian object not provisioned');
    }

    @IsTest
    static void testPerFieldFilterRespected() {
        Account a = new Account(Name = 'X', Industry = 'A');
        insert a;
        Map<String, Object> oldVals = new Map<String, Object>{ 'Name' => 'X', 'Industry' => 'A' };
        Map<String, Object> newVals = new Map<String, Object>{ 'Name' => 'Y', 'Industry' => 'B' };
        HistorianConfigService.ConfigSummary cfg = new HistorianConfigService.ConfigSummary();
        cfg.configName = 'PF';
        cfg.objectApi = 'Account';
        cfg.allFields = false;
        cfg.fieldApis = new List<String>{ 'Name' };

        Integer count = HistorianChangeService.applyChanges(a.Id, cfg, oldVals, newVals);
        System.assertEquals(1, count, 'Only Name should be counted');
    }
}
