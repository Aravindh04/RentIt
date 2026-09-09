@IsTest(SeeAllData=false)
private class InvoiceBatchTest {

    @TestSetup
    static void setup() {
        Account landlord = new Account(Name = 'Batch Test Landlord');
        insert landlord;

        Property__c propertyRecord = new Property__c(
            Property_Type__c = 'House',
            Landlord__c = landlord.Id
        );
        insert propertyRecord;

        Account tenantAccount = new Account(Name = 'Batch Test Tenant Account');
        insert tenantAccount;

        Contact tenantContact = new Contact(
            FirstName = 'Batch',
            LastName = 'Tenant',
            Email = 'batch.tenant@rentit.test',
            AccountId = tenantAccount.Id
        );
        insert tenantContact;

        Tenancy__c tenancyRecord = new Tenancy__c(
            Property__c = propertyRecord.Id,
            Tenant__c = tenantContact.Id,
            Status__c = 'Active'
        );
        insert tenancyRecord;
    }

    @IsTest
    static void givenActivatedContract_whenInvoiceBatchRuns_thenInvoiceAndPaymentAreCreated() {
        Tenancy__c tenancyRecord = [SELECT Id FROM Tenancy__c LIMIT 1];

        insert new Payment__c(
            Tenancy__c = tenancyRecord.Id,
            Amount__c = 1000,
            Payment_Date__c = Date.today(),
            Payment_Method__c = 'Bank Transfer',
            Payment_Type__c = 'Rent Payment',
            Status__c = 'Received'
        );

        Contract contractRecord = createContract(tenancyRecord.Id, Date.today().addDays(-6));
        insert contractRecord;
        contractRecord.Status = 'Activated';
        update contractRecord;

        Test.startTest();
        Database.executeBatch(new InvoiceBatch(), 1);
        Test.stopTest();

        List<Invoice__c> invoices = [
            SELECT Id, Status__c, Total_Paid__c
            FROM Invoice__c
            WHERE Tenancy__c = :tenancyRecord.Id
        ];

        Assert.areEqual(1, invoices.size(), 'InvoiceBatch should create one invoice for the lookahead period.');
        Assert.areEqual('Paid', invoices[0].Status__c, 'The generated invoice should be marked paid.');
        Assert.areEqual(1000, invoices[0].Total_Paid__c, 'The generated invoice should be fully paid.');
        Assert.areEqual(
            1,
            [SELECT COUNT() FROM Payment__c WHERE Invoice__c = :invoices[0].Id AND Payment_Type__c = 'Credit Applied'],
            'InvoiceBatch should create one credit applied payment.'
        );
    }

    @IsTest
    static void givenActivatedContract_whenInvoiceBackfillBatchRuns_thenInvoicesAndPaymentsAreCreated() {
        Tenancy__c tenancyRecord = [SELECT Id FROM Tenancy__c LIMIT 1];

        insert new Payment__c(
            Tenancy__c = tenancyRecord.Id,
            Amount__c = 3000,
            Payment_Date__c = Date.today(),
            Payment_Method__c = 'Bank Transfer',
            Payment_Type__c = 'Rent Payment',
            Status__c = 'Received'
        );

        Contract contractRecord = createContract(tenancyRecord.Id, Date.today().addDays(-14));
        insert contractRecord;
        contractRecord.Status = 'Activated';
        update contractRecord;

        Test.startTest();
        Database.executeBatch(new InvoiceBackfillBatch(), 1);
        Test.stopTest();

        List<Invoice__c> invoices = [
            SELECT Id, Status__c, Total_Paid__c
            FROM Invoice__c
            WHERE Tenancy__c = :tenancyRecord.Id
            ORDER BY Period_Start__c
        ];

        Assert.areEqual(3, invoices.size(), 'Backfill should create the missing invoice history.');
        for (Invoice__c invoiceRecord : invoices) {
            Assert.areEqual('Paid', invoiceRecord.Status__c, 'Backfilled invoices should be marked paid.');
            Assert.areEqual(1000, invoiceRecord.Total_Paid__c, 'Each backfilled invoice should be fully paid.');
        }
        Assert.areEqual(
            3,
            [SELECT COUNT() FROM Payment__c WHERE Invoice__c IN :new Map<Id, Invoice__c>(invoices).keySet() AND Payment_Type__c = 'Credit Applied'],
            'Backfill should create matching credit applied payments.'
        );
    }

    @IsTest
    static void givenContractDueTwoDaysAhead_whenInvoiceBatchRuns_thenInvoiceIsScheduled() {
        Tenancy__c tenancyRecord = [SELECT Id FROM Tenancy__c LIMIT 1];

        // Weekly contract that started 5 days ago rolls its next due date to today + 2,
        // which is only within the creation window now that the lookahead is 2 days.
        Contract contractRecord = createContract(tenancyRecord.Id, Date.today().addDays(-5));
        insert contractRecord;
        contractRecord.Status = 'Activated';
        update contractRecord;

        Test.startTest();
        Database.executeBatch(new InvoiceBatch(), 1);
        Test.stopTest();

        List<Invoice__c> invoices = [
            SELECT Id, Status__c, Due_Date__c
            FROM Invoice__c
            WHERE Tenancy__c = :tenancyRecord.Id
        ];

        Assert.areEqual(1, invoices.size(), 'InvoiceBatch should create one invoice 2 days ahead of the due date.');
        Assert.areEqual(Date.today().addDays(2), invoices[0].Due_Date__c, 'The invoice should be due 2 days from today.');
        Assert.areEqual('Scheduled', invoices[0].Status__c, 'The generated invoice should be Scheduled since there are no available credits.');
    }

    @IsTest
    static void givenInvoiceDueTomorrow_whenInvoiceBatchRuns_thenStatusBecomesUnpaidAndReminderNoticeIsIssued() {
        Tenancy__c tenancyRecord = [SELECT Id FROM Tenancy__c LIMIT 1];
        Invoice__c invoiceRecord = createInvoice(tenancyRecord.Id, 'Scheduled', Date.today().addDays(1));
        insert invoiceRecord;

        Test.startTest();
        Database.executeBatch(new InvoiceBatch(), 1);
        Test.stopTest();

        Invoice__c reloaded = [SELECT Status__c FROM Invoice__c WHERE Id = :invoiceRecord.Id];
        Assert.areEqual('Unpaid', reloaded.Status__c, 'An invoice due tomorrow should transition to Unpaid.');

        List<Notice__c> notices = [SELECT Id, Notice_Type__c FROM Notice__c WHERE Invoice__c = :invoiceRecord.Id];
        Assert.areEqual(1, notices.size(), 'The batch should issue a Rent Reminder notice for the newly-Unpaid invoice.');
        Assert.areEqual('Rent Reminder', notices[0].Notice_Type__c, 'The notice should be a Rent Reminder.');
        Assert.areEqual(
            1,
            [SELECT COUNT() FROM Task WHERE WhatId = :notices[0].Id AND TaskSubtype != 'Email'],
            'A follow-up Task should be logged under the notice.'
        );
    }

    @IsTest
    static void givenInvoicePastDueDate_whenInvoiceBatchRuns_thenStatusBecomesOverdueAndArrearsNoticeIsIssued() {
        Tenancy__c tenancyRecord = [SELECT Id FROM Tenancy__c LIMIT 1];
        Invoice__c invoiceRecord = createInvoice(tenancyRecord.Id, 'Unpaid', Date.today().addDays(-1));
        insert invoiceRecord;

        Test.startTest();
        Database.executeBatch(new InvoiceBatch(), 1);
        Test.stopTest();

        Invoice__c reloaded = [SELECT Status__c FROM Invoice__c WHERE Id = :invoiceRecord.Id];
        Assert.areEqual('Overdue', reloaded.Status__c, 'An invoice past its due date should transition to Overdue.');

        List<Notice__c> notices = [SELECT Id, Notice_Type__c FROM Notice__c WHERE Invoice__c = :invoiceRecord.Id];
        Assert.areEqual(1, notices.size(), 'The batch should issue a Rent Arrears notice for the newly-Overdue invoice.');
        Assert.areEqual('Rent Arrears', notices[0].Notice_Type__c, 'The notice should be a Rent Arrears notice.');
        Assert.areEqual(
            1,
            [SELECT COUNT() FROM Task WHERE WhatId = :notices[0].Id AND TaskSubtype != 'Email'],
            'A follow-up Task should be logged under the notice.'
        );
    }

    @IsTest
    static void givenPaidOrVoidInvoicesPastDueDate_whenInvoiceBatchRuns_thenStatusesAreUnchanged() {
        Tenancy__c tenancyRecord = [SELECT Id FROM Tenancy__c LIMIT 1];
        Invoice__c paidInvoice = createInvoice(tenancyRecord.Id, 'Paid', Date.today().addDays(-3));
        Invoice__c voidInvoice = createInvoice(tenancyRecord.Id, 'Void', Date.today().addDays(-3));
        insert new List<Invoice__c>{ paidInvoice, voidInvoice };

        Test.startTest();
        Database.executeBatch(new InvoiceBatch(), 1);
        Test.stopTest();

        Map<Id, Invoice__c> reloaded = new Map<Id, Invoice__c>([
            SELECT Status__c FROM Invoice__c WHERE Id IN (:paidInvoice.Id, :voidInvoice.Id)
        ]);
        Assert.areEqual('Paid', reloaded.get(paidInvoice.Id).Status__c, 'A Paid invoice must never be reopened by the batch.');
        Assert.areEqual('Void', reloaded.get(voidInvoice.Id).Status__c, 'A Void invoice must never be reopened by the batch.');
    }

    @IsTest
    static void givenBulkUnpaidInvoices_whenInvoiceBatchRuns_thenAllAreTransitioned() {
        Tenancy__c tenancyRecord = [SELECT Id FROM Tenancy__c LIMIT 1];
        List<Invoice__c> invoicesToInsert = new List<Invoice__c>();
        for (Integer i = 0; i < 20; i++) {
            invoicesToInsert.add(createInvoice(tenancyRecord.Id, 'Scheduled', Date.today().addDays(1)));
        }
        for (Integer i = 0; i < 20; i++) {
            invoicesToInsert.add(createInvoice(tenancyRecord.Id, 'Unpaid', Date.today().addDays(-2)));
        }
        insert invoicesToInsert;

        Test.startTest();
        Database.executeBatch(new InvoiceBatch(), 50);
        Test.stopTest();

        Assert.areEqual(
            20,
            [SELECT COUNT() FROM Invoice__c WHERE Tenancy__c = :tenancyRecord.Id AND Status__c = 'Unpaid'],
            'All invoices due tomorrow should be transitioned to Unpaid.'
        );
        Assert.areEqual(
            20,
            [SELECT COUNT() FROM Invoice__c WHERE Tenancy__c = :tenancyRecord.Id AND Status__c = 'Overdue'],
            'All invoices past their due date should be transitioned to Overdue.'
        );
    }

    private static Invoice__c createInvoice(Id tenancyId, String status, Date dueDate) {
        return new Invoice__c(
            Tenancy__c = tenancyId,
            Amount__c = 1000,
            Category__c = 'Rent',
            Invoice_Date__c = dueDate.addDays(-7),
            Due_Date__c = dueDate,
            Period_Start__c = dueDate.addDays(-7),
            Period_End__c = dueDate,
            Status__c = status
        );
    }

    private static Contract createContract(Id tenancyId, Date startDate) {
        Tenancy__c tenancyRecord = [
            SELECT Property__r.Landlord__c, Tenant__c
            FROM Tenancy__c
            WHERE Id = :tenancyId
            LIMIT 1
        ];

        return new Contract(
            AccountId = tenancyRecord.Property__r.Landlord__c,
            Tenancy__c = tenancyId,
            Status = 'Draft',
            StartDate = startDate,
            ContractTerm = 3,
            CustomerSignedId = tenancyRecord.Tenant__c,
            CustomerSignedDate = startDate,
            Rent_Amount__c = 1000,
            Rent_Frequency__c = 'Weekly'
        );
    }
}
