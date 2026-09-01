trigger UserTrigger on User (after insert) {
    List<Id> newCommunityUserIds = new List<Id>();
    for (User u : Trigger.new) {
        if (u.ContactId != null && u.UserType != 'Standard') {
            newCommunityUserIds.add(u.Id);
        }
    }
    if (!newCommunityUserIds.isEmpty()) {
        System.enqueueJob(new TenantProvisioningQueueable(newCommunityUserIds));
    }
}
