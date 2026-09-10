public with sharing class InvoiceTriggerHandler {

    public void beforeInsert(List<Invoice__c> newInvoices) {
    }

    public void beforeUpdate(List<Invoice__c> newInvoices, Map<Id, Invoice__c> oldMap) {
    }

    public void afterInsert(List<Invoice__c> newInvoices) {
        InvoiceTriggerService.applyAvailableCredits(newInvoices);
    }

    public void afterUpdate(List<Invoice__c> newInvoices, Map<Id, Invoice__c> oldMap) {
        InvoiceTriggerService.applyAvailableCredits(newInvoices);
        InvoiceTriggerService.notifyNewlyPaidInvoices(newInvoices, oldMap);
    }
}
