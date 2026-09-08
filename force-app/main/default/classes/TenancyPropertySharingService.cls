/**
 * Grants tenant Users read access to the Property linked to their Tenancy.
 * This service runs from a system-context record-triggered Flow because the tenant
 * may not otherwise have permission to create sharing rows.
 */
public without sharing class TenancyPropertySharingService {
    private static final String ACCESS_LEVEL_READ = 'Read';
    private static final String ROW_CAUSE_MANUAL = 'Manual';

    /**
     * Identifies a Tenancy whose Property should be shared with its tenant User.
     */
    public class SharingRequest {
        @InvocableVariable(required=true)
        public Id tenancyId;
    }

    /**
     * Creates missing Property share rows for the tenant Users linked to the requests.
     */
    @InvocableMethod(
        label='Share Property With Tenants'
        description='Grants read access to each Tenancy Property for the User linked to the Tenant Contact.'
    )
    public static void sharePropertiesWithTenants(List<SharingRequest> requests) {
        if (requests == null || requests.isEmpty()) {
            return;
        }

        Set<Id> tenancyIds = new Set<Id>();
        for (SharingRequest request : requests) {
            if (request != null && request.tenancyId != null) {
                tenancyIds.add(request.tenancyId);
            }
        }
        if (tenancyIds.isEmpty()) {
            return;
        }

        Map<Id, Tenancy__c> tenancyById = new Map<Id, Tenancy__c>([
            SELECT Id, Property__c, Tenant__c
            FROM Tenancy__c
            WHERE Id IN :tenancyIds
            AND Property__c != null
            AND Tenant__c != null
        ]);
        if (tenancyById.isEmpty()) {
            return;
        }

        Set<Id> contactIds = new Set<Id>();
        Set<Id> propertyIds = new Set<Id>();
        for (Tenancy__c tenancyRecord : tenancyById.values()) {
            contactIds.add(tenancyRecord.Tenant__c);
            propertyIds.add(tenancyRecord.Property__c);
        }

        Map<Id, Set<Id>> userIdsByContactId = new Map<Id, Set<Id>>();
        for (User tenantUser : [
            SELECT Id, ContactId
            FROM User
            WHERE ContactId IN :contactIds
            AND IsActive = true
        ]) {
            if (!userIdsByContactId.containsKey(tenantUser.ContactId)) {
                userIdsByContactId.put(tenantUser.ContactId, new Set<Id>());
            }
            userIdsByContactId.get(tenantUser.ContactId).add(tenantUser.Id);
        }
        if (userIdsByContactId.isEmpty()) {
            return;
        }

        Set<Id> tenantUserIds = new Set<Id>();
        for (Set<Id> userIds : userIdsByContactId.values()) {
            tenantUserIds.addAll(userIds);
        }

        Set<String> existingShareKeys = new Set<String>();
        for (Property__Share existingShare : [
            SELECT ParentId, UserOrGroupId
            FROM Property__Share
            WHERE ParentId IN :propertyIds
            AND UserOrGroupId IN :tenantUserIds
            AND RowCause = :ROW_CAUSE_MANUAL
        ]) {
            existingShareKeys.add(buildShareKey(existingShare.ParentId, existingShare.UserOrGroupId));
        }

        List<Property__Share> sharesToInsert = new List<Property__Share>();
        for (Tenancy__c tenancyRecord : tenancyById.values()) {
            Set<Id> tenantUserIdsNew = userIdsByContactId.get(tenancyRecord.Tenant__c);
            if (tenantUserIdsNew == null) {
                continue;
            }
            for (Id tenantUserId : tenantUserIdsNew) {
                String shareKey = buildShareKey(tenancyRecord.Property__c, tenantUserId);
                if (!existingShareKeys.contains(shareKey)) {
                    sharesToInsert.add(new Property__Share(
                        ParentId = tenancyRecord.Property__c,
                        UserOrGroupId = tenantUserId,
                        AccessLevel = ACCESS_LEVEL_READ,
                        RowCause = ROW_CAUSE_MANUAL
                    ));
                    existingShareKeys.add(shareKey);
                }
            }
        }

        if (!sharesToInsert.isEmpty()) {
            Database.insert(sharesToInsert, false);
        }
    }

    private static String buildShareKey(Id propertyId, Id userId) {
        return String.valueOf(propertyId) + ':' + String.valueOf(userId);
    }
}
