public with sharing class ContentDocumentLinkTriggerHandler {

    public void afterInsert(List<ContentDocumentLink> newLinks) {
        ContentDocumentLinkTriggerService.shareContractFilesWithTenantContacts(newLinks);
    }
}
