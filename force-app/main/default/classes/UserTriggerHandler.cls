public with sharing class UserTriggerHandler {

    public void afterInsert(List<User> newUsers) {
        UserTriggerService.provisionTenantUsers(newUsers);
    }
}
