public with sharing class InvoiceTriggerSelector {

    private InvoiceTriggerSelector() {
    }

    public static Map<Id, Invoice__c> selectInvoicesByIds(Set<Id> invoiceIds) {
        if (invoiceIds == null || invoiceIds.isEmpty()) {
            return new Map<Id, Invoice__c>();
        }

        return new Map<Id, Invoice__c>([
            SELECT Id, Tenancy__c, Amount__c, Discount_Amount__c, GST_Amount__c,
                   Total_Amount__c, Status__c, Invoice_Date__c, Due_Date__c,
                   Period_Start__c, Period_End__c
            FROM Invoice__c
            WHERE Id IN :invoiceIds
        ]);
    }

    public static Map<Id, Decimal> selectAvailableCreditsByTenancyIds(Set<Id> tenancyIds) {
        Map<Id, Decimal> creditsByTenancy = new Map<Id, Decimal>();
        if (tenancyIds == null || tenancyIds.isEmpty()) {
            return creditsByTenancy;
        }

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

        return creditsByTenancy;
    }

    public static Set<Id> selectInvoicesWithCreditPayments(Set<Id> invoiceIds) {
        Set<Id> invoicesWithCreditPayment = new Set<Id>();
        if (invoiceIds == null || invoiceIds.isEmpty()) {
            return invoicesWithCreditPayment;
        }

        for (Payment__c paymentRecord : [
            SELECT Invoice__c
            FROM Payment__c
            WHERE Invoice__c IN :invoiceIds
              AND Payment_Type__c = 'Credit Applied'
              AND Status__c = 'Received'
        ]) {
            if (paymentRecord.Invoice__c != null) {
                invoicesWithCreditPayment.add(paymentRecord.Invoice__c);
            }
        }

        return invoicesWithCreditPayment;
    }
}
