@IsTest
private class HistorianConfigServiceTest {
    @IsTest
    static void testDefaultConfigWhenNoCmdt() {
        List<HistorianConfigService.ConfigSummary> configList = HistorianConfigService.listActiveConfigs('Account');
        System.assertEquals(0, configList.size(), 'No CMDT present yet');
        HistorianConfigService.ConfigSummary cfg = HistorianConfigService.getActiveConfig('Account', null);
        System.assertNotEquals(null, cfg);
        System.assertEquals(true, cfg.allFields);
        System.assertEquals('Account', cfg.objectApi);
    }
}

