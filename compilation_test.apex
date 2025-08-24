// Quick compilation test for the fixed classes
public class CompilationTest {
    public static void testHistorianHelper() {
        // Test that HistorianHelper compiles
        HistorianHelper.HistorianRequest request = new HistorianHelper.HistorianRequest();
        request.targetRecordId = 'test';
        request.targetSObjectApiName = 'Account';
        
        List<HistorianHelper.HistorianResult> results = HistorianHelper.captureHistoricalChanges(
            new List<HistorianHelper.HistorianRequest>{request}
        );
        
        System.debug('Results: ' + results.size());
    }
    
    public static void testMetadataJob() {
        // Test that HistorianMetadataJob compiles
        HistorianConfigService.ConfigSummary cfg = new HistorianConfigService.ConfigSummary();
        cfg.objectApi = 'Account';
        cfg.configName = 'test';
        
        HistorianMetadataJob job = new HistorianMetadataJob('Account', cfg);
        // We won't execute it, just test compilation
        System.debug('Job created: ' + job);
    }
    
    public static void testConfigService() {
        // Test that HistorianConfigService methods compile
        List<HistorianConfigService.ConfigSummary> configs = HistorianConfigService.listActiveConfigs('Account');
        System.debug('Config count: ' + configs.size());
        
        HistorianConfigService.ConfigSummary config = HistorianConfigService.getActiveConfig('Account', 'test');
        System.debug('Got config: ' + config);
    }
}