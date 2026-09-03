@IsTest
private class PaymentTriggerHandlerTest {

    private static final String COMMUNITY_PROFILE_NAME = 'Customer Community Plus User';
    private static final String TENANT_PERMISSION_SET_NAME = 'RentIt_Tenant';

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

        Contact tenantContact = new Contact(
            FirstName = 'Test',
            LastName = 'Tenant',
            Email = 'tenant@rentit.test',
            AccountId = tenantAccount.Id
        );
        insert tenantContact;

        Tenancy__c tenancy = new Tenancy__c(
            Property__c = prop.Id,
            Tenant__c = tenantContact.Id,
            Status__c = 'Active'
        );
        insert tenancy;

        Invoice__c inv = new Invoice__c(
            Tenancy__c = tenancy.Id,
            Amount__c = 1000,
            Status__c = 'Unpaid',
            Category__c = 'Rent',
            Invoice_Date__c = Date.today(),
            Due_Date__c = Date.today()
        );
        insert inv;
    }

    private static User createTenantCommunityUser(Contact tenantContact) {
        Profile customerCommunityProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = :COMMUNITY_PROFILE_NAME
            LIMIT 1
        ];

        User tenantUser = new User(
            ProfileId = customerCommunityProfile.Id,
            Username = 'tenant.community.' + System.currentTimeMillis() + '@rentit.test',
            Alias = 'tenant',
            Email = tenantContact.Email,
            EmailEncodingKey = 'UTF-8',
            LastName = tenantContact.LastName,
            FirstName = tenantContact.FirstName,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_AU',
            TimeZoneSidKey = 'Australia/Sydney',
            ContactId = tenantContact.Id
        );
        insert tenantUser;

        PermissionSet tenantPermissionSet = [
            SELECT Id
            FROM PermissionSet
            WHERE Name = :TENANT_PERMISSION_SET_NAME
            LIMIT 1
        ];

        insert new PermissionSetAssignment(
            AssigneeId = tenantUser.Id,
            PermissionSetId = tenantPermissionSet.Id
        );

        return [
            SELECT Id, Profile.Name, ContactId
            FROM User
            WHERE Id = :tenantUser.Id
            LIMIT 1
        ];
    }

    private static User getTenantCommunityUser() {
        Contact tenantContact = [
            SELECT Id, Email, FirstName, LastName
            FROM Contact
            WHERE Email = 'tenant@rentit.test'
            LIMIT 1
        ];
        return createTenantCommunityUser(tenantContact);
    }

    private static void assertTenantCommunityUser(User tenantUser) {
        System.assertEquals(COMMUNITY_PROFILE_NAME, tenantUser.Profile.Name,
            'The active user should be a Customer Community Plus user.');

        Integer permissionCount = [
            SELECT COUNT()
            FROM PermissionSetAssignment
            WHERE AssigneeId = :tenantUser.Id
              AND PermissionSet.Name = :TENANT_PERMISSION_SET_NAME
        ];
        System.assertEquals(1, permissionCount,
            'The tenant user should have the RentIt_Tenant permission set assigned.');
    }

    @IsTest
    static void testBeforeInsertPopulatesTenancyFromInvoice() {
        User tenantUser = getTenantCommunityUser();
        assertTenantCommunityUser(tenantUser);

        Invoice__c inv = [SELECT Id, Tenancy__c FROM Invoice__c LIMIT 1];

        System.runAs(tenantUser) {
            Payment__c payment = new Payment__c(
                Invoice__c = inv.Id,
                Amount__c = 500,
                Payment_Date__c = Date.today(),
                Payment_Method__c = 'Pay ID',
                Payment_Type__c = 'Invoice Payment',
                Status__c = 'Received'
            );

            Test.startTest();
            insert payment;
            Test.stopTest();

            Payment__c saved = [SELECT Tenancy__c FROM Payment__c WHERE Id = :payment.Id];
            System.assertEquals(inv.Tenancy__c, saved.Tenancy__c,
                'Tenancy__c should be auto-populated from the linked Invoice');
        }
    }

    @IsTest
    static void testAfterInsertReceivedPaymentUpdatesTotalPaid() {
        User tenantUser = getTenantCommunityUser();
        assertTenantCommunityUser(tenantUser);

        Invoice__c inv = [SELECT Id FROM Invoice__c LIMIT 1];
        Tenancy__c ten = [SELECT Id FROM Tenancy__c LIMIT 1];

        System.runAs(tenantUser) {
            Payment__c payment = new Payment__c(
                Tenancy__c = ten.Id,
                Invoice__c = inv.Id,
                Amount__c = 300,
                Payment_Date__c = Date.today(),
                Payment_Method__c = 'Pay ID',
                Payment_Type__c = 'Invoice Payment',
                Status__c = 'Received'
            );

            Test.startTest();
            insert payment;
            Test.stopTest();
        }

        Invoice__c updated = [SELECT Total_Paid__c FROM Invoice__c WHERE Id = :inv.Id];
        System.assertEquals(300, updated.Total_Paid__c,
            'Total_Paid__c should reflect the received payment amount');
    }

    @IsTest
    static void testAfterInsertPendingPaymentDoesNotUpdateTotalPaid() {
        User tenantUser = getTenantCommunityUser();
        assertTenantCommunityUser(tenantUser);

        Invoice__c inv = [SELECT Id FROM Invoice__c LIMIT 1];
        Tenancy__c ten = [SELECT Id FROM Tenancy__c LIMIT 1];

        System.runAs(tenantUser) {
            Payment__c payment = new Payment__c(
                Tenancy__c = ten.Id,
                Invoice__c = inv.Id,
                Amount__c = 300,
                Payment_Date__c = Date.today(),
                Payment_Method__c = 'Pay ID',
                Payment_Type__c = 'Invoice Payment',
                Status__c = 'Pending Approval'
            );

            Test.startTest();
            insert payment;
            Test.stopTest();
        }

        Invoice__c updated = [SELECT Total_Paid__c FROM Invoice__c WHERE Id = :inv.Id];
        Decimal totalPaid = updated.Total_Paid__c != null ? updated.Total_Paid__c : 0;
        System.assertEquals(0, totalPaid,
            'Pending payment should not affect Total_Paid__c');
    }

    @IsTest
    static void testAfterUpdateStatusToReceivedUpdatesTotalPaid() {
        User tenantUser = getTenantCommunityUser();
        assertTenantCommunityUser(tenantUser);

        Invoice__c inv = [SELECT Id FROM Invoice__c LIMIT 1];
        Tenancy__c ten = [SELECT Id FROM Tenancy__c LIMIT 1];

        Payment__c payment;
        System.runAs(tenantUser) {
            payment = new Payment__c(
                Tenancy__c = ten.Id,
                Invoice__c = inv.Id,
                Amount__c = 500,
                Payment_Date__c = Date.today(),
                Payment_Method__c = 'Bank Transfer',
                Payment_Type__c = 'Invoice Payment',
                Status__c = 'Pending Approval'
            );
            insert payment;
        }

        System.runAs(tenantUser) {
            Test.startTest();
            payment.Status__c = 'Received';
            update payment;
            Test.stopTest();
        }

        Invoice__c updated = [SELECT Total_Paid__c FROM Invoice__c WHERE Id = :inv.Id];
        System.assertEquals(500, updated.Total_Paid__c,
            'Total_Paid__c should update when payment status changes to Received');
    }

    @IsTest
    static void testAfterDeleteReceivedPaymentRecalculatesTotalPaid() {
        User tenantUser = getTenantCommunityUser();
        assertTenantCommunityUser(tenantUser);

        Invoice__c inv = [SELECT Id FROM Invoice__c LIMIT 1];
        Tenancy__c ten = [SELECT Id FROM Tenancy__c LIMIT 1];

        Payment__c payment;
        System.runAs(tenantUser) {
            payment = new Payment__c(
                Tenancy__c = ten.Id,
                Invoice__c = inv.Id,
                Amount__c = 400,
                Payment_Date__c = Date.today(),
                Payment_Method__c = 'Cash',
                Payment_Type__c = 'Invoice Payment',
                Status__c = 'Received'
            );
            insert payment;
        }

        System.runAs(tenantUser) {
            Test.startTest();
            delete payment;
            Test.stopTest();
        }

        Invoice__c updated = [SELECT Total_Paid__c FROM Invoice__c WHERE Id = :inv.Id];
        System.assertEquals(0, updated.Total_Paid__c,
            'Total_Paid__c should be 0 after the only received payment is deleted');
    }

    @IsTest
    static void testAfterInsertMultipleReceivedPaymentsAggregatesTotal() {
        User tenantUser = getTenantCommunityUser();
        assertTenantCommunityUser(tenantUser);

        Invoice__c inv = [SELECT Id FROM Invoice__c LIMIT 1];
        Tenancy__c ten = [SELECT Id FROM Tenancy__c LIMIT 1];

        List<Payment__c> payments = new List<Payment__c>();
        System.runAs(tenantUser) {
            payments.addAll(new List<Payment__c>{
                new Payment__c(
                    Tenancy__c = ten.Id,
                    Invoice__c = inv.Id,
                    Amount__c = 200,
                    Payment_Date__c = Date.today(),
                    Payment_Method__c = 'Cash',
                    Payment_Type__c = 'Invoice Payment',
                    Status__c = 'Received'
                ),
                new Payment__c(
                    Tenancy__c = ten.Id,
                    Invoice__c = inv.Id,
                    Amount__c = 300,
                    Payment_Date__c = Date.today(),
                    Payment_Method__c = 'Pay ID',
                    Payment_Type__c = 'Credit Applied',
                    Status__c = 'Received'
                )
            });

            Test.startTest();
            insert payments;
            Test.stopTest();
        }

        Invoice__c updated = [SELECT Total_Paid__c FROM Invoice__c WHERE Id = :inv.Id];
        System.assertEquals(500, updated.Total_Paid__c,
            'Total_Paid__c should be the sum of all received Invoice Payment and Credit Applied amounts');
    }
}