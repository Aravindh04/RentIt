public with sharing class PaymentTriggerHandler {

    // ── Before contexts ──────────────────────────────────────────────────────

    public void beforeInsert(List<Payment__c> newPayments) {
        populateTenancyFromInvoice(newPayments);
    }

    public void beforeUpdate(List<Payment__c> newPayments, Map<Id, Payment__c> oldMap) {
        populateTenancyFromInvoice(newPayments);
    }

    // ── After contexts ───────────────────────────────────────────────────────

    public void afterInsert(List<Payment__c> newPayments) {
        recalculateRollups(newPayments, null);
    }

    public void afterUpdate(List<Payment__c> newPayments, Map<Id, Payment__c> oldMap) {
        recalculateRollups(newPayments, oldMap.values());
    }

    public void afterDelete(List<Payment__c> oldPayments) {
        recalculateRollups(oldPayments, null);
    }

    public void afterUndelete(List<Payment__c> newPayments) {
        recalculateRollups(newPayments, null);
    }

    // ── Private helpers ──────────────────────────────────────────────────────

    private void populateTenancyFromInvoice(List<Payment__c> payments) {
        Set<Id> invoiceIds = new Set<Id>();
        for (Payment__c p : payments) {
            if (p.Invoice__c != null && p.Tenancy__c == null) {
                invoiceIds.add(p.Invoice__c);
            }
        }
        if (invoiceIds.isEmpty()) return;

        Map<Id, Invoice__c> invoiceMap = new Map<Id, Invoice__c>([
            SELECT Id, Tenancy__c FROM Invoice__c WHERE Id IN :invoiceIds
        ]);
        for (Payment__c p : payments) {
            if (p.Invoice__c != null && p.Tenancy__c == null && invoiceMap.containsKey(p.Invoice__c)) {
                p.Tenancy__c = invoiceMap.get(p.Invoice__c).Tenancy__c;
            }
        }
    }

    private void recalculateRollups(List<Payment__c> payments, List<Payment__c> oldPayments) {
        Set<Id> invoiceIds  = new Set<Id>();
        Set<Id> tenancyIds  = new Set<Id>();

        collectIds(payments, invoiceIds, tenancyIds);
        if (oldPayments != null) collectIds(oldPayments, invoiceIds, tenancyIds);

        updateInvoiceTotalPaid(invoiceIds);
        updateAccountTotalReceived(tenancyIds);
    }

    private void collectIds(List<Payment__c> payments, Set<Id> invoiceIds, Set<Id> tenancyIds) {
        for (Payment__c p : payments) {
            if (p.Invoice__c  != null) invoiceIds.add(p.Invoice__c);
            if (p.Tenancy__c  != null) tenancyIds.add(p.Tenancy__c);
        }
    }

    private void updateInvoiceTotalPaid(Set<Id> invoiceIds) {
        if (invoiceIds.isEmpty()) return;

        Map<Id, Decimal> paidByInvoice = new Map<Id, Decimal>();
        for (Id iid : invoiceIds) paidByInvoice.put(iid, 0);

        for (AggregateResult ar : [
            SELECT Invoice__c iid, SUM(Amount__c) total
            FROM Payment__c
            WHERE Invoice__c IN :invoiceIds
              AND Status__c = 'Received'
              AND Payment_Type__c IN ('Invoice Payment', 'Credit Applied')
            GROUP BY Invoice__c
        ]) {
            paidByInvoice.put((Id) ar.get('iid'), (Decimal) ar.get('total'));
        }

        List<Invoice__c> toUpdate = new List<Invoice__c>();
        for (Id iid : invoiceIds) {
            toUpdate.add(new Invoice__c(Id = iid, Total_Paid__c = paidByInvoice.get(iid)));
        }
        update toUpdate;
    }

    private void updateAccountTotalReceived(Set<Id> tenancyIds) {
        if (tenancyIds.isEmpty()) return;

        Map<Id, Id> accountByTenancy = new Map<Id, Id>();
        for (Tenancy__c t : [
            SELECT Id, Tenant_Account__c FROM Tenancy__c
            WHERE Id IN :tenancyIds AND Tenant_Account__c != null
        ]) {
            accountByTenancy.put(t.Id, t.Tenant_Account__c);
        }
        if (accountByTenancy.isEmpty()) return;

        // Re-aggregate across ALL tenancies per affected account to get accurate totals
        Set<Id> accountIds = new Set<Id>(accountByTenancy.values());
        Map<Id, Id> tenancyToAccount = new Map<Id, Id>();
        Set<Id> allTenancyIds = new Set<Id>();
        for (Tenancy__c t : [
            SELECT Id, Tenant_Account__c FROM Tenancy__c
            WHERE Tenant_Account__c IN :accountIds
        ]) {
            tenancyToAccount.put(t.Id, t.Tenant_Account__c);
            allTenancyIds.add(t.Id);
        }

        Map<Id, Decimal> totalByAccount = new Map<Id, Decimal>();
        for (Id aid : accountIds) totalByAccount.put(aid, 0);

        for (AggregateResult ar : [
            SELECT Tenancy__c tid, SUM(Amount__c) total
            FROM Payment__c
            WHERE Tenancy__c IN :allTenancyIds AND Status__c = 'Received'
            GROUP BY Tenancy__c
        ]) {
            Id accId = tenancyToAccount.get((Id) ar.get('tid'));
            if (accId != null && totalByAccount.containsKey(accId)) {
                totalByAccount.put(accId, totalByAccount.get(accId) + (Decimal) ar.get('total'));
            }
        }

        List<Account> toUpdate = new List<Account>();
        for (Id aid : accountIds) {
            toUpdate.add(new Account(Id = aid, Total_Payments_Received__c = totalByAccount.get(aid)));
        }
        update toUpdate;
    }
}