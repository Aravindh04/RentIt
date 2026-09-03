@IsTest
private class ContractAttachmentSharingServiceTest {
    @IsTest
    static void test_shareContractAttachments_migratesAttachmentAndPreventsDuplicates() {
        TestData data = createTestData();
        User portalUser = createPortalUser(data.contactRecord, 'service');
        Attachment attachment = new Attachment(
            ParentId = data.contractRecord.Id,
            Name = 'lease.txt',
            Body = Blob.valueOf('lease content')
        );
        insert attachment;

        Test.startTest();
        ContractAttachmentSharingService.shareContractAttachments(new List<Contract>{data.contractRecord});
        ContractAttachmentSharingService.shareContractAttachments(new List<Contract>{data.contractRecord});
        Test.stopTest();

        String marker = 'Migrated from Attachment: ' + attachment.Id;
        List<ContentVersion> migratedVersions = [
            SELECT Id, ContentDocumentId, Title, Description
            FROM ContentVersion
            WHERE Description = :marker
        ];
        Assert.areEqual(1, migratedVersions.size(), 'The Attachment should be migrated only once.');
        Assert.areEqual('lease.txt', migratedVersions[0].Title, 'The migrated File should retain the Attachment name.');

        List<ContentDocumentLink> userLinks = [
            SELECT Id, ContentDocumentId, LinkedEntityId, ShareType, Visibility
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :migratedVersions[0].ContentDocumentId
            AND LinkedEntityId = :portalUser.Id
        ];
        Assert.areEqual(1, userLinks.size(), 'The File should have one portal User link.');
        Assert.areEqual('V', userLinks[0].ShareType, 'The portal User link should provide Viewer access.');
        Assert.areEqual('AllUsers', userLinks[0].Visibility, 'The File should be visible to external users.');
    }

    @IsTest
    static void test_shareContractAttachments_sharesExistingFile() {
        TestData data = createTestData();
        User portalUser = createPortalUser(data.contactRecord, 'existing');
        ContentVersion contentVersion = new ContentVersion(
            Title = 'Existing Contract File',
            PathOnClient = 'existing.pdf',
            VersionData = Blob.valueOf('existing file content')
        );
        insert contentVersion;

        Id contentDocumentId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :contentVersion.Id
        ].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = contentDocumentId,
            LinkedEntityId = data.contractRecord.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        Test.startTest();
        ContractAttachmentSharingService.shareContractAttachments(new List<Contract>{data.contractRecord});
        Test.stopTest();

        Assert.areEqual(
            1,
            [
                SELECT COUNT()
                FROM ContentDocumentLink
                WHERE ContentDocumentId = :contentDocumentId
                AND LinkedEntityId = :portalUser.Id
            ],
            'An existing Contract File should be shared with the Contact.'
        );
    }

    @IsTest
    static void test_shareContractAttachments_ignoresEmptyAndMissingContactInputs() {
        Test.startTest();
        ContractAttachmentSharingService.shareContractAttachments(null);
        ContractAttachmentSharingService.shareContractAttachments(new List<Contract>());
        ContractAttachmentSharingService.shareContractAttachments(new List<Contract>{new Contract()});
        Test.stopTest();

        Assert.isTrue(true, 'Empty and Contact-less inputs should complete without errors.');
    }

    private static TestData createTestData() {
        Account accountRecord = new Account(Name = 'Service Test Account');
        insert accountRecord;

        Contact contactRecord = new Contact(
            AccountId = accountRecord.Id,
            FirstName = 'Service',
            LastName = 'Contact',
            Email = 'service@example.com'
        );
        insert contactRecord;

        Contract contractRecord = new Contract(
            AccountId = accountRecord.Id,
            Status = 'Draft',
            StartDate = Date.today(),
            ContractTerm = 12,
            CustomerSignedId = contactRecord.Id,
            CustomerSignedDate = Date.today()
        );
        insert contractRecord;

        TestData data = new TestData();
        data.contactRecord = contactRecord;
        data.contractRecord = contractRecord;
        return data;
    }

    private static User createPortalUser(Contact contactRecord, String nameSuffix) {
        Profile portalProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Customer Community Plus User'
            LIMIT 1
        ];
        User portalUser = new User(
            Alias = 'svcuser',
            Email = 'service.' + nameSuffix + '@example.com',
            EmailEncodingKey = 'UTF-8',
            FirstName = 'Service',
            LastName = 'Portal User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles',
            ProfileId = portalProfile.Id,
            ContactId = contactRecord.Id,
            Username = 'service.' + nameSuffix + '.' + String.valueOf(Math.random()).left(8) + '@example.com',
            CommunityNickname = 'service' + nameSuffix + String.valueOf(Math.random()).left(8)
        );
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert portalUser;
        }
        return portalUser;
    }

    private class TestData {
        private Contact contactRecord;
        private Contract contractRecord;
    }
}
