public without sharing class ContentDocumentLinkTriggerHandler {

    public static void shareContractFilesWithTenantContacts(List<ContentDocumentLink> newLinks) {
        if (newLinks == null || newLinks.isEmpty()) {
            return;
        }

        Set<Id> contractIds = new Set<Id>();
        for (ContentDocumentLink link : newLinks) {
            if (link != null && link.ContentDocumentId != null && link.LinkedEntityId != null
                    && link.LinkedEntityId.getSObjectType() == Contract.SObjectType) {
                contractIds.add(link.LinkedEntityId);
            }
        }

        if (contractIds.isEmpty()) {
            return;
        }

        Map<Id, Id> tenantContactByContractId = new Map<Id, Id>();
        for (Contract contractRecord : [
            SELECT Id, Tenancy__c, Tenancy__r.Tenant__c
            FROM Contract
            WHERE Id IN :contractIds
        ]) {
            if (contractRecord.Tenancy__r != null && contractRecord.Tenancy__r.Tenant__c != null) {
                tenantContactByContractId.put(contractRecord.Id, contractRecord.Tenancy__r.Tenant__c);
            }
        }

        if (tenantContactByContractId.isEmpty()) {
            return;
        }

        Set<Id> tenantContactIds = new Set<Id>(tenantContactByContractId.values());
        Set<Id> contentDocumentIds = new Set<Id>();
        for (ContentDocumentLink link : newLinks) {
            if (tenantContactByContractId.containsKey(link.LinkedEntityId) && link.ContentDocumentId != null) {
                contentDocumentIds.add(link.ContentDocumentId);
            }
        }

        if (contentDocumentIds.isEmpty()) {
            return;
        }

        Set<String> existingLinkKeys = new Set<String>();
        for (ContentDocumentLink existingLink : [
            SELECT LinkedEntityId, ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :tenantContactIds
              AND ContentDocumentId IN :contentDocumentIds
        ]) {
            existingLinkKeys.add(String.valueOf(existingLink.LinkedEntityId) + ':' + String.valueOf(existingLink.ContentDocumentId));
        }

        List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();
        for (ContentDocumentLink link : newLinks) {
            if (link == null || link.ContentDocumentId == null || link.LinkedEntityId == null) {
                continue;
            }

            Id tenantContactId = tenantContactByContractId.get(link.LinkedEntityId);
            if (tenantContactId == null) {
                continue;
            }

            String linkKey = String.valueOf(tenantContactId) + ':' + String.valueOf(link.ContentDocumentId);
            if (existingLinkKeys.contains(linkKey)) {
                continue;
            }

            linksToInsert.add(new ContentDocumentLink(
                ContentDocumentId = link.ContentDocumentId,
                LinkedEntityId = tenantContactId,
                ShareType = 'V',
                Visibility = 'AllUsers'
            ));
        }

        if (!linksToInsert.isEmpty()) {
            insert linksToInsert;
        }
    }
}
