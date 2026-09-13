@IsTest
private class ContactCommunityUserServiceTest {
    @IsTest
    static void testCreateCommunityUserForContact() {
        User adminuser = TestdataFactory.createAdminUser();
        System.runAs(adminuser){
            TestdataFactory.createPortalContact('Ava', 'Tenant');
        }
        
        Contact tenant = [SELECT Id, Owner.UserRole.Name, FirstName, LastName, Email FROM Contact LIMIT 1];

        Test.startTest();
        ContactCommunityUserService.Request req = new ContactCommunityUserService.Request();
        req.contactId = tenant.Id;
        List<ContactCommunityUserService.Result> results = ContactCommunityUserService.createCommunityUsers(
            new List<ContactCommunityUserService.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'One user result should be returned.');
        System.assertEquals(true, results[0].created, 'User should be created.');
        System.assertEquals(null, results[0].userId, 'User Id should not be populated as the user creation is queued and not immediate.');

        User createdUser = [
            SELECT Id, Username, Profile.Name, ContactId
            FROM User
            WHERE Firstname = 'Ava' AND LastName = 'Tenant'
            LIMIT 1
        ];

        System.assertEquals(tenant.Id, createdUser.ContactId, 'User should be linked to the Contact.');
        System.assertEquals('Customer Community Plus User', createdUser.Profile.Name, 'Profile should be the Customer Community Plus User profile.');
        System.assertEquals('ava.tenant@rentit.com', createdUser.Username, 'Username should match expected pattern.');
    }
}
