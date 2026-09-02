@IsTest
private class PaymentTriggerHandlerTest {

    // ── Test data setup ──────────────────────────────────────────────────────

    @TestSetup
    static void setup() {
        Account landlord = new Account(Name = 'Landlord Corp');
        insert landlord;

        Property__c prop = new Property__c(
            Property_Type__c = 'House',
            Landlord__c = landlord.Id
        );
        insert prop;

        Account tenantAccount = new Account(Name = 'Tenant Account');
        insert tenantAccount;

        Contact tenant = new Contact(
            FirstName = 'Test', LastName = 'Tenant',
            Email = 'tenant@rentit.test'
        );
        insert tenant;

        Tenancy__c tenancy = new Tenancy__c(
            Property__c      = prop.Id,
            Tenant__c        = tenant.Id,
            Tenant_Account__c = tenantAccount.Id,
            Status__c        = 'Active'
        );
        insert tenancy;

        Invoice__c inv = new Invoice__c(
            Tenancy__c      = tenancy.Id,
            Amount__c       = 1000,
            Status__c       = 'Unpaid',
            Category__c     = 'Rent',
            Invoice_Date__c = Date.today(),
            Due_Date__c     = Date.today()
        );
        insert inv;
    }

    // ── Before Insert: populate Tenancy from Invoice ──────────────────────────

    @IsTest
    static void beforeInsert_populatesTenancyFromInvoice() {
        Invoice__c inv = [SELECT Id, Tenancy__c FROM Invoice__c LIMIT 1];

        // Omit Tenancy__c — before trigger must populate it from Invoice
        Payment__c payment = new Payment__c(
            Invoice__c      = inv.Id,
            Amount__c       = 500,
            Payment_Date__c = Date.today(),
            Payment_Method__c = 'Pay ID',
            Payment_Type__c = 'Invoice Payment',
            Status__c       = 'Received'
        );

        Test.startTest();
        insert payment;
        Test.stopTest();

        Payment__c saved = [SELECT Tenancy__c FROM Payment__c WHERE Id = :payment.Id];
        System.assertEquals(inv.Tenancy__c, saved.Tenancy__c,
            'Tenancy__c should be auto-populated from the linked Invoice');
    }

    // ── After Insert: received payment updates Invoice.Total_Paid__c ──────────

    @IsTest
    static void afterInsert_receivedPayment_updatesTotalPaid() {
        Invoice__c inv = [SELECT Id FROM Invoice__c LIMIT 1];
        Tenancy__c ten = [SELECT Id FROM Tenancy__c LIMIT 1];

        Payment__c payment = new Payment__c(
            Tenancy__c        = ten.Id,
            Invoice__c        = inv.Id,
            Amount__c         = 300,
            Payment_Date__c   = Date.today(),
            Payment_Method__c = 'Pay ID',
            Payment_Type__c   = 'Invoice Payment',
            Status__c         = 'Received'
        );

        Test.startTest();
        insert payment;
        Test.stopTest();

        Invoice__c updated = [SELECT Total_Paid__c FROM Invoice__c WHERE Id = :inv.Id];
        System.assertEquals(300, updated.Total_Paid__c,
            'Total_Paid__c should reflect the received payment amount');
    }

    // ── After Insert: non-received payment does NOT update Total_Paid__c ──────

    @IsTest
    static void afterInsert_pendingPayment_doesNotUpdateTotalPaid() {
        Invoice__c inv = [SELECT Id FROM Invoice__c LIMIT 1];
        Tenancy__c ten = [SELECT Id FROM Tenancy__c LIMIT 1];

        Payment__c payment = new Payment__c(
            Tenancy__c        = ten.Id,
            Invoice__c        = inv.Id,
            Amount__c         = 300,
            Payment_Date__c   = Date.today(),
            Payment_Method__c = 'Pay ID',
            Payment_Type__c   = 'Invoice Payment',
            Status__c         = 'Pending Approval'
        );

        Test.startTest();
        insert payment;
        Test.stopTest();

        Invoice__c updated = [SELECT Total_Paid__c FROM Invoice__c WHERE Id = :inv.Id];
        Decimal totalPaid = updated.Total_Paid__c != null ? updated.Total_Paid__c : 0;
        System.assertEquals(0, totalPaid,
            'Pending payment should not affect Total_Paid__c');
    }

    // ── After Update: status → Received triggers recalculation ───────────────

    @IsTest
    static void afterUpdate_statusToReceived_updatesTotalPaid() {
        Invoice__c inv = [SELECT Id FROM Invoice__c LIMIT 1];
        Tenancy__c ten = [SELECT Id FROM Tenancy__c LIMIT 1];

        Payment__c payment = new Payment__c(
            Tenancy__c        = ten.Id,
            Invoice__c        = inv.Id,
            Amount__c         = 500,
            Payment_Date__c   = Date.today(),
            Payment_Method__c = 'Bank Transfer',
            Payment_Type__c   = 'Invoice Payment',
            Status__c         = 'Pending Approval'
        );
        insert payment;

        Test.startTest();
        payment.Status__c = 'Received';
        update payment;
        Test.stopTest();

        Invoice__c updated = [SELECT Total_Paid__c FROM Invoice__c WHERE Id = :inv.Id];
        System.assertEquals(500, updated.Total_Paid__c,
            'Total_Paid__c should update when payment status changes to Received');
    }

    // ── After Delete: received payment deleted → Total_Paid__c recalculated ──

    @IsTest
    static void afterDelete_receivedPayment_recalculatesTotalPaid() {
        Invoice__c inv = [SELECT Id FROM Invoice__c LIMIT 1];
        Tenancy__c ten = [SELECT Id FROM Tenancy__c LIMIT 1];

        Payment__c payment = new Payment__c(
            Tenancy__c        = ten.Id,
            Invoice__c        = inv.Id,
            Amount__c         = 400,
            Payment_Date__c   = Date.today(),
            Payment_Method__c = 'Cash',
            Payment_Type__c   = 'Invoice Payment',
            Status__c         = 'Received'
        );
        insert payment;

        Test.startTest();
        delete payment;
        Test.stopTest();

        Invoice__c updated = [SELECT Total_Paid__c FROM Invoice__c WHERE Id = :inv.Id];
        System.assertEquals(0, updated.Total_Paid__c,
            'Total_Paid__c should be 0 after the only received payment is deleted');
    }

    // ── After Insert: received payment updates Account.Total_Payments_Received__c

    @IsTest
    static void afterInsert_receivedPayment_updatesAccountTotal() {
        Tenancy__c ten = [SELECT Id FROM Tenancy__c LIMIT 1];
        Account tenantAcct = [SELECT Id FROM Account WHERE Name = 'Tenant Account' LIMIT 1];

        Payment__c payment = new Payment__c(
            Tenancy__c        = ten.Id,
            Amount__c         = 750,
            Payment_Date__c   = Date.today(),
            Payment_Method__c = 'Pay ID',
            Payment_Type__c   = 'Rent Payment',
            Status__c         = 'Received'
        );

        Test.startTest();
        insert payment;
        Test.stopTest();

        Account updated = [SELECT Total_Payments_Received__c FROM Account WHERE Id = :tenantAcct.Id];
        System.assertEquals(750, updated.Total_Payments_Received__c,
            'Account Total_Payments_Received__c should reflect all received payments');
    }

    // ── Multiple payments: Total_Paid__c aggregates correctly ─────────────────

    @IsTest
    static void afterInsert_multipleReceivedPayments_aggregatesTotal() {
        Invoice__c inv = [SELECT Id FROM Invoice__c LIMIT 1];
        Tenancy__c ten = [SELECT Id FROM Tenancy__c LIMIT 1];

        List<Payment__c> payments = new List<Payment__c>{
            new Payment__c(
                Tenancy__c = ten.Id, Invoice__c = inv.Id, Amount__c = 200,
                Payment_Date__c = Date.today(), Payment_Method__c = 'Cash',
                Payment_Type__c = 'Invoice Payment', Status__c = 'Received'
            ),
            new Payment__c(
                Tenancy__c = ten.Id, Invoice__c = inv.Id, Amount__c = 300,
                Payment_Date__c = Date.today(), Payment_Method__c = 'Pay ID',
                Payment_Type__c = 'Credit Applied', Status__c = 'Received'
            )
        };

        Test.startTest();
        insert payments;
        Test.stopTest();

        Invoice__c updated = [SELECT Total_Paid__c FROM Invoice__c WHERE Id = :inv.Id];
        System.assertEquals(500, updated.Total_Paid__c,
            'Total_Paid__c should be the sum of all received Invoice Payment and Credit Applied amounts');
    }
}
