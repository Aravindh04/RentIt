trigger PaymentTrigger on Payment__c (before insert, before update, after insert, after update, after delete, after undelete) {
    PaymentTriggerHandler handler = new PaymentTriggerHandler();

    if (Trigger.isBefore) {
        if (Trigger.isInsert) handler.beforeInsert(Trigger.new);
        if (Trigger.isUpdate) handler.beforeUpdate(Trigger.new, Trigger.oldMap);
    } else {
        if (Trigger.isInsert)   handler.afterInsert(Trigger.new);
        if (Trigger.isUpdate)   handler.afterUpdate(Trigger.new, Trigger.oldMap);
        if (Trigger.isDelete)   handler.afterDelete(Trigger.old);
        if (Trigger.isUndelete) handler.afterUndelete(Trigger.new);
    }
}
