@IsTest
private class ContractTriggerHandlerTest {
    @IsTest
    static void test_contractTrigger_bulkUpdateMigratesAndSharesAttachments() {
        Account accountRecord = new Account(Name = 'Handler Test Account');
        insert accountRecord;

        List<Contact> contacts = new List<Contact>{
            new Contact(
                AccountId = accountRecord.Id,
                FirstName = 'Handler',
                LastName = 'One',
                Email = 'handler.one@example.com'
            ),
            new Contact(
                AccountId = accountRecord.Id,
                FirstName = 'Handler',
                LastName = 'Two',
                Email = 'handler.two@example.com'
            )
        };
        insert contacts;

        List<Contract> contracts = new List<Contract>{
            createContract(accountRecord.Id, contacts[0].Id),
            createContract(accountRecord.Id, contacts[1].Id)
        };
        insert contracts;
        List<User> portalUsers = createPortalUsers(contacts);

        List<Attachment> attachments = new List<Attachment>{
            new Attachment(
                ParentId = contracts[0].Id,
                Name = 'bulk-one.txt',
                Body = Blob.valueOf('bulk one')
            ),
            new Attachment(
                ParentId = contracts[1].Id,
                Name = 'bulk-two.txt',
                Body = Blob.valueOf('bulk two')
            )
        };
        insert attachments;

        Test.startTest();
        for (Contract contractRecord : contracts) {
            contractRecord.Description = 'Updated by bulk test';
        }
        update contracts;
        Test.stopTest();

        Set<Id> attachmentIds = new Map<Id, Attachment>(attachments).keySet();
        List<ContentVersion> migratedVersions = [
            SELECT Id, ContentDocumentId, Description
            FROM ContentVersion
            WHERE Description LIKE 'Migrated from Attachment:%'
        ];
        Assert.areEqual(2, migratedVersions.size(), 'The bulk Contract update should migrate both Attachments.');

        Set<Id> portalUserIds = new Map<Id, User>(portalUsers).keySet();
        Assert.areEqual(2, portalUserIds.size(), 'The test should create two related portal Users.');
        Assert.areEqual(2, attachmentIds.size(), 'The test should create two Contract Attachments.');

        Set<Id> documentIds = new Set<Id>();
        for (ContentVersion contentVersion : migratedVersions) {
            documentIds.add(contentVersion.ContentDocumentId);
        }

        Assert.areEqual(
            2,
            [
                SELECT COUNT()
                FROM ContentDocumentLink
                WHERE ContentDocumentId IN :documentIds
                AND LinkedEntityId IN :portalUserIds
            ],
            'Each migrated File should be shared with its related Contact.'
        );
    }

    @IsTest
    static void test_afterUpdate_contactChangeSharesExistingFile() {
        Account accountRecord = new Account(Name = 'Contact Change Account');
        insert accountRecord;

        Contact originalContact = new Contact(
            AccountId = accountRecord.Id,
            FirstName = 'Original',
            LastName = 'Contact',
            Email = 'original@example.com'
        );
        Contact replacementContact = new Contact(
            AccountId = accountRecord.Id,
            FirstName = 'Replacement',
            LastName = 'Contact',
            Email = 'replacement@example.com'
        );
        insert new List<Contact>{originalContact, replacementContact};
        List<User> portalUsers = createPortalUsers(new List<Contact>{originalContact, replacementContact});

        Contract contractRecord = createContract(accountRecord.Id, originalContact.Id);
        insert contractRecord;

        ContentVersion contentVersion = new ContentVersion(
            Title = 'Existing File',
            PathOnClient = 'existing.pdf',
            VersionData = Blob.valueOf('existing content')
        );
        insert contentVersion;
        Id contentDocumentId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :contentVersion.Id
        ].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = contentDocumentId,
            LinkedEntityId = contractRecord.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        Test.startTest();
        contractRecord.CustomerSignedId = replacementContact.Id;
        update contractRecord;
        Test.stopTest();

        Assert.areEqual(
            1,
            [
                SELECT COUNT()
                FROM ContentDocumentLink
                WHERE ContentDocumentId = :contentDocumentId
                AND LinkedEntityId = :portalUsers[1].Id
            ],
            'An existing Contract File should be shared with the replacement Contact.'
        );
    }

    private static Contract createContract(Id accountId, Id contactId) {
        return new Contract(
            AccountId = accountId,
            Status = 'Draft',
            StartDate = Date.today(),
            ContractTerm = 12,
            CustomerSignedId = contactId,
            CustomerSignedDate = Date.today()
        );
    }

    private static List<User> createPortalUsers(List<Contact> contacts) {
        Profile portalProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Customer Community Plus User'
            LIMIT 1
        ];
        List<User> portalUsers = new List<User>();
        for (Integer index = 0; index < contacts.size(); index++) {
            portalUsers.add(new User(
                Alias = 'hdlusr' + index,
                Email = 'handler.user' + index + '@example.com',
                EmailEncodingKey = 'UTF-8',
                FirstName = 'Handler',
                LastName = 'Portal User ' + index,
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                TimeZoneSidKey = 'America/Los_Angeles',
                ProfileId = portalProfile.Id,
                ContactId = contacts[index].Id,
                Username = 'handler.user' + index + '.' + String.valueOf(Math.random()).left(8) + '@example.com',
                CommunityNickname = 'handler' + index + String.valueOf(Math.random()).left(8)
            ));
        }
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert portalUsers;
        }
        return portalUsers;
    }
}
