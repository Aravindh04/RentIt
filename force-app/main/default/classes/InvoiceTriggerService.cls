public with sharing class InvoiceTriggerService {

    private static final String PAID_STATUS = 'Paid';
    private static final String VOID_STATUS = 'Void';
    private static final String RECEIVED_STATUS = 'Received';
    private static final String CREDIT_APPLIED_TYPE = 'Credit Applied';
    private static final String CREDIT_METHOD = 'Credit';

    private InvoiceTriggerService() {
    }

    public static void applyAvailableCredits(List<Invoice__c> invoices) {
        if (invoices == null || invoices.isEmpty()) {
            return;
        }

        Set<Id> invoiceIds = new Set<Id>();
        Set<Id> tenancyIds = new Set<Id>();
        for (Invoice__c invoiceRecord : invoices) {
            if (invoiceRecord == null || invoiceRecord.Id == null || invoiceRecord.Tenancy__c == null) {
                continue;
            }

            if (invoiceRecord.Status__c == VOID_STATUS || invoiceRecord.Status__c == PAID_STATUS) {
                continue;
            }

            if (invoiceRecord.Amount__c == null || invoiceRecord.Amount__c <= 0) {
                continue;
            }

            invoiceIds.add(invoiceRecord.Id);
            tenancyIds.add(invoiceRecord.Tenancy__c);
        }

        if (invoiceIds.isEmpty()) {
            return;
        }

        Map<Id, Invoice__c> invoicesById = InvoiceTriggerSelector.selectInvoicesByIds(invoiceIds);
        Map<Id, Decimal> creditsByTenancy = InvoiceTriggerSelector.selectAvailableCreditsByTenancyIds(tenancyIds);
        Set<Id> invoicesWithCreditPayment = InvoiceTriggerSelector.selectInvoicesWithCreditPayments(invoiceIds);

        List<Payment__c> paymentsToInsert = new List<Payment__c>();
        for (Invoice__c triggerInvoice : invoices) {
            if (triggerInvoice == null || triggerInvoice.Id == null) {
                continue;
            }

            Invoice__c invoiceRecord = invoicesById.get(triggerInvoice.Id);
            if (invoiceRecord == null || invoiceRecord.Tenancy__c == null) {
                continue;
            }

            if (invoicesWithCreditPayment.contains(invoiceRecord.Id)) {
                continue;
            }

            Decimal amountDue = invoiceRecord.Total_Amount__c != null ? invoiceRecord.Total_Amount__c : 0;
            if (amountDue <= 0) {
                continue;
            }

            Decimal creditBalance = creditsByTenancy.containsKey(invoiceRecord.Tenancy__c)
                ? creditsByTenancy.get(invoiceRecord.Tenancy__c)
                : 0;

            if (creditBalance < amountDue) {
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
}
