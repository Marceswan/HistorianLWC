@IsTest
private class HistorianConfigServiceWithCmdtTest {
    @IsTest
    static void testListActiveConfigsReturnsEmpty() {
        // Test that the method returns empty list when no CMDT records exist
        List<HistorianConfigService.ConfigSummary> configList = HistorianConfigService.listActiveConfigs('Account');
        System.assertEquals(0, configList.size(), 'Should return empty list when no CMDT exists');
    }

    @IsTest
    static void testGetActiveConfigReturnsDefault() {
        // Test that getActiveConfig returns a default config when no CMDT exists
        HistorianConfigService.ConfigSummary cfg = HistorianConfigService.getActiveConfig('Account', null);
        System.assertNotEquals(null, cfg, 'Should return default config');
        System.assertEquals(true, cfg.allFields, 'Default config should track all fields');
        System.assertEquals('Account', cfg.objectApi, 'Should match requested object API');
    }
}

