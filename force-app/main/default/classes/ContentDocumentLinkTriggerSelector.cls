public with sharing class ContentDocumentLinkTriggerSelector {

    private ContentDocumentLinkTriggerSelector() {
    }

    public static List<Contract> selectContractsByIds(Set<Id> contractIds) {
        if (contractIds == null || contractIds.isEmpty()) {
            return new List<Contract>();
        }

        return [
            SELECT Id, Tenancy__r.Tenant__c
            FROM Contract
            WHERE Id IN :contractIds
        ];
    }

    public static List<ContentDocumentLink> selectLinksByEntityAndDocumentIds(Set<Id> entityIds, Set<Id> contentDocumentIds) {
        if (entityIds == null || entityIds.isEmpty() || contentDocumentIds == null || contentDocumentIds.isEmpty()) {
            return new List<ContentDocumentLink>();
        }

        return [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :entityIds
              AND ContentDocumentId IN :contentDocumentIds
        ];
    }

    public static List<User> selectPortalUsersByContactIds(Set<Id> contactIds) {
        if (contactIds == null || contactIds.isEmpty()) {
            return new List<User>();
        }

        return [
            SELECT Id, ContactId
            FROM User
            WHERE IsPortalEnabled = TRUE
              AND ContactId IN :contactIds
        ];
    }
}
