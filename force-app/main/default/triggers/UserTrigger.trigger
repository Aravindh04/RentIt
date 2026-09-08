trigger UserTrigger on User (after insert) {
    UserTriggerHandler handler = new UserTriggerHandler();
    if (Trigger.isAfter && Trigger.isInsert) {
        handler.afterInsert(Trigger.new);
    }
}
