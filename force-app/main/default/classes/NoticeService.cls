/**
 * Owns the full lifecycle of Invoice-driven Notice__c records (Rent Reminder -> Rent Arrears), their
 * follow-up Task, and the tenant email — replacing what used to be five separate Flows:
 *   - Rent_Payment_Scheduled_To_Unpaid   (superseded by InvoiceBatch.transitionUnpaidInvoiceStatuses)
 *   - Rent_Payment_Due_Tomorrow_Reminder (superseded by issueOrReissueRentReminderNotices)
 *   - Rent_Invoice_Unpaid_Task_And_Email (superseded by issueOrReissueRentReminderNotices)
 *   - Rent_Payment_Overdue_Create_Notice (superseded by issueOrReissueRentArrearsNotices)
 *   - Notice_Published_Send_Email        (superseded by sendPublishedNoticeEmails, called from NoticeTrigger)
 *
 * Design (Separation of Concerns: InvoiceBatch owns Invoice status transitions only; this class owns
 * everything Notice-related):
 *  - Exactly ONE open ("Published") notice per Invoice__c at a time, linked via Notice__c.Invoice__c
 *    (Tenancy__c is captured straight from Invoice__c.Tenancy__c). The notice starts life as "Rent
 *    Reminder" while the invoice is Unpaid, and is converted in place to "Rent Arrears" (same record,
 *    Notice_Type__c updated, Notice_Iteration__c keeps incrementing) once the invoice becomes Overdue —
 *    never duplicated.
 *  - Called daily from InvoiceBatch for every currently-Unpaid invoice (Rent Reminder) and every
 *    currently-Overdue invoice (Rent Arrears), so notices/emails are reissued each day until the tenant
 *    pays or a property manager closes the follow-up Task.
 *  - A single follow-up Task is created/updated under the notice (WhatId = Notice__c.Id) so property
 *    managers can action it and see it, together with the sent emails, on the Notice's Activity History.
 *  - Once the Task is manually closed (Completed) reissuing/emailing stops for that invoice even if it is
 *    technically still unpaid/overdue, giving property managers a manual "pause" switch.
 *  - Emails are sent using the real RentReminder/RentArrears EmailTemplate records (Messaging.setTemplateId)
 *    so template merge fields ({!Invoice__c.*}) resolve correctly — WhatId is set to the Invoice for this
 *    reason, so the auto-logged "sent email" Activity appears on the Invoice rather than the Notice. The
 *    property's landlord (Notice -> Tenancy -> Property -> Landlord Account.PersonEmail) is CC'd on every
 *    tenant email when resolvable; landlords without a PersonEmail (e.g. plain Business Account landlords)
 *    are silently skipped rather than failing the send.
 *  - When the invoice is paid (InvoiceTriggerService calls closeNoticesForPaidInvoices with the paid
 *    invoice Ids), the open Task is closed and the notice is archived so it's no longer reissued or shown
 *    as active — regardless of whether it was still "Rent Reminder" or had escalated to "Rent Arrears".
 *  - sendPublishedNoticeEmails (called from NoticeTriggerHandler) handles every OTHER notice type (General
 *    Information, Urgent, Rent Increase, Eviction Notice, etc.) once, when the notice is newly Published,
 *    same CC-the-landlord rule applied via plain multi-hop SOQL (Apex has no relationship-depth limit,
 *    unlike Flow's declarative Record Lookup).
 */
public with sharing class NoticeService {

    private static final String REMINDER_TYPE = 'Rent Reminder';
    private static final String ARREARS_TYPE = 'Rent Arrears';
    private static final String SPECIFIC_TENANT_AUDIENCE = 'Specific Tenant';
    private static final String ALL_TENANTS_AUDIENCE = 'All Tenants in Property';
    private static final String PUBLISHED_STATUS = 'Published';
    private static final String ARCHIVED_STATUS = 'Archived';
    private static final String TASK_COMPLETED_STATUS = 'Completed';
    private static final String TASK_NOT_STARTED_STATUS = 'Not Started';
    private static final String ACTIVE_STATUS = 'Active';
    private static final String NOTIFICATIONS_FOLDER = 'RentIt_Notifications';
    private static final String REMINDER_TEMPLATE = 'RentReminder';
    private static final String ARREARS_TEMPLATE = 'RentArrears';

    /** Number of invoices for which a notice was created or reissued on the most recent call. */
    @TestVisible
    private static Integer lastNoticesIssuedCount = 0;

    /** Number of notices archived (and their Tasks closed) on the most recent call. */
    @TestVisible
    private static Integer lastNoticesClosedCount = 0;

    /**
     * Creates or reissues the Rent Reminder notice for every supplied Unpaid invoice Id (one notice per
     * pending invoice). Safe to call with an empty/null set, and safe to call repeatedly (e.g. once per
     * day) for invoices that remain unpaid.
     */
    public static void issueOrReissueRentReminderNotices(Set<Id> unpaidInvoiceIds) {
        processInvoiceNotices(new NoticeProfile(
            unpaidInvoiceIds, 'Unpaid', REMINDER_TYPE, REMINDER_TEMPLATE,
            'Rent Payment Reminder – Follow Up Required', 'Normal', 7, false
        ));
    }

    /**
     * Creates or reissues the Rent Arrears notice for every supplied Overdue invoice Id (one notice per
     * pending invoice). If the invoice already has an open Rent Reminder notice, it is converted in place
     * to Rent Arrears rather than creating a second notice. Safe to call with an empty/null set, and safe
     * to call repeatedly (e.g. once per day) for invoices that remain overdue.
     */
    public static void issueOrReissueRentArrearsNotices(Set<Id> overdueInvoiceIds) {
        processInvoiceNotices(new NoticeProfile(
            overdueInvoiceIds, 'Overdue', ARREARS_TYPE, ARREARS_TEMPLATE,
            'Rent Arrears – Action Required', 'High', 3, true
        ));
    }

    /**
     * Closes the open follow-up Task and archives the notice (whichever type it currently is — Rent
     * Reminder or Rent Arrears) for every supplied (now Paid) Invoice Id, stopping further
     * reissuing/emailing for that invoice.
     */
    public static void closeNoticesForPaidInvoices(Set<Id> paidInvoiceIds) {
        lastNoticesClosedCount = 0;
        if (paidInvoiceIds == null || paidInvoiceIds.isEmpty()) {
            return;
        }

        List<Notice__c> openNotices = [
            SELECT Id
            FROM Notice__c
            WHERE Invoice__c IN :paidInvoiceIds
            AND Status__c = :PUBLISHED_STATUS
        ];
        if (openNotices.isEmpty()) {
            return;
        }

        Set<Id> noticeIds = new Map<Id, Notice__c>(openNotices).keySet();

        List<Task> openTasks = [
            SELECT Id
            FROM Task
            WHERE WhatId IN :noticeIds
            AND Status != :TASK_COMPLETED_STATUS
            AND TaskSubtype != 'Email'
        ];
        if (!openTasks.isEmpty()) {
            for (Task taskRecord : openTasks) {
                taskRecord.Status = TASK_COMPLETED_STATUS;
            }
            update openTasks;
        }

        List<Notice__c> noticesToArchive = new List<Notice__c>();
        for (Id noticeId : noticeIds) {
            noticesToArchive.add(new Notice__c(Id = noticeId, Status__c = ARCHIVED_STATUS));
        }
        update noticesToArchive;

        lastNoticesClosedCount = noticesToArchive.size();
    }

    /**
     * Sends the "notice published" email to the relevant tenant(s) for every newly-Published Notice__c
     * that is NOT a Rent Reminder/Rent Arrears (those are emailed by issueOrReissueRentReminderNotices /
     * issueOrReissueRentArrearsNotices instead, to avoid double-emailing). Handles both audiences:
     *  - Specific Tenant: emails the Tenancy's tenant.
     *  - All Tenants in Property: emails every currently-Active tenancy's tenant on that Property.
     * CCs the property's landlord (Notice -> Tenancy/Property -> Property -> Landlord Account.PersonEmail)
     * on every email when resolvable, and marks Email_Sent__c/Email_Sent_Date__c once processed — mirroring
     * the (now superseded) Notice_Published_Send_Email Flow, including its Specific-Tenant behaviour of
     * only marking Email_Sent__c when the tenant actually had an email to send to.
     */
    public static void sendPublishedNoticeEmails(List<Notice__c> newNotices, Map<Id, Notice__c> oldMap) {
        if (newNotices == null || newNotices.isEmpty()) {
            return;
        }

        Set<Id> specificTenantNoticeIds = new Set<Id>();
        Set<Id> allTenantsNoticeIds = new Set<Id>();

        for (Notice__c noticeRecord : newNotices) {
            if (noticeRecord == null || noticeRecord.Id == null) {
                continue;
            }
            if (noticeRecord.Notice_Type__c == REMINDER_TYPE || noticeRecord.Notice_Type__c == ARREARS_TYPE) {
                continue; // Emailed by the dedicated Reminder/Arrears methods instead.
            }

            Notice__c priorNotice = oldMap == null ? null : oldMap.get(noticeRecord.Id);
            Boolean newlyPublished = noticeRecord.Status__c == PUBLISHED_STATUS
                && (priorNotice == null || priorNotice.Status__c != PUBLISHED_STATUS);
            if (!newlyPublished) {
                continue;
            }

            if (noticeRecord.Audience__c == SPECIFIC_TENANT_AUDIENCE) {
                specificTenantNoticeIds.add(noticeRecord.Id);
            } else if (noticeRecord.Audience__c == ALL_TENANTS_AUDIENCE) {
                allTenantsNoticeIds.add(noticeRecord.Id);
            }
        }

        if (specificTenantNoticeIds.isEmpty() && allTenantsNoticeIds.isEmpty()) {
            return;
        }

        List<EmailService.EmailRequest> emailRequests = new List<EmailService.EmailRequest>();
        Set<Id> noticeIdsToMarkSent = new Set<Id>();

        if (!specificTenantNoticeIds.isEmpty()) {
            for (Notice__c noticeRecord : [
                SELECT Id, Name, Notice_Type__c, Content__c, Effective_Date__c,
                       Tenancy__r.Tenant__c, Tenancy__r.Tenant__r.Email,
                       Tenancy__r.Property__r.Landlord__r.PersonEmail
                FROM Notice__c
                WHERE Id IN :specificTenantNoticeIds
            ]) {
                Id tenantContactId = noticeRecord.Tenancy__r?.Tenant__c;
                String tenantEmail = noticeRecord.Tenancy__r?.Tenant__r?.Email;
                if (tenantContactId == null || String.isBlank(tenantEmail)) {
                    continue; // Matches the Flow's "No Email - Skip" path, which never reached Mark_Email_Sent.
                }

                EmailService.EmailRequest emailRequest = new EmailService.EmailRequest();
                emailRequest.recipientId = tenantContactId;
                emailRequest.relatedRecordId = noticeRecord.Id;
                emailRequest.subject = buildPublishedNoticeSubject(noticeRecord);
                emailRequest.htmlBody = buildPublishedNoticeBody(noticeRecord);
                emailRequest.ccAddress = noticeRecord.Tenancy__r.Property__r.Landlord__r.PersonEmail;
                emailRequests.add(emailRequest);

                noticeIdsToMarkSent.add(noticeRecord.Id);
            }
        }

        if (!allTenantsNoticeIds.isEmpty()) {
            Map<Id, Notice__c> allTenantsNoticesById = new Map<Id, Notice__c>([
                SELECT Id, Name, Notice_Type__c, Content__c, Effective_Date__c, Property__c,
                       Property__r.Landlord__r.PersonEmail
                FROM Notice__c
                WHERE Id IN :allTenantsNoticeIds
            ]);

            Set<Id> propertyIds = new Set<Id>();
            for (Notice__c noticeRecord : allTenantsNoticesById.values()) {
                if (noticeRecord.Property__c != null) {
                    propertyIds.add(noticeRecord.Property__c);
                }
            }

            Map<Id, List<Tenancy__c>> activeTenanciesByProperty = new Map<Id, List<Tenancy__c>>();
            for (Tenancy__c tenancyRecord : [
                SELECT Id, Property__c, Tenant__c, Tenant__r.Email
                FROM Tenancy__c
                WHERE Property__c IN :propertyIds
                AND Status__c = :ACTIVE_STATUS
            ]) {
                if (!activeTenanciesByProperty.containsKey(tenancyRecord.Property__c)) {
                    activeTenanciesByProperty.put(tenancyRecord.Property__c, new List<Tenancy__c>());
                }
                activeTenanciesByProperty.get(tenancyRecord.Property__c).add(tenancyRecord);
            }

            for (Notice__c noticeRecord : allTenantsNoticesById.values()) {
                // Mirrors the Flow's loop, whose noMoreValuesConnector always reaches Mark_Email_Sent
                // regardless of how many (if any) individual tenants had an email address.
                noticeIdsToMarkSent.add(noticeRecord.Id);

                List<Tenancy__c> tenancies = activeTenanciesByProperty.get(noticeRecord.Property__c);
                if (tenancies == null || tenancies.isEmpty()) {
                    continue;
                }

                String landlordEmail = noticeRecord.Property__r?.Landlord__r?.PersonEmail;
                String subject = buildPublishedNoticeSubject(noticeRecord);
                String body = buildPublishedNoticeBody(noticeRecord);
                Id orgWideEmailId = [SELECT Id FROM OrgWideEmailAddress LIMIT 1].Id;

                for (Tenancy__c tenancyRecord : tenancies) {
                    if (tenancyRecord.Tenant__c == null || String.isBlank(tenancyRecord.Tenant__r?.Email)) {
                        continue;
                    }

                    EmailService.EmailRequest emailRequest = new EmailService.EmailRequest();
                    emailRequest.recipientId = tenancyRecord.Tenant__c;
                    emailRequest.relatedRecordId = noticeRecord.Id;
                    emailRequest.subject = subject;
                    emailRequest.htmlBody = body;
                    emailRequest.ccAddress = landlordEmail;
                    emailRequest.orgWideEmailId = orgWideEmailId;
                    emailRequests.add(emailRequest);
                }
            }
        }

        if (!emailRequests.isEmpty()) {
            EmailService.sendBulkEmails(emailRequests);
        }

        if (!noticeIdsToMarkSent.isEmpty()) {
            List<Notice__c> noticesToMarkSent = new List<Notice__c>();
            for (Id noticeId : noticeIdsToMarkSent) {
                noticesToMarkSent.add(new Notice__c(
                    Id = noticeId,
                    Email_Sent__c = true,
                    Email_Sent_Date__c = Datetime.now()
                ));
            }
            update noticesToMarkSent;
        }
    }

    private static String buildPublishedNoticeSubject(Notice__c noticeRecord) {
        return 'Notice from Your Landlord: ' + noticeRecord.Notice_Type__c + ' - ' + noticeRecord.Name;
    }

    private static String buildPublishedNoticeBody(Notice__c noticeRecord) {
        String effectiveDate = noticeRecord.Effective_Date__c != null ? noticeRecord.Effective_Date__c.format() : '';
        return 'Dear Tenant,<br/><br/>'
            + 'You have received a notice from your landlord regarding your tenancy.<br/><br/>'
            + 'Notice Type: ' + noticeRecord.Notice_Type__c + '<br/>'
            + 'Subject: ' + noticeRecord.Name + '<br/>'
            + 'Effective Date: ' + effectiveDate + '<br/><br/>'
            + noticeRecord.Content__c + '<br/><br/>'
            + 'Please log into the tenant portal to view the full notice details and respond if required.<br/><br/>'
            + 'Regards,<br/>RentIt Property Management';
    }

    /** Bundles the handful of values that differ between the Reminder and Arrears phases. */
    private class NoticeProfile {
        private Set<Id> invoiceIds;
        private String invoiceStatus;
        private String noticeType;
        private String templateDeveloperName;
        private String taskSubject;
        private String taskPriority;
        private Integer taskFollowUpDays;
        private Boolean effectiveDateIsDueDatePlusOne;

        private NoticeProfile(
            Set<Id> invoiceIds, String invoiceStatus, String noticeType, String templateDeveloperName,
            String taskSubject, String taskPriority, Integer taskFollowUpDays, Boolean effectiveDateIsDueDatePlusOne
        ) {
            this.invoiceIds = invoiceIds;
            this.invoiceStatus = invoiceStatus;
            this.noticeType = noticeType;
            this.templateDeveloperName = templateDeveloperName;
            this.taskSubject = taskSubject;
            this.taskPriority = taskPriority;
            this.taskFollowUpDays = taskFollowUpDays;
            this.effectiveDateIsDueDatePlusOne = effectiveDateIsDueDatePlusOne;
        }
    }

    private static void processInvoiceNotices(NoticeProfile profile) {
        lastNoticesIssuedCount = 0;
        if (profile.invoiceIds == null || profile.invoiceIds.isEmpty()) {
            return;
        }

        Map<Id, Invoice__c> invoicesById = selectInvoicesByIdAndStatus(profile.invoiceIds, profile.invoiceStatus);
        if (invoicesById.isEmpty()) {
            return;
        }

        Id templateId = selectTemplateId(profile.templateDeveloperName);
        if (templateId == null) {
            return;
        }

        Map<Id, Notice__c> openNoticeByInvoice = selectOpenNoticesByInvoice(invoicesById.keySet());
        Map<Id, Task> mostRecentTaskByNoticeId = selectMostRecentTaskByNoticeId(openNoticeByInvoice.values());

        List<Notice__c> noticesToInsert = new List<Notice__c>();
        List<Notice__c> noticesToUpdate = new List<Notice__c>();
        Map<Id, Notice__c> activeNoticeByInvoice = new Map<Id, Notice__c>();
        Map<Id, Task> existingTaskByInvoice = new Map<Id, Task>();

        for (Id invoiceId : invoicesById.keySet()) {
            Invoice__c invoiceRecord = invoicesById.get(invoiceId);
            Id tenantContactId = invoiceRecord.Tenancy__r.Tenant__c;
            if (tenantContactId == null || invoiceRecord.Tenancy__c == null) {
                continue;
            }

            Notice__c existingNotice = openNoticeByInvoice.get(invoiceId);
            Task existingTask = existingNotice == null ? null : mostRecentTaskByNoticeId.get(existingNotice.Id);
            if (existingTask != null && existingTask.Status == TASK_COMPLETED_STATUS) {
                continue; // Paused: the follow-up task was already closed, so stop reissuing/emailing.
            }

            Integer nextIteration = (existingNotice == null ? 0 : (Integer) existingNotice.Notice_Iteration__c) + 1;
            String comment = buildNoticeComment(invoiceRecord, profile.noticeType, nextIteration);
            String content = buildNoticeContentHtml(invoiceRecord, profile.noticeType, nextIteration);
            Date effectiveDate = profile.effectiveDateIsDueDatePlusOne
                ? invoiceRecord.Due_Date__c.addDays(1)
                : Date.today();

            Notice__c noticeToSave;
            if (existingNotice == null) {
                noticeToSave = new Notice__c(
                    Name = profile.noticeType + ' Notice',
                    Audience__c = SPECIFIC_TENANT_AUDIENCE,
                    Tenancy__c = invoiceRecord.Tenancy__c,
                    Invoice__c = invoiceId,
                    Notice_Type__c = profile.noticeType,
                    Status__c = PUBLISHED_STATUS,
                    Effective_Date__c = effectiveDate,
                    Content__c = content,
                    Notice_Comment__c = comment,
                    Notice_Iteration__c = nextIteration,
                    Email_Sent__c = true,
                    Email_Sent_Date__c = Datetime.now()
                );
                noticesToInsert.add(noticeToSave);
            } else {
                noticeToSave = new Notice__c(
                    Id = existingNotice.Id,
                    Notice_Type__c = profile.noticeType, // converts Rent Reminder -> Rent Arrears in place
                    Effective_Date__c = effectiveDate,
                    Content__c = content,
                    Notice_Comment__c = comment,
                    Notice_Iteration__c = nextIteration,
                    Email_Sent__c = true,
                    Email_Sent_Date__c = Datetime.now()
                );
                noticesToUpdate.add(noticeToSave);
            }

            activeNoticeByInvoice.put(invoiceId, noticeToSave);
            if (existingTask != null) {
                existingTaskByInvoice.put(invoiceId, existingTask);
            }
        }

        if (activeNoticeByInvoice.isEmpty()) {
            return;
        }

        // Insert first so brand-new Notice__c rows get an Id (the same in-memory instances are held by
        // activeNoticeByInvoice, so their Id fields are populated by the platform after this DML).
        if (!noticesToInsert.isEmpty()) {
            insert noticesToInsert;
        }
        if (!noticesToUpdate.isEmpty()) {
            update noticesToUpdate;
        }

        List<Task> tasksToInsert = new List<Task>();
        List<Task> tasksToUpdate = new List<Task>();
        List<EmailService.EmailRequest> emailRequests = new List<EmailService.EmailRequest>();

        for (Id invoiceId : activeNoticeByInvoice.keySet()) {
            Notice__c noticeRecord = activeNoticeByInvoice.get(invoiceId);
            Invoice__c invoiceRecord = invoicesById.get(invoiceId);
            Id tenantContactId = invoiceRecord.Tenancy__r.Tenant__c;
            Date followUpDate = Date.today().addDays(profile.taskFollowUpDays);

            Task existingTask = existingTaskByInvoice.get(invoiceId);
            if (existingTask != null) {
                tasksToUpdate.add(new Task(
                    Id = existingTask.Id,
                    Subject = profile.taskSubject,
                    Priority = profile.taskPriority,
                    ActivityDate = followUpDate,
                    Description = noticeRecord.Notice_Comment__c
                ));
            } else {
                tasksToInsert.add(new Task(
                    Subject = profile.taskSubject,
                    Priority = profile.taskPriority,
                    Status = TASK_NOT_STARTED_STATUS,
                    ActivityDate = followUpDate,
                    Description = noticeRecord.Notice_Comment__c,
                    WhoId = tenantContactId,
                    WhatId = noticeRecord.Id
                ));
            }

            EmailService.EmailRequest emailRequest = new EmailService.EmailRequest();
            emailRequest.recipientId = tenantContactId;
            emailRequest.templateId = templateId;
            emailRequest.relatedRecordId = invoiceId; // WhatId must be the Invoice for {!Invoice__c.*} merges.
            emailRequest.ccAddress = invoiceRecord.Tenancy__r.Property__r.Landlord__r.PersonEmail;
            emailRequests.add(emailRequest);

            lastNoticesIssuedCount++;
        }

        if (!tasksToInsert.isEmpty()) {
            insert tasksToInsert;
        }
        if (!tasksToUpdate.isEmpty()) {
            update tasksToUpdate;
        }
        if (!emailRequests.isEmpty()) {
            EmailService.sendBulkEmails(emailRequests);
        }
    }

    private static Map<Id, Invoice__c> selectInvoicesByIdAndStatus(Set<Id> invoiceIds, String status) {
        return new Map<Id, Invoice__c>([
            SELECT Id, Name, Due_Date__c, Total_Amount__c, Period_Start__c, Period_End__c, Tenancy__c,
                   Tenancy__r.Tenant__c, Tenancy__r.Tenant__r.FirstName,
                   Tenancy__r.Property__r.Landlord__r.PersonEmail
            FROM Invoice__c
            WHERE Id IN :invoiceIds
            AND Status__c = :status
        ]);
    }

    private static Id selectTemplateId(String developerName) {
        List<EmailTemplate> templates = [
            SELECT Id
            FROM EmailTemplate
            WHERE DeveloperName = :developerName
            AND Folder.DeveloperName = :NOTIFICATIONS_FOLDER
            LIMIT 1
        ];
        return templates.isEmpty() ? null : templates[0].Id;
    }

    private static Map<Id, Notice__c> selectOpenNoticesByInvoice(Set<Id> invoiceIds) {
        Map<Id, Notice__c> result = new Map<Id, Notice__c>();
        for (Notice__c noticeRecord : [
            SELECT Id, Invoice__c, Notice_Iteration__c, Notice_Type__c
            FROM Notice__c
            WHERE Invoice__c IN :invoiceIds
            AND Status__c = :PUBLISHED_STATUS
        ]) {
            result.put(noticeRecord.Invoice__c, noticeRecord);
        }
        return result;
    }

    /**
     * Resolves the most recent manually-created follow-up Task per notice (used to decide whether a
     * follow-up already exists so it can be updated in place, and whether it has been closed/paused).
     * Excludes Task rows that Salesforce auto-creates to log a sent email as an Activity
     * (TaskSubtype = 'Email') — those are a record of communication, not the actionable follow-up task
     * property managers use to pause reissuing.
     */
    private static Map<Id, Task> selectMostRecentTaskByNoticeId(List<Notice__c> notices) {
        Map<Id, Task> result = new Map<Id, Task>();
        if (notices == null || notices.isEmpty()) {
            return result;
        }

        Set<Id> noticeIds = new Map<Id, Notice__c>(notices).keySet();
        for (Task taskRecord : [
            SELECT Id, WhatId, Status
            FROM Task
            WHERE WhatId IN :noticeIds
            AND TaskSubtype != 'Email'
            ORDER BY CreatedDate DESC
        ]) {
            if (!result.containsKey(taskRecord.WhatId)) {
                result.put(taskRecord.WhatId, taskRecord);
            }
        }
        return result;
    }

    private static String buildNoticeComment(Invoice__c invoiceRecord, String noticeType, Integer iteration) {
        String phase = noticeType == ARREARS_TYPE ? 'remains overdue' : 'remains unpaid';
        return 'Reissued on ' + Date.today().format() + ' — invoice ' + invoiceRecord.Name
            + ' ' + phase + ' (due ' + invoiceRecord.Due_Date__c.format() + '). Iteration '
            + iteration + '.';
    }

    private static String buildNoticeContentHtml(Invoice__c invoiceRecord, String noticeType, Integer iteration) {
        Boolean isArrears = noticeType == ARREARS_TYPE;
        Decimal amount = invoiceRecord.Total_Amount__c != null ? invoiceRecord.Total_Amount__c : 0;
        String amountLabel = isArrears ? 'Overdue Amount' : 'Amount Due';
        String introText = isArrears
            ? 'Our records show your rent is now <strong style="color:#be123c;">overdue</strong>. Please arrange payment immediately to avoid escalation.'
            : 'This is a reminder that your rent payment is <strong>due soon</strong>. Please make payment on time to avoid late charges.';
        String accentColor = isArrears ? '#be123c' : '#0f4ea8';
        String noticeBoxText = isArrears
            ? 'Please make payment and submit your payment details in the portal as soon as possible to prevent further action.'
            : 'To keep your account in good standing, please complete payment and submit evidence in the portal before the due date.';

        return '<p style="margin:0 0 12px;color:#1f2937;font-size:14px;line-height:1.6;">' + introText + '</p>'
            + '<div style="background:#f8fafc;border:1px solid #e2e8f0;border-left:4px solid ' + accentColor + ';border-radius:8px;padding:14px 16px;margin:12px 0;">'
            + '<div style="font-size:12px;color:' + accentColor + ';text-transform:uppercase;letter-spacing:.6px;font-weight:700;">' + amountLabel + '</div>'
            + '<div style="font-size:24px;font-weight:700;color:' + accentColor + ';margin-top:4px;">$' + amount.setScale(2) + '</div>'
            + '</div>'
            + '<table style="width:100%;border-collapse:collapse;margin:12px 0;">'
            + '<tr><td style="padding:6px 0;color:#64748b;font-size:13px;">Invoice Number</td><td style="padding:6px 0;color:#111827;font-weight:600;font-size:13px;text-align:right;">' + invoiceRecord.Name + '</td></tr>'
            + '<tr><td style="padding:6px 0;color:#64748b;font-size:13px;">Due Date</td><td style="padding:6px 0;color:#111827;font-weight:600;font-size:13px;text-align:right;">' + invoiceRecord.Due_Date__c.format() + '</td></tr>'
            + '<tr><td style="padding:6px 0;color:#64748b;font-size:13px;">Billing Period</td><td style="padding:6px 0;color:#111827;font-weight:600;font-size:13px;text-align:right;">' + invoiceRecord.Period_Start__c.format() + ' - ' + invoiceRecord.Period_End__c.format() + '</td></tr>'
            + '<tr><td style="padding:6px 0;color:#64748b;font-size:13px;">Times Issued</td><td style="padding:6px 0;color:#111827;font-weight:600;font-size:13px;text-align:right;">' + iteration + '</td></tr>'
            + '</table>'
            + '<p style="background:#fff7ed;border:1px solid #fdba74;border-left:4px solid #f97316;border-radius:8px;padding:12px 14px;margin:12px 0;color:#7c2d12;font-size:13px;">' + noticeBoxText + '</p>'
            + '<p style="margin:0;color:#1f2937;font-size:14px;">If you are experiencing financial difficulty, please contact your property manager immediately to discuss arrangements.</p>';
    }
}
