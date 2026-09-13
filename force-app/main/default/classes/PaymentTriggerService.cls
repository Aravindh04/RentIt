public with sharing class PaymentTriggerService {

    private static final String VOID_STATUS = 'Void';
    private static final String PAID_STATUS = 'Paid';

    private PaymentTriggerService() {
    }

    public static void beforeInsert(List<Payment__c> newPayments) {
        populateTenancyFromInvoice(newPayments);
    }

    public static void beforeUpdate(List<Payment__c> newPayments, Map<Id, Payment__c> oldMap) {
        populateTenancyFromInvoice(newPayments);
    }

    public static void afterInsert(List<Payment__c> newPayments) {
        recalculateInvoiceTotals(newPayments, null);
    }

    public static void afterUpdate(List<Payment__c> newPayments, Map<Id, Payment__c> oldMap) {
        recalculateInvoiceTotals(newPayments, oldMap == null ? null : oldMap.values());
    }

    public static void afterDelete(List<Payment__c> oldPayments) {
        recalculateInvoiceTotals(oldPayments, null);
    }

    public static void afterUndelete(List<Payment__c> newPayments) {
        recalculateInvoiceTotals(newPayments, null);
    }

    private static void populateTenancyFromInvoice(List<Payment__c> payments) {
        if (payments == null || payments.isEmpty()) {
            return;
        }

        Set<Id> invoiceIds = new Set<Id>();
        for (Payment__c paymentRecord : payments) {
            if (paymentRecord != null && paymentRecord.Invoice__c != null && paymentRecord.Tenancy__c == null) {
                invoiceIds.add(paymentRecord.Invoice__c);
            }
        }

        if (invoiceIds.isEmpty()) {
            return;
        }

        Map<Id, Invoice__c> invoicesById = PaymentTriggerSelector.selectInvoicesByIds(invoiceIds);
        for (Payment__c paymentRecord : payments) {
            if (paymentRecord != null && paymentRecord.Invoice__c != null && paymentRecord.Tenancy__c == null
                && invoicesById.containsKey(paymentRecord.Invoice__c)) {
                paymentRecord.Tenancy__c = invoicesById.get(paymentRecord.Invoice__c).Tenancy__c;
            }
        }
    }

    private static void recalculateInvoiceTotals(List<Payment__c> payments, List<Payment__c> oldPayments) {
        Set<Id> invoiceIds = new Set<Id>();
        collectInvoiceIds(payments, invoiceIds);
        collectInvoiceIds(oldPayments, invoiceIds);

        if (invoiceIds.isEmpty()) {
            return;
        }

        Map<Id, Decimal> paidByInvoice = PaymentTriggerSelector.selectPaidAmountsByInvoiceIds(invoiceIds);
        Map<Id, Invoice__c> invoicesById = PaymentTriggerSelector.selectInvoicesByIds(invoiceIds);

        List<Invoice__c> invoicesToUpdate = new List<Invoice__c>();
        for (Id invoiceId : invoiceIds) {
            Decimal totalPaid = paidByInvoice.containsKey(invoiceId) ? paidByInvoice.get(invoiceId) : 0;
            Invoice__c invoiceRecord = invoicesById.get(invoiceId);
            Invoice__c invoiceToUpdate = new Invoice__c(
                Id = invoiceId,
                Total_Paid__c = totalPaid
            );

            if (invoiceRecord != null
                && invoiceRecord.Status__c != VOID_STATUS
                && invoiceRecord.Total_Amount__c != null
                && totalPaid >= invoiceRecord.Total_Amount__c) {
                invoiceToUpdate.Status__c = PAID_STATUS;
            }

            invoicesToUpdate.add(invoiceToUpdate);
        }

        update invoicesToUpdate;
    }

    private static void notifyUsers(List<Payment__c> payments) {
        Set<Id> recevivedPaymentIds = PaymentTriggerSelector.selectReceivedPaymentIds(payments);
        User[] relatedUsers = PaymentTriggerSelector.selectUsersByPayments(payments);
        if (relatedUsers.isEmpty()) {
            return; 
        }

        NotificationService.notifyUsers(

    }

    private static void collectInvoiceIds(List<Payment__c> payments, Set<Id> invoiceIds) {
        if (payments == null || payments.isEmpty()) {
            return;
        }

        for (Payment__c paymentRecord : payments) {
            if (paymentRecord != null && paymentRecord.Invoice__c != null) {
                invoiceIds.add(paymentRecord.Invoice__c);
            }
        }
    }
}
