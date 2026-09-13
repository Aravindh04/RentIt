public with sharing class TenancyTriggerHandler {

    // ── After contexts ───────────────────────────────────────────────────────

    public void afterInsert(List<Tenancy__c> newTenancies) {
        applySharing(newTenancies, null);
    }

    public void afterUpdate(List<Tenancy__c> newTenancies, Map<Id, Tenancy__c> oldMap) {
        List<Tenancy__c> changed = new List<Tenancy__c>();
        for (Tenancy__c t : newTenancies) {
            if (t.Tenant__c != oldMap.get(t.Id).Tenant__c) {
                changed.add(t);
            }
        }
        if (!changed.isEmpty()) {
            applySharing(changed, oldMap);
        }
    }

    // ── Private helpers ──────────────────────────────────────────────────────

    private void applySharing(List<Tenancy__c> tenancies, Map<Id, Tenancy__c> oldMap) {
        Set<Id> newTenantIds = new Set<Id>();
        Set<Id> oldTenantIds = new Set<Id>();
        Set<Id> tenancyIds   = new Set<Id>();

        for (Tenancy__c t : tenancies) {
            tenancyIds.add(t.Id);
            if (t.Tenant__c != null) newTenantIds.add(t.Tenant__c);
            if (oldMap != null) {
                Id prev = oldMap.get(t.Id).Tenant__c;
                if (prev != null && prev != t.Tenant__c) oldTenantIds.add(prev);
            }
        }

        removeOldShares(tenancyIds, oldTenantIds);
        createNewShares(tenancies, newTenantIds);
    }

    private void removeOldShares(Set<Id> tenancyIds, Set<Id> oldTenantIds) {
        if (oldTenantIds.isEmpty()) return;

        Set<Id> oldUserIds = new Set<Id>(contactToUserMap(oldTenantIds).values());
        if (oldUserIds.isEmpty()) return;

        List<Tenancy__Share> toDelete = [
            SELECT Id FROM Tenancy__Share
            WHERE ParentId IN :tenancyIds
            AND UserOrGroupId IN :oldUserIds
            AND RowCause = :Schema.Tenancy__Share.RowCause.Manual
        ];
        if (!toDelete.isEmpty()) delete toDelete;
    }

    private void createNewShares(List<Tenancy__c> tenancies, Set<Id> newTenantIds) {
        if (newTenantIds.isEmpty()) return;

        // Invoice__c and Payment__c are ControlledByParent children of Tenancy__c
        // and automatically inherit this share — no separate share record needed.
        Map<Id, Id> contactToUser = contactToUserMap(newTenantIds);
        List<Tenancy__Share> toInsert = new List<Tenancy__Share>();
        for (Tenancy__c t : tenancies) {
            if (t.Tenant__c != null && contactToUser.containsKey(t.Tenant__c)) {
                toInsert.add(new Tenancy__Share(
                    ParentId      = t.Id,
                    UserOrGroupId = contactToUser.get(t.Tenant__c),
                    AccessLevel   = 'Read',
                    RowCause      = Schema.Tenancy__Share.RowCause.Manual
                ));
            }
        }
        // Partial success: silently ignore duplicate-share errors
        if (!toInsert.isEmpty()) Database.insert(toInsert, false);
    }

    private Map<Id, Id> contactToUserMap(Set<Id> contactIds) {
        Map<Id, Id> result = new Map<Id, Id>();
        if (contactIds == null || contactIds.isEmpty()) return result;
        for (User u : [
            SELECT Id, ContactId
            FROM User
            WHERE ContactId IN :contactIds
            AND IsActive = true
        ]) {
            result.put(u.ContactId, u.Id);
        }
        return result;
    }
}