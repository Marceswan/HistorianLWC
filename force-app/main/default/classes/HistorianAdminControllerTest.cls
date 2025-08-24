@IsTest
private class HistorianAdminControllerTest {
    @IsTest
    static void testStartEnsureHistorianObject() {
        Test.startTest();
        String jobId = HistorianAdminController.startEnsureHistorianObject('Account', null);
        Test.stopTest();
        System.assertNotEquals(null, jobId);
    }
}

