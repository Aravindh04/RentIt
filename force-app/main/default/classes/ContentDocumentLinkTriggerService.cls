public without sharing class ContentDocumentLinkTriggerService {

    private static final String FILE_SHARE_TYPE = 'V';
    private static final String FILE_VISIBILITY = 'AllUsers';

    private ContentDocumentLinkTriggerService() {
    }

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
        for (Contract contractRecord : ContentDocumentLinkTriggerSelector.selectContractsByIds(contractIds)) {
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
        for (ContentDocumentLink existingLink : ContentDocumentLinkTriggerSelector.selectLinksByEntityAndDocumentIds(
            tenantContactIds,
            contentDocumentIds
        )) {
            existingLinkKeys.add(buildLinkKey(existingLink.ContentDocumentId, existingLink.LinkedEntityId));
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

            String linkKey = buildLinkKey(link.ContentDocumentId, tenantContactId);
            if (existingLinkKeys.contains(linkKey)) {
                continue;
            }

            linksToInsert.add(new ContentDocumentLink(
                ContentDocumentId = link.ContentDocumentId,
                LinkedEntityId = tenantContactId,
                ShareType = FILE_SHARE_TYPE,
                Visibility = FILE_VISIBILITY
            ));
            existingLinkKeys.add(linkKey);
        }

        if (!linksToInsert.isEmpty()) {
            insert linksToInsert;
        }
    }

    private static String buildLinkKey(Id contentDocumentId, Id linkedEntityId) {
        return String.valueOf(contentDocumentId) + ':' + String.valueOf(linkedEntityId);
    }
}
