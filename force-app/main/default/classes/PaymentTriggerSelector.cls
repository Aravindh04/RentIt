public with sharing class PaymentTriggerSelector {

    private PaymentTriggerSelector() {
    }

    public static Map<Id, Invoice__c> selectInvoicesByIds(Set<Id> invoiceIds) {
        if (invoiceIds == null || invoiceIds.isEmpty()) {
            return new Map<Id, Invoice__c>();
        }

        return new Map<Id, Invoice__c>([
            SELECT Id, Tenancy__c, Total_Amount__c, Status__c
            FROM Invoice__c
            WHERE Id IN :invoiceIds
        ]);
    }

    public static Map<Id, Decimal> selectPaidAmountsByInvoiceIds(Set<Id> invoiceIds) {
        Map<Id, Decimal> paidByInvoice = new Map<Id, Decimal>();
        if (invoiceIds == null || invoiceIds.isEmpty()) {
            return paidByInvoice;
        }

        for (AggregateResult result : [
            SELECT Invoice__c invoiceId, SUM(Amount__c) totalPaid
            FROM Payment__c
            WHERE Invoice__c IN :invoiceIds
              AND Status__c = 'Received'
              AND Payment_Type__c IN ('Invoice Payment', 'Credit Applied')
            GROUP BY Invoice__c
        ]) {
            paidByInvoice.put((Id)result.get('invoiceId'), (Decimal)result.get('totalPaid'));
        }

        return paidByInvoice;
    }
}
