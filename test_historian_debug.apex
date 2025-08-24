System.debug('=== Testing enhanced historian object creation ===');
String objectApiName = 'Opportunity';
HistorianConfigService.ConfigSummary cfg = new HistorianConfigService.ConfigSummary();
cfg.objectApi = objectApiName;
cfg.configName = 'debug_test';
Id jobId = System.enqueueJob(new HistorianMetadataJob(objectApiName, cfg));
System.debug('Enhanced debug job enqueued with ID: ' + jobId);