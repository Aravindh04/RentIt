trigger PaymentTrigger on Payment__c (before insert, before update, after insert, after update, after delete, after undelete) {

    if (Trigger.isBefore) {
        Set<Id> invoiceIds = new Set<Id>();
        for (Payment__c p : Trigger.new) {
            if (p.Invoice__c != null && p.Tenancy__c == null) {
                invoiceIds.add(p.Invoice__c);
            }
        }
        if (!invoiceIds.isEmpty()) {
            Map<Id, Invoice__c> invoices = new Map<Id, Invoice__c>([
                SELECT Id, Tenancy__c FROM Invoice__c WHERE Id IN :invoiceIds
            ]);
            for (Payment__c p : Trigger.new) {
                if (p.Invoice__c != null && p.Tenancy__c == null && invoices.containsKey(p.Invoice__c)) {
                    p.Tenancy__c = invoices.get(p.Invoice__c).Tenancy__c;
                }
            }
        }
        return;
    }

    // --- after context ---
    Set<Id> invoiceIds = new Set<Id>();
    Set<Id> tenancyIds = new Set<Id>();

    List<Payment__c> allRecords = Trigger.isDelete ? Trigger.old : Trigger.new;
    for (Payment__c p : allRecords) {
        if (p.Invoice__c != null) invoiceIds.add(p.Invoice__c);
        if (p.Tenancy__c != null) tenancyIds.add(p.Tenancy__c);
    }
    if (Trigger.isUpdate) {
        for (Payment__c p : Trigger.old) {
            if (p.Invoice__c != null) invoiceIds.add(p.Invoice__c);
            if (p.Tenancy__c != null) tenancyIds.add(p.Tenancy__c);
        }
    }

    // Recalculate Invoice.Total_Paid__c
    if (!invoiceIds.isEmpty()) {
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

    // Recalculate Account.Total_Payments_Received__c
    if (!tenancyIds.isEmpty()) {
        Map<Id, Id> accountByTenancy = new Map<Id, Id>();
        for (Tenancy__c t : [SELECT Id, Tenant_Account__c FROM Tenancy__c WHERE Id IN :tenancyIds AND Tenant_Account__c != null]) {
            accountByTenancy.put(t.Id, t.Tenant_Account__c);
        }

        Set<Id> accountIds = new Set<Id>(accountByTenancy.values());
        if (!accountIds.isEmpty()) {
            Map<Id, Id> accountByAllTenancy = new Map<Id, Id>();
            Set<Id> allTenancyIds = new Set<Id>();
            for (Tenancy__c t : [SELECT Id, Tenant_Account__c FROM Tenancy__c WHERE Tenant_Account__c IN :accountIds]) {
                accountByAllTenancy.put(t.Id, t.Tenant_Account__c);
                allTenancyIds.add(t.Id);
            }

            Map<Id, Decimal> totalByAccount = new Map<Id, Decimal>();
            for (Id aid : accountIds) totalByAccount.put(aid, 0);

            for (AggregateResult ar : [
                SELECT Tenancy__c tid, SUM(Amount__c) total
                FROM Payment__c
                WHERE Tenancy__c IN :allTenancyIds
                AND Status__c = 'Received'
                GROUP BY Tenancy__c
            ]) {
                Id tenId = (Id) ar.get('tid');
                Id accId = accountByAllTenancy.get(tenId);
                if (accId != null && totalByAccount.containsKey(accId)) {
                    totalByAccount.put(accId, totalByAccount.get(accId) + (Decimal) ar.get('total'));
                }
            }

            List<Account> accountsToUpdate = new List<Account>();
            for (Id aid : accountIds) {
                accountsToUpdate.add(new Account(Id = aid, Total_Payments_Received__c = totalByAccount.get(aid)));
            }
            update accountsToUpdate;
        }
    }
}