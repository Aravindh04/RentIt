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
            SELECT Id, Status__c
            FROM Invoice__c
            WHERE Tenancy__c = :tenancyRecord.Id
        ];

        Assert.areEqual(1, invoices.size(), 'InvoiceBatch should create one invoice for the lookahead period.');
        Assert.areEqual('Paid', invoices[0].Status__c, 'The generated invoice should be marked paid.');
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
            SELECT Id, Status__c
            FROM Invoice__c
            WHERE Tenancy__c = :tenancyRecord.Id
            ORDER BY Period_Start__c
        ];

        Assert.areEqual(3, invoices.size(), 'Backfill should create the missing invoice history.');
        for (Invoice__c invoiceRecord : invoices) {
            Assert.areEqual('Paid', invoiceRecord.Status__c, 'Backfilled invoices should be marked paid.');
        }
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
