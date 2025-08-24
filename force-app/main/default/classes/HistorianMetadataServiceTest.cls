@IsTest
private class HistorianMetadataServiceTest {
    @IsTest
    static void testEnqueueJob() {
        Test.startTest();
        Id jobId = HistorianMetadataService.ensureHistorianObjectAsync('Account', null);
        Test.stopTest();
        System.assertNotEquals(null, jobId, 'Queueable job id should be returned');
    }
}

