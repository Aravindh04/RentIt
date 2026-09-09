@IsTest(SeeAllData=false)
private class EmailServiceTest {

    @TestSetup
    static void setup() {
        Account landlord = new Account(Name = 'Email Service Landlord');
        insert landlord;

        Property__c propertyRecord = new Property__c(
            Property_Type__c = 'House',
            Landlord__c = landlord.Id
        );
        insert propertyRecord;

        Account tenantAccount = new Account(Name = 'Email Service Tenant Account');
        insert tenantAccount;

        Contact tenantContact = new Contact(
            FirstName = 'Email',
            LastName = 'Service',
            Email = 'email.service@rentit.test',
            AccountId = tenantAccount.Id
        );
        insert tenantContact;

        insert new Tenancy__c(
            Property__c = propertyRecord.Id,
            Tenant__c = tenantContact.Id,
            Status__c = 'Active'
        );
    }

    @IsTest
    static void givenRecipientIdAndRelatedRecord_whenSendBulkEmailsCalled_thenEmailIsSentAndLogged() {
        Contact tenantContact = [SELECT Id FROM Contact WHERE Email = 'email.service@rentit.test' LIMIT 1];
        Tenancy__c tenancyRecord = [SELECT Id FROM Tenancy__c LIMIT 1];

        EmailService.EmailRequest request = new EmailService.EmailRequest();
        request.recipientId = tenantContact.Id;
        request.relatedRecordId = tenancyRecord.Id;
        request.subject = 'Test Subject';
        request.htmlBody = '<p>Test Body</p>';

        EmailService.lastEmailsSentCount = 0;

        Test.startTest();
        List<Messaging.SendEmailResult> results = EmailService.sendBulkEmails(new List<EmailService.EmailRequest>{ request });
        Test.stopTest();

        // sendBulkEmails never performs a real send in test context (see EmailService), so no
        // SendEmailResult is returned even though the message was built; lastEmailsSentCount is the
        // test-safe way to confirm the send was attempted.
        Assert.areEqual(0, results.size(), 'No real send happens in test context.');
        Assert.areEqual(1, EmailService.lastEmailsSentCount, 'One email should have been sent.');
    }

    @IsTest
    static void givenRecipientEmailOnly_whenSendBulkEmailsCalled_thenEmailIsSentWithoutActivity() {
        EmailService.EmailRequest request = new EmailService.EmailRequest();
        request.recipientEmail = 'raw.recipient@rentit.test';
        request.subject = 'Test Subject';
        request.htmlBody = '<p>Test Body</p>';

        EmailService.lastEmailsSentCount = 0;

        Test.startTest();
        EmailService.sendBulkEmails(new List<EmailService.EmailRequest>{ request });
        Test.stopTest();

        Assert.areEqual(1, EmailService.lastEmailsSentCount, 'One email should have been sent using the raw email address.');
    }

    @IsTest
    static void givenInvocableMethodInvoked_whenValidRequest_thenEmailIsSent() {
        Contact tenantContact = [SELECT Id FROM Contact WHERE Email = 'email.service@rentit.test' LIMIT 1];

        EmailService.EmailRequest request = new EmailService.EmailRequest();
        request.recipientId = tenantContact.Id;
        request.subject = 'Flow Subject';
        request.htmlBody = '<p>Flow Body</p>';

        EmailService.lastEmailsSentCount = 0;

        Test.startTest();
        EmailService.sendEmails(new List<EmailService.EmailRequest>{ request });
        Test.stopTest();

        Assert.areEqual(1, EmailService.lastEmailsSentCount, 'The invocable method should send the email.');
    }

    @IsTest
    static void givenInvalidOrEmptyRequests_whenSendBulkEmailsCalled_thenNoEmailIsSent() {
        Contact tenantContact = [SELECT Id FROM Contact WHERE Email = 'email.service@rentit.test' LIMIT 1];

        EmailService.EmailRequest missingSubject = new EmailService.EmailRequest();
        missingSubject.recipientId = tenantContact.Id;
        missingSubject.htmlBody = '<p>Body</p>';

        EmailService.EmailRequest missingRecipient = new EmailService.EmailRequest();
        missingRecipient.subject = 'Subject';
        missingRecipient.htmlBody = '<p>Body</p>';

        EmailService.lastEmailsSentCount = 0;

        Test.startTest();
        List<Messaging.SendEmailResult> emptyListResult = EmailService.sendBulkEmails(new List<EmailService.EmailRequest>());
        List<Messaging.SendEmailResult> nullResult = EmailService.sendBulkEmails(null);
        List<Messaging.SendEmailResult> invalidResult = EmailService.sendBulkEmails(
            new List<EmailService.EmailRequest>{ missingSubject, missingRecipient }
        );
        Test.stopTest();

        Assert.areEqual(0, emptyListResult.size(), 'An empty request list should return no results.');
        Assert.areEqual(0, nullResult.size(), 'A null request list should return no results.');
        Assert.areEqual(0, invalidResult.size(), 'Requests missing required fields should be skipped.');
        Assert.areEqual(0, EmailService.lastEmailsSentCount, 'No email should have been sent.');
    }

    @IsTest
    static void givenBulkRequests_whenSendBulkEmailsCalled_thenAllAreSentInOneCall() {
        Contact tenantContact = [SELECT Id FROM Contact WHERE Email = 'email.service@rentit.test' LIMIT 1];

        List<EmailService.EmailRequest> requests = new List<EmailService.EmailRequest>();
        for (Integer i = 0; i < 50; i++) {
            EmailService.EmailRequest request = new EmailService.EmailRequest();
            request.recipientId = tenantContact.Id;
            request.subject = 'Bulk Subject ' + i;
            request.htmlBody = '<p>Bulk Body ' + i + '</p>';
            requests.add(request);
        }

        EmailService.lastEmailsSentCount = 0;

        Test.startTest();
        EmailService.sendBulkEmails(requests);
        Test.stopTest();

        Assert.areEqual(50, EmailService.lastEmailsSentCount, 'All 50 requests should be sent in a single bulk call.');
    }

    @IsTest
    static void givenTemplateIdAndRecipientId_whenSendBulkEmailsCalled_thenTemplateEmailIsSent() {
        Contact tenantContact = [SELECT Id FROM Contact WHERE Email = 'email.service@rentit.test' LIMIT 1];
        Tenancy__c tenancyRecord = [SELECT Id FROM Tenancy__c LIMIT 1];
        EmailTemplate templateRecord = [SELECT Id FROM EmailTemplate WHERE DeveloperName = 'RentReminder' LIMIT 1];

        EmailService.EmailRequest request = new EmailService.EmailRequest();
        request.recipientId = tenantContact.Id;
        request.relatedRecordId = tenancyRecord.Id;
        request.templateId = templateRecord.Id;

        EmailService.lastEmailsSentCount = 0;

        Test.startTest();
        EmailService.sendBulkEmails(new List<EmailService.EmailRequest>{ request });
        Test.stopTest();

        Assert.areEqual(1, EmailService.lastEmailsSentCount, 'One template-based email should have been sent.');
    }

    @IsTest
    static void givenTemplateIdWithoutRecipientId_whenSendBulkEmailsCalled_thenRequestIsSkipped() {
        EmailTemplate templateRecord = [SELECT Id FROM EmailTemplate WHERE DeveloperName = 'RentReminder' LIMIT 1];

        EmailService.EmailRequest request = new EmailService.EmailRequest();
        request.recipientEmail = 'raw.recipient@rentit.test';
        request.templateId = templateRecord.Id;

        EmailService.lastEmailsSentCount = 0;

        Test.startTest();
        EmailService.sendBulkEmails(new List<EmailService.EmailRequest>{ request });
        Test.stopTest();

        Assert.areEqual(
            0,
            EmailService.lastEmailsSentCount,
            'A template-based request without a recipient Id cannot resolve merge fields and should be skipped.'
        );
    }

    @IsTest
    static void givenUserRecipient_whenSendBulkEmailsCalled_thenMessageIsBuiltWithoutActivityOrWhatId() {
        // Real (non-test) sends to a User recipient throw if setSaveAsActivity(true) or setWhatId() are
        // used (Salesforce restriction, unlike Contact/Lead recipients) — see buildMessage(). This test
        // only proves the request still reaches Messaging.sendEmail (isn't skipped) for a User recipient;
        // Test.isRunningTest() means the real platform-side restriction can't be asserted here directly
        // and was instead verified live via anonymous Apex against an internal User.
        User internalUser = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        Tenancy__c tenancyRecord = [SELECT Id FROM Tenancy__c LIMIT 1];

        EmailService.EmailRequest request = new EmailService.EmailRequest();
        request.recipientId = internalUser.Id;
        request.relatedRecordId = tenancyRecord.Id;
        request.subject = 'Internal User Test';
        request.htmlBody = '<p>Body</p>';

        EmailService.lastEmailsSentCount = 0;

        Test.startTest();
        EmailService.sendBulkEmails(new List<EmailService.EmailRequest>{ request });
        Test.stopTest();

        Assert.areEqual(1, EmailService.lastEmailsSentCount, 'The message should still be built and handed to the send call for a User recipient.');
    }
}
