public with sharing class NoticeTriggerHandler {

    public void beforeInsert(List<Notice__c> newNotices) {
    }

    public void beforeUpdate(List<Notice__c> newNotices, Map<Id, Notice__c> oldMap) {
    }

    public void afterInsert(List<Notice__c> newNotices) {
        NoticeService.sendPublishedNoticeEmails(newNotices, null);
    }

    public void afterUpdate(List<Notice__c> newNotices, Map<Id, Notice__c> oldMap) {
        NoticeService.sendPublishedNoticeEmails(newNotices, oldMap);
    }
}
