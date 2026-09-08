public with sharing class PaymentTriggerHandler {

    public void beforeInsert(List<Payment__c> newPayments) {
        PaymentTriggerService.beforeInsert(newPayments);
    }

    public void beforeUpdate(List<Payment__c> newPayments, Map<Id, Payment__c> oldMap) {
        PaymentTriggerService.beforeUpdate(newPayments, oldMap);
    }

    public void afterInsert(List<Payment__c> newPayments) {
        PaymentTriggerService.afterInsert(newPayments);
    }

    public void afterUpdate(List<Payment__c> newPayments, Map<Id, Payment__c> oldMap) {
        PaymentTriggerService.afterUpdate(newPayments, oldMap);
    }

    public void afterDelete(List<Payment__c> oldPayments) {
        PaymentTriggerService.afterDelete(oldPayments);
    }

    public void afterUndelete(List<Payment__c> newPayments) {
        PaymentTriggerService.afterUndelete(newPayments);
    }
}