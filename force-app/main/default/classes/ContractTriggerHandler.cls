public with sharing class ContractTriggerHandler {
    public void afterInsert(List<Contract> newContracts) {
        ContractAttachmentSharingService.shareContractAttachments(newContracts);
    }

    public void afterUpdate(List<Contract> newContracts, Map<Id, Contract> oldMap) {
        ContractAttachmentSharingService.shareContractAttachments(newContracts);
    }
}
