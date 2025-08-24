trigger OpportunityHistorianTrigger on Opportunity (after update) {
    // Auto-generated lightweight historian trigger - Updated: 2024-08-24 14:25:00
    HistorianTriggerHandler.handleAfterUpdate('Opportunity', Trigger.old, Trigger.new);
}