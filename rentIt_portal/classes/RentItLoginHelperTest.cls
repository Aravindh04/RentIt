@IsTest
private class RentItLoginHelperTest {

    @TestSetup
    static void setupData() {
        Contact tenant = new Contact(
            FirstName = 'Priya',
            LastName = 'Tenant',
            Email = 'priya.tenant@rentit.example.com'
        );
        insert tenant;

        Profile communityProfile = [SELECT Id FROM Profile WHERE Name = 'Customer Community Plus User' LIMIT 1];

        User portalUser = new User(
            Alias = 'ptenant',
            Email = 'priya.tenant@rentit.example.com',
            EmailEncodingKey = 'UTF-8',
            FirstName = 'Priya',
            LastName = 'Tenant',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles',
            ProfileId = communityProfile.Id,
            ContactId = tenant.Id,
            Username = 'priya.tenant.loginhelpertest@rentit.com.dev',
            IsActive = true,
            CommunityNickname = 'PriyaTenantLoginHelperTest'
        );
        insert portalUser;

        PermissionSet tenantPermSet = [SELECT Id FROM PermissionSet WHERE Name = 'RentIt_Tenant' LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = portalUser.Id, PermissionSetId = tenantPermSet.Id);

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
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles',
            ProfileId = standardProfile.Id,
            Username = 'internal.user.loginhelpertest@rentit.com.dev',
            IsActive = true
        );
        insert internalUser;
    }

    @IsTest
    static void test_resolveLoginIdentifier_byEmail_returnsUsername() {
        Test.startTest();
        String resolved = RentItLoginHelper.resolveLoginIdentifier('priya.tenant@rentit.example.com');
        Test.stopTest();

        Assert.areEqual(
            'priya.tenant.loginhelpertest@rentit.com.dev',
            resolved,
            'Lookup by Email should return the matching portal user\'s Username.'
        );
    }

    @IsTest
    static void test_resolveLoginIdentifier_byUsername_returnsSameUsername() {
        Test.startTest();
        String resolved = RentItLoginHelper.resolveLoginIdentifier('priya.tenant.loginhelpertest@rentit.com.dev');
        Test.stopTest();

        Assert.areEqual(
            'priya.tenant.loginhelpertest@rentit.com.dev',
            resolved,
            'Lookup by an already-valid Username should return it unchanged.'
        );
    }

    @IsTest
    static void test_resolveLoginIdentifier_unknownIdentifier_returnsUnchanged() {
        Test.startTest();
        String resolved = RentItLoginHelper.resolveLoginIdentifier('nobody.here@rentit.example.com');
        Test.stopTest();

        Assert.areEqual(
            'nobody.here@rentit.example.com',
            resolved,
            'An unmatched identifier must be returned unchanged so login fails without revealing whether it exists.'
        );
    }

    @IsTest
    static void test_resolveLoginIdentifier_nonPortalUser_returnsUnchanged() {
        Test.startTest();
        String resolved = RentItLoginHelper.resolveLoginIdentifier('internal.user.loginhelpertest@rentit.example.com');
        Test.stopTest();

        Assert.areEqual(
            'internal.user.loginhelpertest@rentit.example.com',
            resolved,
            'Users without a RentIt portal permission set must never be resolvable, even if they exist in the org.'
        );
    }

    @IsTest
    static void test_resolveLoginIdentifier_blankOrNull_returnsUnchanged() {
        Test.startTest();
        String resolvedBlank = RentItLoginHelper.resolveLoginIdentifier('   ');
        String resolvedNull = RentItLoginHelper.resolveLoginIdentifier(null);
        Test.stopTest();

        Assert.areEqual('   ', resolvedBlank, 'Blank input should be returned unchanged without querying.');
        Assert.areEqual(null, resolvedNull, 'Null input should be returned unchanged without throwing.');
    }

    @IsTest
    static void test_resolveLoginIdentifier_bulk_multipleCallsSucceed() {
        List<String> identifiers = new List<String>{
            'priya.tenant@rentit.example.com',
            'nobody1@rentit.example.com',
            'nobody2@rentit.example.com',
            'nobody3@rentit.example.com',
            'internal.user.loginhelpertest@rentit.example.com'
        };

        Test.startTest();
        List<String> resolved = new List<String>();
        for (String identifier : identifiers) {
            resolved.add(RentItLoginHelper.resolveLoginIdentifier(identifier));
        }
        Test.stopTest();

        Assert.areEqual(
            identifiers.size(),
            resolved.size(),
            'Every identifier in the batch should resolve without hitting governor limits.'
        );
        Assert.areEqual(
            'priya.tenant.loginhelpertest@rentit.com.dev',
            resolved[0],
            'The one portal match should still resolve correctly within a bulk run.'
        );
    }

    // ── login() ──────────────────────────────────────────────────────
    // Note: Site.login only performs a real authentication when invoked
    // from an actual Digital Experience guest request; in the unit test
    // execution context it cannot establish a session and effectively
    // always fails closed (returns null / throws), which login() then
    // surfaces as the generic AuraHandledException below. That failure
    // path — and the input-validation short-circuits — are what these
    // tests can verify. The real success path (valid credentials actually
    // logging a user in) must be verified manually against the deployed
    // site, since it depends on Site.login's guest-request context.

    @IsTest
    static void test_login_blankIdentifier_throwsGenericError() {
        Test.startTest();
        try {
            RentItLoginHelper.login('', 'somePassword123', '/rentitportal/');
            Assert.fail('Expected an AuraHandledException for a blank identifier.');
        } catch (AuraHandledException ex) {
            Assert.isTrue(
                ex.getMessage().contains('sign you in'),
                'A blank identifier should surface the generic sign-in error message.'
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void test_login_blankPassword_throwsGenericError() {
        Test.startTest();
        try {
            RentItLoginHelper.login('priya.tenant@rentit.example.com', '', '/rentitportal/');
            Assert.fail('Expected an AuraHandledException for a blank password.');
        } catch (AuraHandledException ex) {
            Assert.isTrue(
                ex.getMessage().contains('sign you in'),
                'A blank password should surface the generic sign-in error message.'
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void test_login_outsideSiteContext_failsClosedWithGenericError() {
        Test.startTest();
        try {
            RentItLoginHelper.login('priya.tenant@rentit.example.com', 'wrongPassword123!', '/rentitportal/');
            Assert.fail('Expected an AuraHandledException since Site.login cannot authenticate outside a live site request.');
        } catch (AuraHandledException ex) {
            Assert.isTrue(
                ex.getMessage().contains('sign you in'),
                'Any login failure must surface only the generic message, never a system exception or specific reason.'
            );
        }
        Test.stopTest();
    }
}
