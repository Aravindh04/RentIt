@IsTest
public class ContractAttachmentSharingSelectorTest {
    @IsTest
    static void test_selectors_returnContractFilesAndLinks() {
        Account accountRecord = new Account(Name = 'Selector Test Account');
        insert accountRecord;

        Contact contactRecord = new Contact(
            AccountId = accountRecord.Id,
            FirstName = 'Selector',
            LastName = 'Contact',
            Email = 'selector@example.com'
        );
        insert contactRecord;
        User portalUser = createPortalUser(contactRecord, 'selector');

        Contract contractRecord = createContract(accountRecord.Id, contactRecord.Id);
        insert contractRecord;
        contractRecord = [
            SELECT Id, ContractNumber
            FROM Contract
            WHERE Id = :contractRecord.Id
        ];

        Attachment attachment = new Attachment(
            ParentId = contractRecord.Id,
            Name = 'selector.txt',
            Body = Blob.valueOf('selector content')
        );
        insert attachment;

        ContentVersion contentVersion = new ContentVersion(
            Title = 'Selector File',
            PathOnClient = 'selector.pdf',
            VersionData = Blob.valueOf('file content'),
            Description = 'selector description'
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
        List<Contract> contracts = ContractAttachmentSharingSelector.selectByContractNumber(
            contractRecord.ContractNumber
        );
        List<Attachment> attachments = ContractAttachmentSharingSelector.selectAttachmentsByContractIds(
            new Set<Id>{contractRecord.Id}
        );
        List<ContentVersion> versions = ContractAttachmentSharingSelector.selectVersionsByDescriptions(
            new Set<String>{'selector description'}
        );
        List<ContentDocumentLink> links = ContractAttachmentSharingSelector.selectLinksByEntityIds(
            new Set<Id>{contractRecord.Id}
        );
        List<User> portalUsers = ContractAttachmentSharingSelector.selectPortalUsersByContactIds(
            new Set<Id>{contactRecord.Id}
        );
        Test.stopTest();

        Assert.areEqual(1, contracts.size(), 'The Contract selector should return one Contract.');
        Assert.areEqual(contractRecord.Id, contracts[0].Id, 'The Contract selector returned the wrong record.');
        Assert.areEqual(1, attachments.size(), 'The Attachment selector should return the Contract Attachment.');
        Assert.areEqual(1, versions.size(), 'The ContentVersion selector should return the matching File.');
        Assert.areEqual(1, links.size(), 'The link selector should return the Contract File link.');
        Assert.areEqual(1, portalUsers.size(), 'The User selector should return the portal User.');
        Assert.areEqual(portalUser.Id, portalUsers[0].Id, 'The User selector returned the wrong portal User.');
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

    private static User createPortalUser(Contact contactRecord, String nameSuffix) {
        Profile portalProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Customer Community Plus User'
            LIMIT 1
        ];
        User portalUser = new User(
            Alias = 'seluser',
            Email = 'selector.user@example.com',
            EmailEncodingKey = 'UTF-8',
            FirstName = 'Selector',
            LastName = 'Portal User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles',
            ProfileId = portalProfile.Id,
            ContactId = contactRecord.Id,
            Username = 'selector.user.' + nameSuffix + '.' + String.valueOf(Math.random()).left(8) + '@example.com',
            CommunityNickname = 'selector' + nameSuffix + String.valueOf(Math.random()).left(8)
        );
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert portalUser;
        }
        return portalUser;
    }
}
