@IsTest
private class HistorianHelperTest {
    @IsTest
    static void testHelperParsesJsonAndReturnsCounts() {
        Account a = new Account(Name = 'Old');
        insert a;

        Map<String, Object> oldVals = new Map<String, Object>{ 'Name' => 'Old' };
        Map<String, Object> newVals = new Map<String, Object>{ 'Name' => 'New' };
        HistorianHelper.Inputs inp = new HistorianHelper.Inputs();
        inp.TargetRecordId = a.Id;
        inp.TargetSObjectApiName = 'Account';
        inp.ConfigName = 'Default';
        inp.OldValuesJson = JSON.serialize(oldVals);
        inp.NewValuesJson = JSON.serialize(newVals);

        List<HistorianHelper.Outputs> outs = HistorianHelper.run(new List<HistorianHelper.Inputs>{ inp });
        System.assertEquals(1, outs.size());
        System.assertEquals('Default', outs[0].configUsed);
        System.assertEquals('AllFields', outs[0].trackScope);
        System.assertEquals(1, outs[0].createdRows);
    }
}

