trigger ContractTrigger on Contract (after insert, after update) {
    ContractTriggerHandler handler = new ContractTriggerHandler();

    if (Trigger.isInsert) {
        handler.afterInsert(Trigger.new);
    }
    if (Trigger.isUpdate) {
        handler.afterUpdate(Trigger.new, Trigger.oldMap);
    }
}
