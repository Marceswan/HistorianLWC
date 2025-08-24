public with sharing class HistorianMetadataService {
    public static Id ensureHistorianObjectAsync(String objectApi, HistorianConfigService.ConfigSummary cfg) {
        return System.enqueueJob(new HistorianMetadataJob(objectApi, cfg));
    }

    // Placeholder for potential synchronous use in admin flows; prefer async.
    public static void ensureHistorianObject(String objectApi, HistorianConfigService.ConfigSummary cfg) {
        new HistorianMetadataJob(objectApi, cfg).execute(null);
    }
}

