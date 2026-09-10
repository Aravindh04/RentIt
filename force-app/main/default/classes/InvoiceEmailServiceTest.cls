@IsTest(SeeAllData=false)
private class InvoiceEmailServiceTest {

    @TestSetup
    static void setup() {
        Account landlord = new Account(Name = 'Invoice Email Landlord');
        insert landlord;

        Property__c propertyRecord = new Property__c(
            Property_Type__c = 'House',
            Landlord__c = landlord.Id
        );
        insert propertyRecord;

        Account tenantAccountWithEmail = new Account(Name = 'Invoice Email Tenant Account');
        insert tenantAccountWithEmail;

        Contact tenantContactWithEmail = new Contact(
            FirstName = 'Receipt',
            LastName = 'Tenant',
            Email = 'receipt.tenant@rentit.test',
            AccountId = tenantAccountWithEmail.Id
        );
        insert tenantContactWithEmail;

        Contact tenantContactWithoutEmail = new Contact(
            FirstName = 'NoEmail',
            LastName = 'Tenant',
            AccountId = tenantAccountWithEmail.Id
        );
        insert tenantContactWithoutEmail;

        Tenancy__c tenancyWithEmail = new Tenancy__c(
            Property__c = propertyRecord.Id,
            Tenant__c = tenantContactWithEmail.Id,
            Status__c = 'Active'
        );
        insert tenancyWithEmail;

        Tenancy__c tenancyWithoutEmail = new Tenancy__c(
            Property__c = propertyRecord.Id,
            Tenant__c = tenantContactWithoutEmail.Id,
            Status__c = 'Active'
        );
        insert tenancyWithoutEmail;

        insert new Invoice__c(
            Tenancy__c = tenancyWithEmail.Id,
            Amount__c = 500,
            Status__c = 'Paid',
            Category__c = 'Rent',
            Invoice_Date__c = Date.today(),
            Due_Date__c = Date.today()
        );

        insert new Invoice__c(
            Tenancy__c = tenancyWithoutEmail.Id,
            Amount__c = 300,
            Status__c = 'Paid',
            Category__c = 'Rent',
            Invoice_Date__c = Date.today(),
            Due_Date__c = Date.today()
        );
    }

    @IsTest
    static void givenPaidInvoiceWithTenantEmail_whenReceiptsQueued_thenEmailIsSent() {
        Invoice__c invoiceRecord = [
            SELECT Id
            FROM Invoice__c
            WHERE Tenancy__r.Tenant__r.Email = 'receipt.tenant@rentit.test'
            LIMIT 1
        ];

        InvoiceEmailService.lastEmailsSentCount = 0;

        Test.startTest();
        InvoiceEmailService.sendInvoicePaidReceipts(new Set<Id>{ invoiceRecord.Id });
        Test.stopTest();

        Assert.areEqual(
            1,
            InvoiceEmailService.lastEmailsSentCount,
            'A receipt email should have been sent for the paid invoice.'
        );
    }

    @IsTest
    static void givenNullOrEmptyInvoiceIds_whenReceiptsQueued_thenNoEmailIsSent() {
        InvoiceEmailService.lastEmailsSentCount = 0;

        Test.startTest();
        InvoiceEmailService.sendInvoicePaidReceipts(null);
        InvoiceEmailService.sendInvoicePaidReceipts(new Set<Id>());
        Test.stopTest();

        Assert.areEqual(
            0,
            InvoiceEmailService.lastEmailsSentCount,
            'No email should be sent when no invoice Ids are supplied.'
        );
    }

    @IsTest
    static void givenTenantWithoutEmail_whenReceiptsQueued_thenEmailIsSkippedGracefully() {
        Invoice__c invoiceRecord = [
            SELECT Id
            FROM Invoice__c
            WHERE Tenancy__r.Tenant__r.Email = null
            LIMIT 1
        ];

        InvoiceEmailService.lastEmailsSentCount = 0;

        Test.startTest();
        InvoiceEmailService.sendInvoicePaidReceipts(new Set<Id>{ invoiceRecord.Id });
        Test.stopTest();

        Assert.areEqual(
            0,
            InvoiceEmailService.lastEmailsSentCount,
            'No email should be sent when the tenant contact has no email address.'
        );
    }

    @IsTest
    static void givenBulkPaidInvoices_whenReceiptsQueued_thenAllBatchesAreProcessed() {
        Tenancy__c tenancyRecord = [
            SELECT Id
            FROM Tenancy__c
            WHERE Tenant__r.Email = 'receipt.tenant@rentit.test'
            LIMIT 1
        ];

        List<Invoice__c> bulkInvoices = new List<Invoice__c>();
        for (Integer index = 0; index < 40; index++) {
            bulkInvoices.add(new Invoice__c(
                Tenancy__c = tenancyRecord.Id,
                Amount__c = 100,
                Status__c = 'Paid',
                Category__c = 'Rent',
                Invoice_Date__c = Date.today(),
                Due_Date__c = Date.today()
            ));
        }
        insert bulkInvoices;

        Set<Id> invoiceIds = new Map<Id, Invoice__c>(bulkInvoices).keySet();
        InvoiceEmailService.lastEmailsSentCount = 0;

        Test.startTest();
        InvoiceEmailService.sendInvoicePaidReceipts(invoiceIds);
        Test.stopTest();

        Assert.areEqual(
            40,
            InvoiceEmailService.lastEmailsSentCount,
            'Every bulk-paid invoice with a tenant email should receive a receipt email.'
        );
    }
}
