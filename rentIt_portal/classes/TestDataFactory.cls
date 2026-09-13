/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an org are executed whenever Apex code is deployed
 * to a production org to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production org. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the org size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
public with sharing class TestDataFactory {

    public static User createAdminUser() {
        // 1. Fetch a profile and create a UserRole
        Profile systemAdminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        UserRole topRole = new UserRole(DeveloperName = 'TestTopRole', Name = 'Top Role');
        insert topRole;

        // 2. Create a setup an admin user with that role
        User adminUser = new User(
            Alias = 'ownertst',
            Email = 'owner@testorg.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Testing',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_AU',
            ProfileId = systemAdminProfile.Id,
            UserRoleId = topRole.Id, // <-- Crucial step
            TimeZoneSidKey = 'Australia/Melbourne',
            UserName = 'unique_owner_test_user@testorg.com'
        );
        insert adminUser;
        return adminUser;
    }

    // Account creation
    public static Account createPortalAccount() {
        return createPortalAccount('Test Portal Account');
    }

    public static Account createPortalAccount(String accountName) {
        Account acc = new Account(Name = accountName);
        insert acc;
        return acc;
    }

    // Contact creation
    public static Contact createPortalContact() {
       return createPortalContact('Priya', 'Tenant');
    }

    public static Contact createPortalContact( String firstName, String lastName ) {
        Account acc = createPortalAccount(firstName + ' ' + lastName + ' Account');
        Contact tenant = new Contact(
            FirstName = firstName,
            LastName = lastName,
            Email = firstName.toLowerCase() + lastName.toLowerCase() + '@rentit.example.com',
            AccountId = acc.Id
        );
        insert tenant;
        return tenant;
    }


    // User creation
    public static User createPortalUser() {
        return createPortalUser('Priya', 'Tenant');
    }

    public static User createPortalUser( String firstName, String lastName ) {
        Contact tenant = createPortalContact(firstName, lastName);
        
        Profile communityProfile = [SELECT Id FROM Profile WHERE Name = 'Customer Community Plus User' LIMIT 1];

        User portalUser = new User(
            Alias = firstName.toLowerCase().substring(0, 4) + lastName.toLowerCase().substring(0, 4),
            Email = firstName.toLowerCase() + lastName.toLowerCase() + '@rentit.example.com',
            EmailEncodingKey = 'UTF-8',
            FirstName = firstName,
            LastName = lastName,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_AU',
            TimeZoneSidKey = 'Australia/Melbourne',
            ProfileId = communityProfile.Id,
            ContactId = tenant.Id,
            Username = firstName.toLowerCase() + lastName.toLowerCase() + '_loginhelpertest@rentit.com.dev',
            IsActive = true,
            CommunityNickname = firstName + lastName + 'LoginHelperTest'
        );
        insert portalUser;

        PermissionSet tenantPermSet = [SELECT Id FROM PermissionSet WHERE Name = 'RentIt_Tenant' LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = portalUser.Id, PermissionSetId = tenantPermSet.Id);

        return portalUser;
    }

    public static User createStandardUser() {
        // A user that exists in the org but holds none of the portal's
        // permission sets — proves the lookup can never resolve arbitrary
        // internal users, only actual portal members.
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User internalUser = new User(
                Alias = 'intusr',
                Email = 'internal.user.loginhelpertest@rentit.example.com',
                EmailEncodingKey = 'UTF-8',
                FirstName = 'Internal',
                LastName = 'UserLoginHelperTest',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_AU',
                TimeZoneSidKey = 'Australia/Melbourne',
                ProfileId = standardProfile.Id,
                Username = 'internal.user.loginhelpertest@rentit.com.dev',
                IsActive = true
        );
        insert internalUser;
        return internalUser;
    }
}