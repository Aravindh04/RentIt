/**
 * Central, bulk-safe Apex service for sending all outbound email in RentIt.
 *
 * Exposes an @InvocableMethod so Flows can call it directly instead of the native "Send Email" (emailSimple)
 * core action, which cannot relate a sent email to a record (no Activity History logging). When a recipient
 * Id (Contact/Lead/User) and/or a related record Id is supplied, the email is saved as an Activity so it shows
 * up on the related record's (and the recipient's) Activity History related list.
 *
 * Supports two mutually exclusive content modes per request:
 *  - Raw HTML: set subject + htmlBody.
 *  - Salesforce EmailTemplate: set templateId (requires recipientId, since template merge fields are
 *    resolved against the target object) — relatedRecordId then acts as the "What" record the template's
 *    merge fields resolve against (e.g. {!Invoice__c.Name}), in addition to logging the Activity.
 *
 * An optional ccAddress CCs a second recipient (e.g. the property landlord) on the same message.
 *
 * Every call sends the entire batch of requests through a single Messaging.sendEmail invocation, so this
 * class is safe to call with any number of records without risking the "10 sendEmail calls per transaction"
 * governor limit.
 */
public with sharing class EmailService {

    public class EmailRequest {
        @InvocableVariable(label='Recipient Contact/Lead/User Id' description='Preferred recipient reference. Enables Activity History logging on both the recipient and the Related Record Id. Required when Template Id is used.')
        public Id recipientId;

        @InvocableVariable(label='Recipient Email Address' description='Used only when Recipient Contact/Lead/User Id is not supplied. Not usable with Template Id.')
        public String recipientEmail;

        @InvocableVariable(label='Org-Wide Email Address Id' description='Used only when Recipient Contact/Lead/User Id is not supplied. Not usable with Template Id.')
        public Id orgWideEmailId;

        @InvocableVariable(label='Related Record Id' description='Record the email is logged against (Activity "Related To") and, when Template Id is set, the record the template merge fields resolve against (e.g. an Invoice for {!Invoice__c.Name}).')
        public Id relatedRecordId;

        @InvocableVariable(label='Subject' description='Used only when Template Id is not supplied.')
        public String subject;

        @InvocableVariable(label='HTML Body' description='Used only when Template Id is not supplied.')
        public String htmlBody;

        @InvocableVariable(label='Email Template Id' description='When set, the email is built from this Salesforce EmailTemplate instead of Subject/HTML Body; Subject/Body/merge fields come from the template.')
        public Id templateId;

        @InvocableVariable(label='CC Email Address' description='Optional address CC\'d on the email in addition to the primary recipient (e.g. the property landlord).')
        public String ccAddress;
    }

    /**
     * Number of emails successfully handed to Messaging.sendEmail (or, in test context, that would have
     * been) on the most recent call. Governor-limit counters don't reliably carry over from async contexts
     * (e.g. Queueable) back to the caller, so tests assert on this TestVisible counter instead.
     */
    @TestVisible
    private static Integer lastEmailsSentCount = 0;

    /**
     * The exact request list handed to the most recent sendBulkEmails call, retained for test inspection
     * (e.g. verifying a caller like NoticeService resolved ccAddress correctly) since Test.isRunningTest()
     * means the real Messaging.SingleEmailMessage/SendEmailResult are never available to assert against.
     */
    @TestVisible
    private static List<EmailRequest> lastProcessedRequests;

    @InvocableMethod(label='Send Email' description='Sends bulk email (raw HTML or EmailTemplate-based), logging each as an Activity against the related record when a recipient Id and/or related record Id is supplied.' category='Email')
    public static void sendEmails(List<EmailRequest> requests) {
        sendBulkEmails(requests);
    }

    /** Plain-Apex bulk entry point for other Apex classes (e.g. NoticeService, batch/trigger logic). */
    public static List<Messaging.SendEmailResult> sendBulkEmails(List<EmailRequest> requests) {
        if (requests == null || requests.isEmpty()) {
            return new List<Messaging.SendEmailResult>();
        }

        lastProcessedRequests = requests;

        List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();
        for (EmailRequest request : requests) {
            Messaging.SingleEmailMessage message = buildMessage(request);
            if (message != null) {
                messages.add(message);
            }
        }

        if (messages.isEmpty()) {
            return new List<Messaging.SendEmailResult>();
        }

        lastEmailsSentCount = messages.size();

        // Never perform a real outbound send during Apex tests: Developer Edition orgs have a very low
        // daily "single email" quota, and once it's exhausted, Messaging.sendEmail() fails with
        // SINGLE_EMAIL_LIMIT_EXCEEDED even inside tests. No caller currently inspects the returned
        // SendEmailResult list (they assert on lastEmailsSentCount instead), so it's safe to skip the
        // real call entirely here rather than mock it.
        Messaging.SendEmailResult[] messagingResults;
        if (Test.isRunningTest()) {
            messagingResults = new List<Messaging.SendEmailResult>();
        } else {
            messagingResults = Messaging.sendEmail(messages, false);
        }
        
        for (Messaging.SendEmailResult result : messagingResults) {
            if (result.isSuccess()) {
                System.debug('EmailService.sendBulkEmails failed to send one or more emails: ' + result.getErrors()[0].getMessage());
            } else {
                GlobalUtility.logMessage('Info', 'EmailService', 'sendBulkEmails', null, result.getErrors()[0].getMessage(), null, null, 0);
            }
        }



        if (Test.isRunningTest()) {
            messagingResults = new List<Messaging.SendEmailResult>();
        }

        return messagingResults;
    }

    private static Messaging.SingleEmailMessage buildMessage(EmailRequest request) {
        if (request == null) {
            return null;
        }

        Boolean hasRecipient = request.recipientId != null || String.isNotBlank(request.recipientEmail);
        if (!hasRecipient) {
            return null;
        }

        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();

        if (request.templateId != null) {
            // EmailTemplate merge fields only resolve against a target object (Contact/Lead/User), so a
            // raw recipientEmail address cannot be used with a template.
            if (request.recipientId == null) {
                return null;
            }
            message.setTemplateId(request.templateId);
        } else {
            Boolean hasContent = String.isNotBlank(request.subject) && String.isNotBlank(request.htmlBody);
            if (!hasContent) {
                return null;
            }
            message.setSubject(request.subject);
            message.setHtmlBody(request.htmlBody);
        }

        if (String.isNotBlank(request.orgWideEmailId)) {
            message.setOrgWideEmailAddressId(request.orgWideEmailId);
        }

        if (request.recipientId != null) {
            message.setTargetObjectId(request.recipientId);

            // Platform restriction: emails to internal User recipients cannot use setSaveAsActivity(true)
            // or setWhatId() at all (Salesforce throws "saveAsActivity must be false when sending mail to
            // users" / "WhatId is not available for sending emails to UserIds"). This only applies to
            // User recipients — Contact/Lead recipients support both normally.
            Boolean isUserRecipient = request.recipientId.getSObjectType() == User.SObjectType;
            message.setSaveAsActivity(!isUserRecipient);
            if (request.relatedRecordId != null && !isUserRecipient) {
                message.setWhatId(request.relatedRecordId);
            }
        } else {
            message.setToAddresses(new List<String>{ request.recipientEmail });
            message.setSaveAsActivity(false);
            if (request.relatedRecordId != null) {
                message.setWhatId(request.relatedRecordId);
            }
        }

        if (String.isNotBlank(request.ccAddress)) {
            message.setCcAddresses(new List<String>{ request.ccAddress });
        }

        return message;
    }
}

