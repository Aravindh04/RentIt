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

    public static Set<Id> selectReceivedPaymentIds(List<Payment__c> payments) {
        Set<Id> receivedPaymentIds = new Set<Id>();
        if (payments == null || payments.isEmpty()) {
            return receivedPaymentIds;
        }

        for (Payment__c paymentRecord : payments) {
            if (paymentRecord != null && paymentRecord.Status__c == 'Received') {
                receivedPaymentIds.add(paymentRecord.Id);
            }
        }

        return receivedPaymentIds;
    }

    public static User[] selectUsersByPayments(List<Payment__c> payments) {
        Set<Id> tenancyIds = new Set<Id>();
        if (payments == null || payments.isEmpty()) {
            return new User[]{};
        }

        for (Payment__c paymentRecord : payments) {
            if (paymentRecord != null && paymentRecord.Tenancy__c != null) {
                tenancyIds.add(paymentRecord.Tenancy__c);
            }
        }

        if (tenancyIds.isEmpty()) {
            return new User[]{};
        }

        return [
            SELECT Id, ContactId
            FROM User
            WHERE ContactId IN (
                SELECT Tenant__c
                FROM Tenancy__c
                WHERE Id IN :tenancyIds
                  AND Status__c = 'Active'
            )
        ];
    }
}
