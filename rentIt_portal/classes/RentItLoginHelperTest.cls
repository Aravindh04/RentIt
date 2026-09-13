@IsTest
private class RentItLoginHelperTest {

    @TestSetup
    static void setupData() {
        User adminUser = TestDataFactory.createAdminUser();

        System.runAs(adminUser) {
            TestDataFactory.createPortalUser(); // Creates a portal user with a contact and account.
            TestDataFactory.createStandardUser(); // Creates a standard user for testing.
        }
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
