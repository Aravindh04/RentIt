public with sharing class UserTriggerService {

    private UserTriggerService() {
    }

    public static void provisionTenantUsers(List<User> newUsers) {
        if (newUsers == null || newUsers.isEmpty()) {
            return;
        }

        Set<Id> userIds = new Set<Id>();
        for (User userRecord : newUsers) {
            if (userRecord != null && userRecord.ContactId != null && userRecord.UserType != 'Standard') {
                userIds.add(userRecord.Id);
            }
        }

        if (userIds.isEmpty()) {
            return;
        }

        List<Id> communityUserIds = new List<Id>();
        for (User userRecord : UserTriggerSelector.selectUsersByIds(userIds).values()) {
            if (userRecord.ContactId != null && userRecord.UserType != 'Standard') {
                communityUserIds.add(userRecord.Id);
            }
        }

        if (!communityUserIds.isEmpty()) {
            System.enqueueJob(new TenantProvisioningQueueable(communityUserIds));
        }
    }
}
