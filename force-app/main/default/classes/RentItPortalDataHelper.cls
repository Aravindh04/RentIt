/**
 * Without-sharing data helper for portal queries where Salesforce sharing rules
 * cannot cover the required object (Contract has no supported sharing path for
 * community users). Ownership is validated in user mode before any elevated
 * query runs, so tenants can only see their own data.
 */
public without sharing class RentItPortalDataHelper {

    public static Contract getContractForTenancy(Id tenancyId) {
        Integer owned = [
            SELECT COUNT() FROM Tenancy__c
            WHERE Id = :tenancyId
              AND Tenant__c IN (SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId())
            WITH USER_MODE
        ];
        if (owned == 0) return null;

        List<Contract> contracts = [
            SELECT Id, ContractNumber, Status, StartDate, EndDate,
                   Rent_Amount__c, Rent_Frequency__c,
                   Deposit_Amount__c, Special_Conditions__c
            FROM   Contract
            WHERE  Tenancy__c = :tenancyId
            ORDER BY StartDate DESC
            LIMIT  1
        ];
        return contracts.isEmpty() ? null : contracts[0];
    }

    public static List<ContentDocumentLink> getPaymentFilesForTenancy(Id paymentId, Id tenancyId) {
        Integer ownedTenancy = [
            SELECT COUNT() FROM Tenancy__c
            WHERE Id = :tenancyId
              AND Tenant__c IN (SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId())
            WITH USER_MODE
        ];
        if (ownedTenancy == 0) return new List<ContentDocumentLink>();

        Integer ownedPayment = [
            SELECT COUNT() FROM Payment__c
            WHERE Id = :paymentId AND Tenancy__c = :tenancyId
            WITH USER_MODE
        ];
        if (ownedPayment == 0) return new List<ContentDocumentLink>();

        return [
            SELECT ContentDocumentId,
                   ContentDocument.Title,
                   ContentDocument.FileType,
                   ContentDocument.ContentSize,
                   ContentDocument.LatestPublishedVersionId,
                   ContentDocument.CreatedDate
            FROM   ContentDocumentLink
            WHERE  LinkedEntityId = :paymentId
            ORDER BY ContentDocument.CreatedDate DESC
        ];
    }

    public static List<ContentDocumentLink> getContractFilesForTenancy(Id contractId, Id tenancyId) {
        Integer owned = [
            SELECT COUNT() FROM Tenancy__c
            WHERE Id = :tenancyId
              AND Tenant__c IN (SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId())
            WITH USER_MODE
        ];
        if (owned == 0) return new List<ContentDocumentLink>();

        return [
            SELECT ContentDocumentId,
                   ContentDocument.Title,
                   ContentDocument.FileType,
                   ContentDocument.ContentSize,
                   ContentDocument.LatestPublishedVersionId,
                   ContentDocument.CreatedDate
            FROM   ContentDocumentLink
            WHERE  LinkedEntityId = :contractId
            ORDER BY ContentDocument.CreatedDate DESC
        ];
    }
}
