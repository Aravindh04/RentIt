public with sharing class InvoiceTriggerHandler {

    private static final String PAID_STATUS = 'Paid';
    private static final String VOID_STATUS = 'Void';
    private static final String RECEIVED_STATUS = 'Received';
    private static final String CREDIT_APPLIED_TYPE = 'Credit Applied';
    private static final String CREDIT_METHOD = 'Credit';

    public void beforeInsert(List<Invoice__c> newInvoices) {
    }

    public void beforeUpdate(List<Invoice__c> newInvoices, Map<Id, Invoice__c> oldMap) {
    }

    public void afterInsert(List<Invoice__c> newInvoices) {
        applyCreditPayments(newInvoices, null);
    }

    public void afterUpdate(List<Invoice__c> newInvoices, Map<Id, Invoice__c> oldMap) {
        applyCreditPayments(newInvoices, oldMap);
    }

    private void applyCreditPayments(List<Invoice__c> triggerInvoices, Map<Id, Invoice__c> oldMap) {
        Set<Id> invoiceIds = new Set<Id>();
        Set<Id> tenancyIds = new Set<Id>();

        for (Invoice__c triggerInvoice : triggerInvoices) {
            if (triggerInvoice == null || triggerInvoice.Id == null || triggerInvoice.Tenancy__c == null) {
                continue;
            }
            if (oldMap != null && !shouldReevaluate(oldMap.get(triggerInvoice.Id), triggerInvoice)) {
                continue;
            }
            if (triggerInvoice.Status__c == VOID_STATUS || triggerInvoice.Status__c == PAID_STATUS) {
                continue;
            }

            invoiceIds.add(triggerInvoice.Id);
            tenancyIds.add(triggerInvoice.Tenancy__c);
        }

        if (invoiceIds.isEmpty() || tenancyIds.isEmpty()) {
            return;
        }

        Map<Id, Invoice__c> invoicesById = new Map<Id, Invoice__c>([
            SELECT Id, Tenancy__c, Amount__c, Discount_Amount__c, GST_Amount__c,
                   Total_Amount__c, Status__c, Invoice_Date__c, Due_Date__c,
                   Period_Start__c, Period_End__c
            FROM Invoice__c
            WHERE Id IN :invoiceIds
        ]);

        Map<Id, Decimal> creditsByTenancy = new Map<Id, Decimal>();
        for (Tenancy__c tenancyRecord : [
            SELECT Id, Available_Credits__c
            FROM Tenancy__c
            WHERE Id IN :tenancyIds
        ]) {
            creditsByTenancy.put(
                tenancyRecord.Id,
                tenancyRecord.Available_Credits__c != null ? tenancyRecord.Available_Credits__c : 0
            );
        }

        Set<Id> invoicesWithCreditPayment = new Set<Id>();
        for (Payment__c paymentRecord : [
            SELECT Id, Invoice__c
            FROM Payment__c
            WHERE Invoice__c IN :invoiceIds
            AND Payment_Type__c = :CREDIT_APPLIED_TYPE
            AND Status__c = :RECEIVED_STATUS
        ]) {
            invoicesWithCreditPayment.add(paymentRecord.Invoice__c);
        }

        List<Payment__c> paymentsToInsert = new List<Payment__c>();

        for (Invoice__c triggerInvoice : triggerInvoices) {
            Invoice__c invoiceRecord = invoicesById.get(triggerInvoice.Id);
            if (invoiceRecord == null || invoiceRecord.Tenancy__c == null || invoiceRecord.Status__c == VOID_STATUS) {
                continue;
            }

            if (invoicesWithCreditPayment.contains(invoiceRecord.Id)) {
                continue;
            }

            Decimal creditBalance = creditsByTenancy.containsKey(invoiceRecord.Tenancy__c)
                ? creditsByTenancy.get(invoiceRecord.Tenancy__c)
                : 0;
            Decimal amountDue = invoiceRecord.Total_Amount__c != null ? invoiceRecord.Total_Amount__c : 0;

            if (creditBalance < amountDue || amountDue <= 0) {
                continue;
            }

            paymentsToInsert.add(new Payment__c(
                Tenancy__c = invoiceRecord.Tenancy__c,
                Invoice__c = invoiceRecord.Id,
                Amount__c = amountDue,
                Payment_Date__c = invoiceRecord.Invoice_Date__c != null ? invoiceRecord.Invoice_Date__c : Date.today(),
                Payment_Method__c = CREDIT_METHOD,
                Payment_Type__c = CREDIT_APPLIED_TYPE,
                Status__c = RECEIVED_STATUS
            ));

            creditsByTenancy.put(invoiceRecord.Tenancy__c, creditBalance - amountDue);
        }

        if (!paymentsToInsert.isEmpty()) {
            insert paymentsToInsert;
        }
    }

    private Boolean shouldReevaluate(Invoice__c oldInvoice, Invoice__c newInvoice) {
        if (oldInvoice == null || newInvoice == null) {
            return true;
        }

        return oldInvoice.Tenancy__c != newInvoice.Tenancy__c
            || oldInvoice.Amount__c != newInvoice.Amount__c
            || oldInvoice.Discount_Amount__c != newInvoice.Discount_Amount__c
            || oldInvoice.GST_Amount__c != newInvoice.GST_Amount__c
            || oldInvoice.Invoice_Date__c != newInvoice.Invoice_Date__c
            || oldInvoice.Due_Date__c != newInvoice.Due_Date__c
            || oldInvoice.Period_Start__c != newInvoice.Period_Start__c
            || oldInvoice.Period_End__c != newInvoice.Period_End__c;
    }
}
