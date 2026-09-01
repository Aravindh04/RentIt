@IsTest
private class ContactCommunityUserServiceTest {
    @IsTest
    static void testCreateCommunityUserForContact() {
        Contact tenant = new Contact(
            FirstName = 'Ava',
            LastName = 'Tenant',
            Email = 'ava.tenant@rentit.example.com',
            MailingStreet = '1 Test Street',
            MailingCity = 'Sydney',
            MailingState = 'NSW',
            MailingPostalCode = '2000',
            MailingCountry = 'Australia'
        );
        insert tenant;

        Test.startTest();
        ContactCommunityUserService.Request req = new ContactCommunityUserService.Request();
        req.contactId = tenant.Id;
        List<ContactCommunityUserService.Result> results = ContactCommunityUserService.createCommunityUsers(
            new List<ContactCommunityUserService.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'One user result should be returned.');
        System.assertEquals(true, results[0].created, 'User should be created.');
        System.assertNotEquals(null, results[0].userId, 'User Id should be populated.');

        User createdUser = [
            SELECT Id, Username, Profile.Name, ContactId
            FROM User
            WHERE Id = :results[0].userId
            LIMIT 1
        ];

        System.assertEquals(tenant.Id, createdUser.ContactId, 'User should be linked to the Contact.');
        System.assertEquals('Customer Community Plus User', createdUser.Profile.Name, 'Profile should be the Customer Community Plus User profile.');
        System.assertEquals('Ava.Tenant@rentit.com.dev', createdUser.Username, 'Username should match expected pattern.');
    }
}
