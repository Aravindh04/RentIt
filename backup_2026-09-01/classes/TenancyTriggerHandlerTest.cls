@IsTest
private class TenancyTriggerHandlerTest {

    // ── Test data setup ──────────────────────────────────────────────────────

    @TestSetup
    static void setup() {
        User adminUser = TestDataFactory.createAdminUser();

        System.runAs(adminUser) {
            TestDataFactory.createPortalUser('Alice', 'Tenant'); // Creates a portal user with a contact and account.
            TestDataFactory.createPortalUser('Bob', 'Tenant');   // Creates a portal user with a contact and account.
        }
        
        Account landlord = new Account(Name = 'Test Landlord', OwnerId = adminUser.Id );
        insert landlord;

        Property__c prop = new Property__c(
            Property_Type__c = 'House',
            Landlord__c = landlord.Id
        );
        insert prop;
    
    }

    // ── Insert: portal user exists → share created ───────────────────────────

    @IsTest
    static void afterInsert_portalUserExists_shareCreated() {
        
        Property__c prop = [SELECT Id FROM Property__c LIMIT 1];
        Contact alice = [SELECT Id FROM Contact WHERE FirstName = 'Alice' LIMIT 1];

        Tenancy__c tenancy = new Tenancy__c(
            Property__c = prop.Id,
            Tenant__c   = alice.Id,
            Status__c   = 'Active'
        );

        Test.startTest();
        insert tenancy;
        Test.stopTest();

        List<Tenancy__Share> shares = [
            SELECT UserOrGroupId, AccessLevel
            FROM Tenancy__Share
            WHERE ParentId = :tenancy.Id
            AND RowCause = 'Manual'
        ];
        System.assertEquals(1, shares.size(), 'One manual share should be created');
        System.assertEquals('Read', shares[0].AccessLevel);
        System.assertEquals(portalUser.Id, shares[0].UserOrGroupId);
    }

    // ── Insert: no portal user → no share ────────────────────────────────────

    @IsTest
    static void afterInsert_noPortalUser_noShare() {
        // Bob has no portal User account
        Contact bob = [SELECT Id FROM Contact WHERE FirstName = 'Bob' LIMIT 1];
        Property__c prop = [SELECT Id FROM Property__c LIMIT 1];

        Tenancy__c tenancy = new Tenancy__c(
            Property__c = prop.Id,
            Tenant__c   = bob.Id,
            Status__c   = 'Active'
        );

        Test.startTest();
        insert tenancy;
        Test.stopTest();

        Integer shareCount = [
            SELECT COUNT() FROM Tenancy__Share
            WHERE ParentId = :tenancy.Id AND RowCause = 'Manual'
        ];
        System.assertEquals(0, shareCount, 'No share should be created when the tenant has no portal user');
    }

    // ── Update: tenant changed → old share removed, new share created ─────────

    @IsTest
    static void afterUpdate_tenantChanged_swapsShare() {
        Contact alice = [SELECT Id FROM Contact WHERE FirstName = 'Alice' LIMIT 1];
        Contact bob   = [SELECT Id FROM Contact WHERE FirstName = 'Bob' LIMIT 1];
        User bobPortalUser = TestDataFactory.createPortalUser(bob.Id, 'bob2');
        Property__c prop = [SELECT Id FROM Property__c LIMIT 1];

        Tenancy__c tenancy = new Tenancy__c(
            Property__c = prop.Id,
            Tenant__c   = alice.Id,
            Status__c   = 'Active'
        );
        insert tenancy;

        Test.startTest();
        tenancy.Tenant__c = bob.Id;
        update tenancy;
        Test.stopTest();

        List<Tenancy__Share> shares = [
            SELECT UserOrGroupId FROM Tenancy__Share
            WHERE ParentId = :tenancy.Id AND RowCause = 'Manual'
        ];
        System.assertEquals(1, shares.size(), 'Exactly one share should exist after tenant change');
        System.assertEquals(bobPortalUser.Id, shares[0].UserOrGroupId, 'Share should belong to the new tenant');
    }

    // ── Update: tenant unchanged → shares untouched ───────────────────────────

    @IsTest
    static void afterUpdate_tenantUnchanged_sharesPreserved() {
        Contact alice = [SELECT Id FROM Contact WHERE FirstName = 'Alice' LIMIT 1];
        Property__c prop = [SELECT Id FROM Property__c LIMIT 1];
        
        Tenancy__c tenancy = new Tenancy__c(
            Property__c = prop.Id,
            Tenant__c   = alice.Id,
            Status__c   = 'Active'
        );
        insert tenancy;

        Test.startTest();
        tenancy.Status__c = 'Pending';
        update tenancy;
        Test.stopTest();

        Integer shareCount = [
            SELECT COUNT() FROM Tenancy__Share
            WHERE ParentId = :tenancy.Id AND RowCause = 'Manual'
        ];
        System.assertEquals(1, shareCount, 'Existing share should be preserved when Tenant__c is unchanged');
    }
}