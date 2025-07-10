/*********************************************************************************
** Class:  Test Class For PartProductSyncScheduler
** Version:     1.0
** Created By:  Harshwardhan Singh Karki
** Created On:  10 July 2025
** Developer :   Harshwardhan Singh Karki
*********************************************************************************/
@IsTest
private class Test_PartProductSyncScheduler{

    @TestSetup
    static void setupTestData() {
        List<SQX_Part__c> partsToInsert = new List<SQX_Part__c>();
        partsToInsert.add(new SQX_Part__c(
            Name = 'Test Part For Scheduler',
            SQX_Part_Number__c = 'SCHED001',
            SQX_Active__c = true,
            SQX_Product__c = null
        ));
        partsToInsert.add(new SQX_Part__c(
            Name = 'Another Part For Scheduler',
            SQX_Part_Number__c = 'SCHED002',
            SQX_Active__c = true,
            SQX_Product__c = null
        ));
        insert partsToInsert;
    }

    @IsTest
    static void testSchedulerExecutesBatchDirectly() {
        Test.startTest();
        PartProductSyncScheduler scheduler = new PartProductSyncScheduler();
        SchedulableContext sc = null;
        scheduler.execute(sc);
        Test.stopTest();
        List<Product2> createdProducts = [SELECT Id, ProductCode FROM Product2 WHERE ProductCode IN ('SCHED001', 'SCHED002')];
        System.assertEquals(2, createdProducts.size(), 'Two new Products should have been created by the batch.');
        List<SQX_Part__c> updatedParts = [SELECT Id, SQX_Product__c FROM SQX_Part__c WHERE SQX_Part_Number__c IN ('SCHED001', 'SCHED002') AND SQX_Product__c != NULL];
        System.assertEquals(2, updatedParts.size(), 'Two Parts should have been updated with Product links.');
    }
}