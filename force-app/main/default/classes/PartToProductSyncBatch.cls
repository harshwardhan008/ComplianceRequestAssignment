/*********************************************************************************
** Class: Batch Class For Part to Product Synchronization
** Version:     1.0
** Created By:  Harshwardhan Singh Karki
** Created On:  8 July 2025
** Description : Asynchronously processes active custom Part records, creating new standard Product records or associating existing ones if the Product lookup on the Part is empty
** Developer :   Harshwardhan Singh Karki
*********************************************************************************/
public with sharing class PartToProductSyncBatch implements Database.Batchable<SObject>, Database.Stateful {

    private Integer productsCreated = 0; // Tracks the number of products created
    private Integer partsUpdated = 0; // Tracks the number of parts updated
    private List<String> errors = new List<String>(); // Stores error messages encountered during processing

    /**
     * Purpose: Returns the QueryLocator for batch processing of active Parts with no Product linked.
     * @param bc Database.BatchableContext - the batch context
     * @return Database.QueryLocator - query for active Parts with no Product linked
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator('SELECT Id, Name, SQX_Part_Number__c FROM SQX_Part__c WHERE SQX_Active__c = TRUE AND SQX_Product__c = NULL WITH USER_MODE');
    }

    /**
     * Purpose: Processes each batch of Part records, creates Products if needed, and links Parts to Products.
     * @param bc Database.BatchableContext - the batch context
     * @param scope List<SObject> - the current batch of SQX_Part__c records to process
     * @return void
     */
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        try{
            List<SQX_Part__c> partsList = (List<SQX_Part__c>) scope; // List of Parts to process in this batch
            List<SQX_Part__c> partsToUpdate = new List<SQX_Part__c>(); // Parts that need to be updated with Product
            List<Product2> productsToInsert = new List<Product2>(); // Products to be inserted for Parts with no existing Product
            Map<String, SQX_Part__c> newProductMap = new Map<String, SQX_Part__c>(); // Maps Part Number to Part for linking after Product insert
            Set<String> partNumbers = new Set<String>(); // Set of unique Part Numbers in this batch

            // Collect all Part Numbers from the batch
            for (SQX_Part__c part : partsList) {
                if (String.isNotBlank(part.SQX_Part_Number__c)) {
                    partNumbers.add(part.SQX_Part_Number__c);
                }
            }

            // Query existing Products that match any Part Number in this batch
            Map<String, Product2> existingProducts = new Map<String, Product2>(); // Maps ProductCode to Product2
            if (!partNumbers.isEmpty()) {
                for (Product2 prod : [SELECT Id, ProductCode FROM Product2 WHERE ProductCode IN :partNumbers WITH USER_MODE]) {
                    existingProducts.put(prod.ProductCode, prod);
                }
            }

            // For each Part, either link to existing Product or prepare to create a new Product
            for (SQX_Part__c part : partsList) {
                String partNumber = part.SQX_Part_Number__c;

                if (String.isBlank(partNumber)) {
                    errors.add('Skipped Part ' + part.Id + ' - missing Part Number.');
                    continue;
                }

                if (existingProducts.containsKey(partNumber)) {
                    part.SQX_Product__c = existingProducts.get(partNumber).Id;
                    partsToUpdate.add(part);
                    partsUpdated++;
                } else {
                    Product2 newProduct = new Product2(
                        Name = part.Name,
                        ProductCode = partNumber,
                        IsActive = true
                    );
                    productsToInsert.add(newProduct);
                    newProductMap.put(partNumber, part);
                }
            }

            // Insert new Products and link them to their Parts
            if (!productsToInsert.isEmpty()) {
                Database.SaveResult[] insertResults = Database.insert(productsToInsert, false, AccessLevel.USER_MODE);
                for (Integer i = 0; i < insertResults.size(); i++) {
                    if (insertResults[i].isSuccess()) {
                        Product2 insertedProd = productsToInsert[i];
                        SQX_Part__c relatedPart = newProductMap.get(insertedProd.ProductCode);
                        if (relatedPart != null) {
                            relatedPart.SQX_Product__c = insertedProd.Id;
                            partsToUpdate.add(relatedPart);
                            partsUpdated++;
                            productsCreated++;
                        }
                    } else {
                        errors.add('Failed to insert Product for PartNumber ' + productsToInsert[i].ProductCode + ': ' + insertResults[i].getErrors()[0].getMessage());
                    }
                }
            }

            // Update Parts with their linked Product Ids
            if (!partsToUpdate.isEmpty()) {
                Database.SaveResult[] updateResults = Database.update(partsToUpdate, false, AccessLevel.USER_MODE);
                for (Integer i = 0; i < updateResults.size(); i++) {
                    if (!updateResults[i].isSuccess()) {
                        errors.add('Failed to update Part ' + partsToUpdate[i].Id + ': ' + updateResults[i].getErrors()[0].getMessage());
                    }
                }
            }
        }catch(Exception e) {
            errors.add('An unexpected error occurred in batch: ' + e.getMessage() + ' at line ' + e.getLineNumber());
            System.debug('Unexpected error in PartToProductSyncBatch.execute: ' + e.getMessage() + ' at line ' + e.getLineNumber());
        }
    }

    /**
     * Purpose: Sends a summary email to the batch job creator after batch completion, including errors and counts.
     * @param bc Database.BatchableContext - the batch context
     * @return void
     */
    public void finish(Database.BatchableContext bc) {
        AsyncApexJob job = [SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems, CreatedBy.Email
                            FROM AsyncApexJob WHERE Id = :bc.getJobId()];

        String body = 'Part-Product Sync Completed\n\n' +
                      'Status: ' + job.Status + '\n' +
                      'Parts Updated: ' + partsUpdated + '\n' +
                      'Products Created: ' + productsCreated + '\n' +
                      'Errors: ' + (errors.isEmpty() ? 'None' : '') + '\n\n'; 
        if (!errors.isEmpty()) {
            for (String err : errors) {
                body += '- ' + err + '\n';
            }
        }

        try {
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new String[]{job.CreatedBy.Email});
            email.setSubject('Part-Product Sync Job Result');
            email.setPlainTextBody(body);
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
        } catch (Exception e) {
            System.debug('Email failed: ' + e.getMessage());
        }
    }
}