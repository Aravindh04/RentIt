@IsTest(SeeAllData=false)
private class InvoiceTriggerHandlerTest {

    @TestSetup
    static void setup() {
        Account landlord = new Account(Name = 'Invoice Handler Landlord');
        insert landlord;

        Property__c propertyRecord = new Property__c(
            Property_Type__c = 'House',
            Landlord__c = landlord.Id
        );
        insert propertyRecord;

        Account tenantAccount = new Account(Name = 'Invoice Handler Tenant Account');
        insert tenantAccount;

        Contact tenantContact = new Contact(
            FirstName = 'Invoice',
            LastName = 'Tenant',
            Email = 'invoice.tenant@rentit.test',
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
    static void givenAvailableCredits_whenInvoiceInserted_thenCreditPaymentIsCreated() {
        Tenancy__c tenancyRecord = [SELECT Id FROM Tenancy__c LIMIT 1];

        insert new Payment__c(
            Tenancy__c = tenancyRecord.Id,
            Amount__c = 1000,
            Payment_Date__c = Date.today(),
            Payment_Method__c = 'Bank Transfer',
            Payment_Type__c = 'Rent Payment',
            Status__c = 'Received'
        );

        Invoice__c invoiceRecord = new Invoice__c(
            Tenancy__c = tenancyRecord.Id,
            Amount__c = 750,
            Status__c = 'Unpaid',
            Category__c = 'Rent',
            Invoice_Date__c = Date.today(),
            Due_Date__c = Date.today()
        );

        Test.startTest();
        insert invoiceRecord;
        Test.stopTest();

        List<Payment__c> payments = [
            SELECT Amount__c, Payment_Type__c, Status__c, Invoice__c
            FROM Payment__c
            WHERE Invoice__c = :invoiceRecord.Id
        ];

        Assert.areEqual(1, payments.size(), 'A single credit payment should be created for the invoice.');
        Assert.areEqual(750, payments[0].Amount__c, 'The credit payment should match the invoice amount.');
        Assert.areEqual('Credit Applied', payments[0].Payment_Type__c, 'The payment should be marked as credit applied.');
        Assert.areEqual('Received', payments[0].Status__c, 'The credit payment should be marked as received.');

        Invoice__c updatedInvoice = [
            SELECT Total_Paid__c, Status__c
            FROM Invoice__c
            WHERE Id = :invoiceRecord.Id
        ];
        Assert.areEqual(750, updatedInvoice.Total_Paid__c, 'The invoice total paid should be updated.');
        Assert.areEqual('Paid', updatedInvoice.Status__c, 'The invoice should be marked paid.');
    }

    @IsTest
    static void givenNoAvailableCredits_whenInvoiceInserted_thenNoCreditPaymentIsCreated() {
        Tenancy__c tenancyRecord = [SELECT Id FROM Tenancy__c LIMIT 1];

        Invoice__c invoiceRecord = new Invoice__c(
            Tenancy__c = tenancyRecord.Id,
            Amount__c = 450,
            Status__c = 'Unpaid',
            Category__c = 'Rent',
            Invoice_Date__c = Date.today(),
            Due_Date__c = Date.today()
        );

        Test.startTest();
        insert invoiceRecord;
        Test.stopTest();

        Assert.areEqual(
            0,
            [SELECT COUNT() FROM Payment__c WHERE Invoice__c = :invoiceRecord.Id],
            'No payment should be generated without available credits.'
        );

        Invoice__c updatedInvoice = [
            SELECT Total_Paid__c, Status__c
            FROM Invoice__c
            WHERE Id = :invoiceRecord.Id
        ];
        Decimal totalPaid = updatedInvoice.Total_Paid__c != null ? updatedInvoice.Total_Paid__c : 0;
        Assert.areEqual(0, totalPaid, 'The invoice total paid should remain zero.');
        Assert.areEqual('Unpaid', updatedInvoice.Status__c, 'The invoice status should remain unchanged.');
    }

    @IsTest
    static void givenCreditsBecomeAvailable_whenInvoiceUpdated_thenCreditPaymentIsCreated() {
        Tenancy__c tenancyRecord = [SELECT Id FROM Tenancy__c LIMIT 1];

        Invoice__c invoiceRecord = new Invoice__c(
            Tenancy__c = tenancyRecord.Id,
            Amount__c = 500,
            Status__c = 'Unpaid',
            Category__c = 'Rent',
            Invoice_Date__c = Date.today(),
            Due_Date__c = Date.today()
        );
        insert invoiceRecord;

        insert new Payment__c(
            Tenancy__c = tenancyRecord.Id,
            Amount__c = 500,
            Payment_Date__c = Date.today(),
            Payment_Method__c = 'Bank Transfer',
            Payment_Type__c = 'Rent Payment',
            Status__c = 'Received'
        );

        Test.startTest();
        invoiceRecord.Due_Date__c = Date.today().addDays(1);
        update invoiceRecord;
        Test.stopTest();

        List<Payment__c> payments = [
            SELECT Amount__c, Payment_Type__c, Status__c
            FROM Payment__c
            WHERE Invoice__c = :invoiceRecord.Id
            AND Payment_Type__c = 'Credit Applied'
        ];

        Assert.areEqual(1, payments.size(), 'The invoice update should create one credit payment.');
        Assert.areEqual(500, payments[0].Amount__c, 'The payment should match the invoice amount.');
        Assert.areEqual('Received', payments[0].Status__c, 'The payment should be received.');

        Invoice__c updatedInvoice = [
            SELECT Total_Paid__c, Status__c
            FROM Invoice__c
            WHERE Id = :invoiceRecord.Id
        ];
        Assert.areEqual(500, updatedInvoice.Total_Paid__c, 'The invoice total paid should be updated after the change.');
        Assert.areEqual('Paid', updatedInvoice.Status__c, 'The invoice should be marked paid after the update.');
        Assert.areEqual(
            1,
            InvoiceEmailService.lastEmailsSentCount,
            'Transitioning the invoice to Paid should queue the Invoice Paid receipt email.'
        );
    }

    @IsTest
    static void givenBulkInvoices_whenInserted_thenAllCreditPaymentsAreCreated() {
        Tenancy__c tenancyRecord = [SELECT Id FROM Tenancy__c LIMIT 1];

        insert new Payment__c(
            Tenancy__c = tenancyRecord.Id,
            Amount__c = 2000,
            Payment_Date__c = Date.today(),
            Payment_Method__c = 'Bank Transfer',
            Payment_Type__c = 'Rent Payment',
            Status__c = 'Received'
        );

        List<Invoice__c> invoices = new List<Invoice__c>();
        for (Integer index = 0; index < 200; index++) {
            invoices.add(new Invoice__c(
                Tenancy__c = tenancyRecord.Id,
                Amount__c = 10,
                Status__c = 'Unpaid',
                Category__c = 'Rent',
                Invoice_Date__c = Date.today(),
                Due_Date__c = Date.today()
            ));
        }

        Test.startTest();
        insert invoices;
        Test.stopTest();

        Set<Id> invoiceIds = new Map<Id, Invoice__c>(invoices).keySet();
        Assert.areEqual(
            200,
            [SELECT COUNT() FROM Payment__c WHERE Invoice__c IN :invoiceIds AND Payment_Type__c = 'Credit Applied'],
            'Every bulk invoice should receive a credit payment.'
        );

        for (Invoice__c invoiceRecord : [
            SELECT Total_Paid__c, Status__c
            FROM Invoice__c
            WHERE Id IN :invoiceIds
        ]) {
            Assert.areEqual(10, invoiceRecord.Total_Paid__c, 'Each invoice should be fully paid.');
            Assert.areEqual('Paid', invoiceRecord.Status__c, 'Each invoice should be marked paid.');
        }
    }
}
