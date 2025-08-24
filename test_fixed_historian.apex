System.debug('=== Testing fixed historian object creation ===');
String objectApiName = 'Opportunity';
HistorianConfigService.ConfigSummary cfg = new HistorianConfigService.ConfigSummary();
cfg.objectApi = objectApiName;
cfg.configName = 'fixed_test';
Id jobId = System.enqueueJob(new HistorianMetadataJob(objectApiName, cfg));
System.debug('Fixed historian job enqueued with ID: ' + jobId);