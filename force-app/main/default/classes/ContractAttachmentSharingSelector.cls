public with sharing class ContractAttachmentSharingSelector {
    private ContractAttachmentSharingSelector() {
    }

    public static List<Contract> selectByContractNumber(String contractNumber) {
        return [
            SELECT Id, ContractNumber, CustomerSignedId
            FROM Contract
            WHERE ContractNumber = :contractNumber
            WITH USER_MODE
            LIMIT 1
        ];
    }

    public static List<Attachment> selectAttachmentsByContractIds(Set<Id> contractIds) {
        return [
            SELECT Id, ParentId, Name, Body, Description
            FROM Attachment
            WHERE ParentId IN :contractIds
            WITH USER_MODE
        ];
    }

    public static List<ContentVersion> selectVersionsByDescriptions(Set<String> descriptions) {
        return [
            SELECT Id, Description
            FROM ContentVersion
            WHERE Description IN :descriptions
            WITH USER_MODE
        ];
    }

    public static List<ContentDocumentLink> selectLinksByEntityIds(Set<Id> entityIds) {
        return [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :entityIds
            WITH USER_MODE
        ];
    }

    public static List<User> selectPortalUsersByContactIds(Set<Id> contactIds) {
        return [
            SELECT Id, ContactId
            FROM User
            WHERE IsPortalEnabled = TRUE
            AND ContactId IN :contactIds
            WITH USER_MODE
        ];
    }
}
