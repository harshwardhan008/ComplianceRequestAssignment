/*********************************************************************************
** Class:      Test Class for PartToProductSyncBatch Class
** Version:     1.0
** Created By:  Harshwardhan Singh Karki
** Created On:  8 July 2025
** Developer :   Harshwardhan Singh Karki
*********************************************************************************/
@isTest
public class Test_PartToProductSyncBatch {

    @testSetup
    static void setup() {
        Product2 existingProd = new Product2(Name = 'Existing Product', ProductCode = 'EXIST123', IsActive = true);
        insert existingProd;
        SQX_Part__c partWithProduct = new SQX_Part__c(
            Name = 'Part With Product',
            SQX_Part_Number__c = 'EXIST123',
            SQX_Active__c = true,
            SQX_Product__c = existingProd.Id
        );
        insert partWithProduct;
    }

    /**
     * Purpose: Tests that a new Product is created and linked to a Part when an active Part with no Product exists.
     * Verifies the Product and Part linkage, and checks the batch summary email for correct counts.
     */
    @isTest
    static void testInsertScenario() {
        SQX_Part__c partWithoutProduct = new SQX_Part__c(
            Name = 'Part Without Product',
            SQX_Part_Number__c = 'NEW123',
            SQX_Active__c = true,
            SQX_Product__c = null
        );
        insert partWithoutProduct;

        Test.startTest();
        PartToProductSyncBatch batch = new PartToProductSyncBatch();
        Database.executeBatch(batch, 1);
        Test.stopTest();

        Product2 createdProduct = [SELECT Id, ProductCode, Name FROM Product2 WHERE ProductCode = 'NEW123' LIMIT 1];
        System.assertNotEquals(null, createdProduct, 'Product should be created for NEW123');
        System.assertEquals('NEW123', createdProduct.ProductCode, 'ProductCode should match Part Number');
        System.assertEquals('Part Without Product', createdProduct.Name, 'Product Name should match Part Name');

        SQX_Part__c updatedPart = [SELECT Id, SQX_Product__c FROM SQX_Part__c WHERE SQX_Part_Number__c = 'NEW123' LIMIT 1];
        System.assertNotEquals(null, updatedPart.SQX_Product__c, 'Part should be linked to a Product');
        System.assertEquals(createdProduct.Id, updatedPart.SQX_Product__c, 'Part should be linked to the newly created Product');

        List<EmailMessage> sentEmails = [SELECT Id, Subject, TextBody FROM EmailMessage WHERE Subject = 'Part-Product Sync Job Result'];
        System.assertEquals(1, sentEmails.size(), 'An email should have been sent upon batch completion.');
        System.assert(sentEmails[0].TextBody.contains('Products Created: 1'), 'Email should report 1 product created.');
        System.assert(sentEmails[0].TextBody.contains('Parts Updated: 1'), 'Email should report 1 part updated.');
    }

    /**
     * Purpose: Tests that a Part already linked to an existing Product is not updated or processed again.
     * Verifies no new Product is created and batch summary email reports zero updates/creations.
     */
    @isTest
    static void testExistingProductScenario() {
        Test.startTest();
        PartToProductSyncBatch batch = new PartToProductSyncBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        SQX_Part__c partWithExistingProduct = [SELECT Id, SQX_Product__c FROM SQX_Part__c WHERE SQX_Part_Number__c = 'EXIST123' LIMIT 1];
        Product2 existingProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'EXIST123' LIMIT 1];

        System.assertNotEquals(null, partWithExistingProduct.SQX_Product__c, 'Part with existing product should still be linked.');
        System.assertEquals(existingProduct.Id, partWithExistingProduct.SQX_Product__c, 'Part should remain linked to the original existing Product.');

        List<EmailMessage> sentEmails = [SELECT Id, Subject, TextBody FROM EmailMessage WHERE Subject = 'Part-Product Sync Job Result'];
        System.assertEquals(1, sentEmails.size(), 'An email should have been sent upon batch completion.');
        System.assert(sentEmails[0].TextBody.contains('Products Created: 0'), 'Email should report 0 products created.');
        System.assert(sentEmails[0].TextBody.contains('Parts Updated: 0'), 'Email should report 0 parts updated.');
    }

    /**
     * Purpose: Tests that a Part with a Part Number matching an existing Product gets linked to that Product.
     * Verifies no duplicate Product is created and batch summary email reports correct update count.
     */
    @isTest
    static void testLinkToExistingProductScenario() {
        Product2 preExistingProduct = new Product2(Name = 'Pre-Existing Product', ProductCode = 'PREEXIST456', IsActive = true);
        insert preExistingProduct;

        SQX_Part__c partToLink = new SQX_Part__c(
            Name = 'Part To Link To Existing',
            SQX_Part_Number__c = 'PREEXIST456',
            SQX_Active__c = true,
            SQX_Product__c = null
        );
        insert partToLink;

        Test.startTest();
        PartToProductSyncBatch batch = new PartToProductSyncBatch();
        Database.executeBatch(batch, 1);
        Test.stopTest();

        SQX_Part__c updatedPart = [SELECT Id, SQX_Product__c FROM SQX_Part__c WHERE Id = :partToLink.Id LIMIT 1];
        System.assertNotEquals(null, updatedPart.SQX_Product__c, 'Part should be linked to an existing Product.');
        System.assertEquals(preExistingProduct.Id, updatedPart.SQX_Product__c, 'Part should be linked to the correctly pre-existing Product.');

        List<Product2> newProducts = [SELECT Id FROM Product2 WHERE ProductCode = 'PREEXIST456' AND Id != :preExistingProduct.Id];
        System.assertEquals(0, newProducts.size(), 'No new Product should be created when one already exists for the Part Number.');

        // Assert on the email results
        List<EmailMessage> sentEmails = [SELECT Id, Subject, TextBody FROM EmailMessage WHERE Subject = 'Part-Product Sync Job Result'];
        System.assertEquals(1, sentEmails.size(), 'An email should have been sent upon batch completion.');
        System.assert(sentEmails[0].TextBody.contains('Products Created: 0'), 'Email should report 0 products created.');
        System.assert(sentEmails[0].TextBody.contains('Parts Updated: 1'), 'Email should report 1 part updated.');
    }


    /**
     * Purpose: Tests bulk processing by inserting 150 Parts and ensuring all are processed and linked to Products.
     * Verifies all Parts are linked, Products are created, and batch summary email reports correct counts.
     */
    @isTest
    static void testBulkScenario() {
        List<SQX_Part__c> partsToInsert = new List<SQX_Part__c>();
        for (Integer i = 1; i <= 150; i++) {
            partsToInsert.add(new SQX_Part__c(
                Name = 'Bulk Part ' + i,
                SQX_Part_Number__c = 'BULK' + i,
                SQX_Active__c = true,
                SQX_Product__c = null
            ));
        }
        insert partsToInsert;

        Test.startTest();
        PartToProductSyncBatch batch = new PartToProductSyncBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        List<SQX_Part__c> bulkPartsProcessed = [SELECT Id, SQX_Part_Number__c, SQX_Product__c FROM SQX_Part__c WHERE Name LIKE 'Bulk Part%' AND SQX_Product__c != NULL];
        System.assertEquals(150, bulkPartsProcessed.size(), 'All 150 bulk parts should have been processed and linked.');

        Set<Id> productIds = new Set<Id>();
        for (SQX_Part__c part : bulkPartsProcessed) {
            productIds.add(part.SQX_Product__c);
        }

        Map<Id, Product2> linkedProductsMap = new Map<Id, Product2>(
            [SELECT Id, ProductCode FROM Product2 WHERE Id IN :productIds]
        );

        for(SQX_Part__c part : bulkPartsProcessed) {
            System.assertNotEquals(null, part.SQX_Product__c, 'Bulk part ' + part.SQX_Part_Number__c + ' should be linked to a Product.');

            Product2 linkedProd = linkedProductsMap.get(part.SQX_Product__c);
            System.assertNotEquals(null, linkedProd, 'Linked Product should be found in map for Part ' + part.SQX_Part_Number__c);
            System.assertEquals(part.SQX_Part_Number__c, linkedProd.ProductCode, 'Linked ProductCode should match Part Number for ' + part.SQX_Part_Number__c);
        }

        List<EmailMessage> sentEmails = [SELECT Id, Subject, TextBody FROM EmailMessage WHERE Subject = 'Part-Product Sync Job Result'];
        System.assertEquals(1, sentEmails.size(), 'An email should have been sent upon batch completion.');
        System.assert(sentEmails[0].TextBody.contains('Products Created: 150'), 'Email should report 150 products created.');
        System.assert(sentEmails[0].TextBody.contains('Parts Updated: 150'), 'Email should report 150 parts updated.');
    }

    /**
     * Purpose: Tests failing and skipped scenarios, including inactive Parts and Parts missing Part Numbers.
     * Verifies these Parts are not updated, errors are reported, and batch summary email contains error details.
     */
    @isTest
    static void testFailingAndSkippedScenarios() {
        SQX_Part__c inactivePart = new SQX_Part__c(
            Name = 'Inactive Part',
            SQX_Part_Number__c = 'INACTIVE123',
            SQX_Active__c = false,
            SQX_Product__c = null
        );

        SQX_Part__c missingNumberPart = new SQX_Part__c(
            Name = 'Missing Number Part',
            SQX_Part_Number__c = null,
            SQX_Active__c = true,
            SQX_Product__c = null
        );
        insert new List<SQX_Part__c>{inactivePart, missingNumberPart};

        Test.startTest();
        PartToProductSyncBatch batch = new PartToProductSyncBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        SQX_Part__c inactivePartCheck = [SELECT Id, SQX_Product__c FROM SQX_Part__c WHERE SQX_Part_Number__c = 'INACTIVE123' LIMIT 1];
        System.assertEquals(null, inactivePartCheck.SQX_Product__c, 'Inactive part should not have been updated with a Product link.');

        SQX_Part__c missingNumberCheck = [SELECT Id, SQX_Product__c FROM SQX_Part__c WHERE Name = 'Missing Number Part' LIMIT 1];
        System.assertEquals(null, missingNumberCheck.SQX_Product__c, 'Part with missing Part Number should not have been updated.');

        // Assert on the email sent by finish method to check for errors
        List<EmailMessage> sentEmails = [SELECT Id, Subject, TextBody FROM EmailMessage WHERE Subject = 'Part-Product Sync Job Result'];
        System.assertEquals(1, sentEmails.size(), 'An email should have been sent upon batch completion.');
        System.assert(sentEmails[0].TextBody.contains('Errors: '), 'Email body should contain error information.');
        System.assert(sentEmails[0].TextBody.contains('Skipped Part ' + missingNumberCheck.Id + ' - missing Part Number.'), 'Email body should contain error for skipped part due to missing number.');
        System.assert(sentEmails[0].TextBody.contains('Products Created: 0'), 'Email should report 0 products created.');
        System.assert(sentEmails[0].TextBody.contains('Parts Updated: 0'), 'Email should report 0 parts updated.');
    }
}