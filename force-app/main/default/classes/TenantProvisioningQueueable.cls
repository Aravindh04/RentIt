public class TenantProvisioningQueueable implements Queueable {

    private List<Id> userIds;

    public TenantProvisioningQueueable(List<Id> userIds) {
        this.userIds = userIds;
    }

    public void execute(QueueableContext context) {
        // Re-query users to get ContactId (may have been stripped in trigger context)
        Map<Id, User> users = new Map<Id, User>([
            SELECT Id, ContactId
            FROM   User
            WHERE  Id IN :userIds
              AND  ContactId != null
        ]);
        if (users.isEmpty()) return;

        // Check which contacts have an active tenancy
        Set<Id> contactIds = new Set<Id>();
        for (User u : users.values()) contactIds.add(u.ContactId);

        Set<Id> tenantContactIds = new Set<Id>();
        for (Tenancy__c t : [
            SELECT Tenant__c
            FROM   Tenancy__c
            WHERE  Tenant__c IN :contactIds
              AND  Status__c  = 'Active'
        ]) {
            tenantContactIds.add(t.Tenant__c);
        }
        if (tenantContactIds.isEmpty()) return;

        // Resolve permission set and group IDs
        List<PermissionSet> psList = [
            SELECT Id FROM PermissionSet WHERE Name = 'RentIt_Tenant' LIMIT 1
        ];
        List<Group> grpList = [
            SELECT Id FROM Group WHERE DeveloperName = 'RentIt_Community_Tenants' AND Type = 'Regular' LIMIT 1
        ];
        if (psList.isEmpty() || grpList.isEmpty()) return;

        Id psId  = psList[0].Id;
        Id grpId = grpList[0].Id;

        // Skip users who already have the permission set
        Set<Id> alreadyAssigned = new Set<Id>();
        for (PermissionSetAssignment psa : [
            SELECT AssigneeId
            FROM   PermissionSetAssignment
            WHERE  PermissionSetId = :psId
              AND  AssigneeId IN :users.keySet()
        ]) {
            alreadyAssigned.add(psa.AssigneeId);
        }

        // Skip users already in the group
        Set<Id> alreadyInGroup = new Set<Id>();
        for (GroupMember gm : [
            SELECT UserOrGroupId
            FROM   GroupMember
            WHERE  GroupId = :grpId
              AND  UserOrGroupId IN :users.keySet()
        ]) {
            alreadyInGroup.add(gm.UserOrGroupId);
        }

        List<PermissionSetAssignment> psas    = new List<PermissionSetAssignment>();
        List<GroupMember>             members = new List<GroupMember>();

        for (User u : users.values()) {
            if (!tenantContactIds.contains(u.ContactId)) continue;

            if (!alreadyAssigned.contains(u.Id)) {
                psas.add(new PermissionSetAssignment(
                    AssigneeId      = u.Id,
                    PermissionSetId = psId
                ));
            }
            if (!alreadyInGroup.contains(u.Id)) {
                members.add(new GroupMember(
                    GroupId        = grpId,
                    UserOrGroupId  = u.Id
                ));
            }
        }

        if (!psas.isEmpty())    insert psas;
        if (!members.isEmpty()) insert members;
    }
}
