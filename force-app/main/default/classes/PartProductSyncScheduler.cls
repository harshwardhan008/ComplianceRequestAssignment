/*********************************************************************************
** Class: PartProductSyncScheduler
** Version:     1.0
** Created By:  Harshwardhan Singh Karki
** Created On:  10 July 2025
** Description : Schedulable class to run the PartToProductSyncBatch every morning.
** Developer :   Harshwardhan Singh Karki
*********************************************************************************/
public class PartProductSyncScheduler implements Schedulable {

    /**
     * Purpose: Executes the PartToProductSyncBatch.
     * @param sc SchedulableContext - the schedulable context
     * @return void
     */
    public void execute(SchedulableContext sc) {
        PartToProductSyncBatch batch = new PartToProductSyncBatch();
        Database.executeBatch(batch,100);
    }
}