public with sharing class UserTriggerSelector {

    private UserTriggerSelector() {
    }

    public static Map<Id, User> selectUsersByIds(Set<Id> userIds) {
        if (userIds == null || userIds.isEmpty()) {
            return new Map<Id, User>();
        }

        return new Map<Id, User>([
            SELECT Id, ContactId, UserType
            FROM User
            WHERE Id IN :userIds
        ]);
    }
}
