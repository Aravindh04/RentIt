@IsTest
private class ContentDocumentLinkTriggerHandlerTest {

    @IsTest
    static void contractFile_sharedToTenantContact() {
        Account landlord = new Account(Name = 'Landlord Corp');
        insert landlord;

        Property__c propertyRecord = new Property__c(
            Property_Type__c = 'House',
            Landlord__c = landlord.Id
        );
        insert propertyRecord;

        Account tenantAccount = new Account(Name = 'Tenant Account');
        insert tenantAccount;

        Contact tenantContact = new Contact(
            AccountId = tenantAccount.Id,
            FirstName = 'Test',
            LastName = 'Tenant',
            Email = 'tenant@example.com'
        );
        insert tenantContact;

        Tenancy__c tenancy = new Tenancy__c(
            Property__c = propertyRecord.Id,
            Tenant__c = tenantContact.Id,
            Status__c = 'Active'
        );
        insert tenancy;

        Contract contractRecord = new Contract(
            AccountId = tenantAccount.Id,
            Tenancy__c = tenancy.Id,
            Status = 'Draft',
            StartDate = Date.today(),
            ContractTerm = 12,
            CustomerSignedId = tenantContact.Id,
            CustomerSignedDate = Date.today()
        );
        insert contractRecord;

        ContentVersion contentVersion = new ContentVersion(
            Title = 'Contract Document',
            PathOnClient = 'contract-document.pdf',
            VersionData = Blob.valueOf('contract file content')
        );
        insert contentVersion;

        Id contentDocumentId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :contentVersion.Id
            LIMIT 1
        ].ContentDocumentId;

        Test.startTest();
        insert new ContentDocumentLink(
            ContentDocumentId = contentDocumentId,
            LinkedEntityId = contractRecord.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        Test.stopTest();

        List<ContentDocumentLink> tenantLinks = [
            SELECT Id, LinkedEntityId, ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :tenantContact.Id
              AND ContentDocumentId = :contentDocumentId
        ];

        System.assertEquals(1, tenantLinks.size(),
            'The tenant Contact should receive a shared link to the contract file.');
    }
}
