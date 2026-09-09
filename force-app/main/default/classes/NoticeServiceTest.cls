@IsTest(SeeAllData=false)
private class NoticeServiceTest {

    @TestSetup
    static void setup() {
        Account landlord = new Account(Name = 'Notice Service Landlord');
        insert landlord;

        Property__c propertyRecord = new Property__c(
            Property_Type__c = 'House',
            Landlord__c = landlord.Id
        );
        insert propertyRecord;

        Account tenantAccount = new Account(Name = 'Notice Service Tenant Account');
        insert tenantAccount;

        Contact tenantContact = new Contact(
            FirstName = 'Notice',
            LastName = 'Tenant',
            Email = 'notice.tenant@rentit.test',
            AccountId = tenantAccount.Id
        );
        insert tenantContact;

        insert new Tenancy__c(
            Property__c = propertyRecord.Id,
            Tenant__c = tenantContact.Id,
            Status__c = 'Active'
        );
    }

    private static Invoice__c createInvoice(Id tenancyId, String status, Date dueDate) {
        Invoice__c invoiceRecord = new Invoice__c(
            Tenancy__c = tenancyId,
            Amount__c = 1000,
            Category__c = 'Rent',
            Invoice_Date__c = dueDate.addDays(-7),
            Due_Date__c = dueDate,
            Period_Start__c = dueDate.addDays(-7),
            Period_End__c = dueDate,
            Status__c = 'Scheduled'
        );
        insert invoiceRecord;
        invoiceRecord.Status__c = status;
        update invoiceRecord;
        return invoiceRecord;
    }

    @IsTest
    static void givenUnpaidInvoice_whenReminderIssued_thenNoticeAndTaskAreCreatedAndEmailIsSent() {
        Tenancy__c tenancyRecord = [SELECT Id FROM Tenancy__c LIMIT 1];
        Invoice__c invoiceRecord = createInvoice(tenancyRecord.Id, 'Unpaid', Date.today().addDays(1));

        EmailService.lastEmailsSentCount = 0;

        Test.startTest();
        NoticeService.issueOrReissueRentReminderNotices(new Set<Id>{ invoiceRecord.Id });
        Test.stopTest();

        List<Notice__c> notices = [
            SELECT Id, Invoice__c, Tenancy__c, Notice_Iteration__c, Notice_Comment__c, Content__c,
                   Effective_Date__c, Status__c, Notice_Type__c
            FROM Notice__c
            WHERE Invoice__c = :invoiceRecord.Id
        ];
        Assert.areEqual(1, notices.size(), 'One Rent Reminder notice should be created for the unpaid invoice.');
        Assert.areEqual(invoiceRecord.Id, notices[0].Invoice__c, 'The notice should be linked to the invoice.');
        Assert.areEqual(tenancyRecord.Id, notices[0].Tenancy__c, 'The tenancy should be captured from the invoice.');
        Assert.areEqual('Rent Reminder', notices[0].Notice_Type__c, 'The notice should be of type Rent Reminder.');
        Assert.areEqual(1, notices[0].Notice_Iteration__c.intValue(), 'The first issuance should have iteration 1.');
        Assert.areEqual(Date.today(), notices[0].Effective_Date__c, 'Reminder effective date should be the issuance date.');
        Assert.isTrue(String.isNotBlank(notices[0].Notice_Comment__c), 'A notice comment should be recorded.');
        Assert.isTrue(String.isNotBlank(notices[0].Content__c), 'The notice content should be populated.');

        List<Task> tasks = [SELECT Id, WhatId, Status, Priority FROM Task WHERE WhatId = :notices[0].Id AND TaskSubtype != 'Email'];
        Assert.areEqual(1, tasks.size(), 'One follow-up Task should be created under the notice.');
        Assert.areEqual('Not Started', tasks[0].Status, 'The follow-up Task should start Not Started.');
        Assert.areEqual('Normal', tasks[0].Priority, 'The reminder follow-up Task should be Normal priority.');

        Assert.areEqual(1, EmailService.lastEmailsSentCount, 'One reminder email should have been sent.');
    }

    @IsTest
    static void givenPersonAccountLandlordWithEmail_whenReminderIssued_thenLandlordIsCcd() {
        Id landlordRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Landlord_Account').getRecordTypeId();

        Account landlordPersonAccount = new Account(
            RecordTypeId = landlordRecordTypeId,
            LastName = 'CcLandlord',
            PersonEmail = 'cc.landlord@rentit.test'
        );
        insert landlordPersonAccount;

        Property__c propertyRecord = new Property__c(
            Property_Type__c = 'House',
            Landlord__c = landlordPersonAccount.Id
        );
        insert propertyRecord;

        Account tenantAccount = new Account(Name = 'Cc Test Tenant Account');
        insert tenantAccount;
        Contact tenantContact = new Contact(
            FirstName = 'Cc',
            LastName = 'Tenant',
            Email = 'cc.tenant@rentit.test',
            AccountId = tenantAccount.Id
        );
        insert tenantContact;
        Tenancy__c tenancyRecord = new Tenancy__c(
            Property__c = propertyRecord.Id,
            Tenant__c = tenantContact.Id,
            Status__c = 'Active'
        );
        insert tenancyRecord;

        Invoice__c invoiceRecord = createInvoice(tenancyRecord.Id, 'Unpaid', Date.today().addDays(1));

        Test.startTest();
        NoticeService.issueOrReissueRentReminderNotices(new Set<Id>{ invoiceRecord.Id });
        Test.stopTest();

        Assert.areEqual(1, EmailService.lastProcessedRequests.size(), 'One email request should have been built.');
        Assert.areEqual(
            'cc.landlord@rentit.test',
            EmailService.lastProcessedRequests[0].ccAddress,
            'The property landlord should be resolved via Notice -> Tenancy -> Property -> Landlord and CC\'d.'
        );
    }

    @IsTest
    static void givenBusinessAccountLandlordWithoutPersonEmail_whenReminderIssued_thenNoCcIsSet() {
        Tenancy__c tenancyRecord = [SELECT Id FROM Tenancy__c LIMIT 1];
        Invoice__c invoiceRecord = createInvoice(tenancyRecord.Id, 'Unpaid', Date.today().addDays(1));

        Test.startTest();
        NoticeService.issueOrReissueRentReminderNotices(new Set<Id>{ invoiceRecord.Id });
        Test.stopTest();

        Assert.areEqual(1, EmailService.lastProcessedRequests.size(), 'One email request should have been built.');
        Assert.isTrue(
            String.isBlank(EmailService.lastProcessedRequests[0].ccAddress),
            'A plain Business Account landlord has no PersonEmail, so no CC address should be set.'
        );
    }

    @IsTest
    static void givenStillUnpaidInvoice_whenReminderIssuedAgain_thenNoticeIsReissuedNotDuplicated() {
        Tenancy__c tenancyRecord = [SELECT Id FROM Tenancy__c LIMIT 1];
        Invoice__c invoiceRecord = createInvoice(tenancyRecord.Id, 'Unpaid', Date.today().addDays(1));

        NoticeService.issueOrReissueRentReminderNotices(new Set<Id>{ invoiceRecord.Id });

        EmailService.lastEmailsSentCount = 0;

        Test.startTest();
        NoticeService.issueOrReissueRentReminderNotices(new Set<Id>{ invoiceRecord.Id });
        Test.stopTest();

        List<Notice__c> notices = [SELECT Id, Notice_Iteration__c FROM Notice__c WHERE Invoice__c = :invoiceRecord.Id];
        Assert.areEqual(1, notices.size(), 'Reissuing should update the existing notice, not create a duplicate.');
        Assert.areEqual(2, notices[0].Notice_Iteration__c.intValue(), 'The iteration should increment to 2 on reissue.');

        Assert.areEqual(
            1,
            [SELECT COUNT() FROM Task WHERE WhatId = :notices[0].Id AND TaskSubtype != 'Email'],
            'Reissuing should update the existing follow-up Task, not create a second one.'
        );
        Assert.areEqual(1, EmailService.lastEmailsSentCount, 'A reminder email should be sent again on reissue.');
    }

    @IsTest
    static void givenOverdueInvoiceWithExistingReminderNotice_whenArrearsIssued_thenNoticeIsConvertedInPlace() {
        Tenancy__c tenancyRecord = [SELECT Id FROM Tenancy__c LIMIT 1];
        Invoice__c invoiceRecord = createInvoice(tenancyRecord.Id, 'Unpaid', Date.today().addDays(-2));

        NoticeService.issueOrReissueRentReminderNotices(new Set<Id>{ invoiceRecord.Id });
        Notice__c reminderNotice = [SELECT Id FROM Notice__c WHERE Invoice__c = :invoiceRecord.Id LIMIT 1];
        Task reminderTask = [SELECT Id FROM Task WHERE WhatId = :reminderNotice.Id AND TaskSubtype != 'Email' LIMIT 1];

        invoiceRecord.Status__c = 'Overdue';
        update invoiceRecord;

        EmailService.lastEmailsSentCount = 0;

        Test.startTest();
        NoticeService.issueOrReissueRentArrearsNotices(new Set<Id>{ invoiceRecord.Id });
        Test.stopTest();

        List<Notice__c> notices = [
            SELECT Id, Notice_Type__c, Notice_Iteration__c
            FROM Notice__c
            WHERE Invoice__c = :invoiceRecord.Id
        ];
        Assert.areEqual(1, notices.size(), 'The invoice should still have exactly one notice — converted in place, not duplicated.');
        Assert.areEqual(reminderNotice.Id, notices[0].Id, 'The same notice record should be reused/converted.');
        Assert.areEqual('Rent Arrears', notices[0].Notice_Type__c, 'The notice should now be Rent Arrears.');
        Assert.areEqual(2, notices[0].Notice_Iteration__c.intValue(), 'The iteration should continue incrementing across the conversion.');

        Task reloadedTask = [SELECT Id, Subject, Priority FROM Task WHERE Id = :reminderTask.Id];
        Assert.areEqual('Rent Arrears – Action Required', reloadedTask.Subject, 'The existing follow-up Task should be updated to the Arrears subject.');
        Assert.areEqual('High', reloadedTask.Priority, 'The existing follow-up Task should be escalated to High priority.');
        Assert.areEqual(
            1,
            [SELECT COUNT() FROM Task WHERE WhatId = :reminderNotice.Id AND TaskSubtype != 'Email'],
            'Converting to Arrears should update the existing Task, not create a second one.'
        );

        Assert.areEqual(1, EmailService.lastEmailsSentCount, 'One arrears email should have been sent.');
    }

    @IsTest
    static void givenClosedTask_whenReissuedAgain_thenNoticeIsNotReissuedAndNoEmailIsSent() {
        Tenancy__c tenancyRecord = [SELECT Id FROM Tenancy__c LIMIT 1];
        Invoice__c invoiceRecord = createInvoice(tenancyRecord.Id, 'Overdue', Date.today().addDays(-2));

        NoticeService.issueOrReissueRentArrearsNotices(new Set<Id>{ invoiceRecord.Id });

        Notice__c noticeRecord = [SELECT Id FROM Notice__c WHERE Invoice__c = :invoiceRecord.Id LIMIT 1];
        Task taskRecord = [SELECT Id FROM Task WHERE WhatId = :noticeRecord.Id AND TaskSubtype != 'Email' LIMIT 1];
        taskRecord.Status = 'Completed';
        update taskRecord;

        EmailService.lastEmailsSentCount = 0;

        Test.startTest();
        NoticeService.issueOrReissueRentArrearsNotices(new Set<Id>{ invoiceRecord.Id });
        Test.stopTest();

        Notice__c reloadedNotice = [SELECT Notice_Iteration__c FROM Notice__c WHERE Id = :noticeRecord.Id];
        Assert.areEqual(1, reloadedNotice.Notice_Iteration__c.intValue(), 'Iteration should not increase once the task is closed.');
        Assert.areEqual(0, EmailService.lastEmailsSentCount, 'No further email should be sent once the task is closed.');
    }

    @IsTest
    static void givenInvoicePaid_whenClosed_thenNoticeIsArchivedAndTaskIsCompleted() {
        Tenancy__c tenancyRecord = [SELECT Id FROM Tenancy__c LIMIT 1];
        Invoice__c invoiceRecord = createInvoice(tenancyRecord.Id, 'Overdue', Date.today().addDays(-2));

        NoticeService.issueOrReissueRentArrearsNotices(new Set<Id>{ invoiceRecord.Id });

        Test.startTest();
        NoticeService.closeNoticesForPaidInvoices(new Set<Id>{ invoiceRecord.Id });
        Test.stopTest();

        Notice__c noticeRecord = [SELECT Status__c FROM Notice__c WHERE Invoice__c = :invoiceRecord.Id LIMIT 1];
        Assert.areEqual('Archived', noticeRecord.Status__c, 'The notice should be archived once the invoice is paid.');

        Task taskRecord = [SELECT Status FROM Task WHERE WhatId = :noticeRecord.Id AND TaskSubtype != 'Email' LIMIT 1];
        Assert.areEqual('Completed', taskRecord.Status, 'The follow-up Task should be completed once the invoice is paid.');
    }

    @IsTest
    static void givenReminderNoticePaidBeforeBecomingOverdue_whenClosed_thenReminderNoticeIsArchived() {
        Tenancy__c tenancyRecord = [SELECT Id FROM Tenancy__c LIMIT 1];
        Invoice__c invoiceRecord = createInvoice(tenancyRecord.Id, 'Unpaid', Date.today().addDays(1));

        NoticeService.issueOrReissueRentReminderNotices(new Set<Id>{ invoiceRecord.Id });

        Test.startTest();
        NoticeService.closeNoticesForPaidInvoices(new Set<Id>{ invoiceRecord.Id });
        Test.stopTest();

        Notice__c noticeRecord = [SELECT Status__c, Notice_Type__c FROM Notice__c WHERE Invoice__c = :invoiceRecord.Id LIMIT 1];
        Assert.areEqual('Rent Reminder', noticeRecord.Notice_Type__c, 'The notice should still be Rent Reminder — it never escalated.');
        Assert.areEqual('Archived', noticeRecord.Status__c, 'A still-Rent-Reminder notice should also be archived once its invoice is paid.');
    }

    @IsTest
    static void givenOtherInvoiceStillOverdue_whenOneInvoiceClosed_thenOnlyItsNoticeIsArchived() {
        Tenancy__c tenancyRecord = [SELECT Id FROM Tenancy__c LIMIT 1];
        Invoice__c paidInvoice = createInvoice(tenancyRecord.Id, 'Overdue', Date.today().addDays(-10));
        Invoice__c stillOverdueInvoice = createInvoice(tenancyRecord.Id, 'Overdue', Date.today().addDays(-2));

        NoticeService.issueOrReissueRentArrearsNotices(new Set<Id>{ paidInvoice.Id, stillOverdueInvoice.Id });

        Test.startTest();
        NoticeService.closeNoticesForPaidInvoices(new Set<Id>{ paidInvoice.Id });
        Test.stopTest();

        Notice__c paidNotice = [SELECT Status__c FROM Notice__c WHERE Invoice__c = :paidInvoice.Id LIMIT 1];
        Notice__c stillOpenNotice = [SELECT Status__c FROM Notice__c WHERE Invoice__c = :stillOverdueInvoice.Id LIMIT 1];
        Assert.areEqual('Archived', paidNotice.Status__c, 'Only the paid invoice notice should be archived.');
        Assert.areEqual('Published', stillOpenNotice.Status__c, 'The still-overdue invoice notice must remain open.');
    }

    @IsTest
    static void givenNullOrEmptyInvoiceIds_whenProcessed_thenNothingHappens() {
        EmailService.lastEmailsSentCount = 0;

        Test.startTest();
        NoticeService.issueOrReissueRentReminderNotices(null);
        NoticeService.issueOrReissueRentReminderNotices(new Set<Id>());
        NoticeService.issueOrReissueRentArrearsNotices(null);
        NoticeService.issueOrReissueRentArrearsNotices(new Set<Id>());
        NoticeService.closeNoticesForPaidInvoices(null);
        NoticeService.closeNoticesForPaidInvoices(new Set<Id>());
        Test.stopTest();

        Assert.areEqual(0, [SELECT COUNT() FROM Notice__c], 'No notice should be created for empty input.');
        Assert.areEqual(0, EmailService.lastEmailsSentCount, 'No email should be sent for empty input.');
    }

    @IsTest
    static void givenBulkUnpaidAndOverdueInvoicesAcrossTenancies_whenProcessed_thenAllAreHandled() {
        Account landlord = new Account(Name = 'Bulk Notice Landlord');
        insert landlord;
        Property__c propertyRecord = new Property__c(Property_Type__c = 'House', Landlord__c = landlord.Id);
        insert propertyRecord;

        List<Account> tenantAccounts = new List<Account>();
        for (Integer i = 0; i < 50; i++) {
            tenantAccounts.add(new Account(Name = 'Bulk Notice Tenant Account ' + i));
        }
        insert tenantAccounts;

        List<Contact> tenantContacts = new List<Contact>();
        for (Integer i = 0; i < 50; i++) {
            tenantContacts.add(new Contact(
                FirstName = 'Bulk' + i,
                LastName = 'Tenant',
                Email = 'bulk.tenant' + i + '@rentit.test',
                AccountId = tenantAccounts[i].Id
            ));
        }
        insert tenantContacts;

        List<Tenancy__c> tenancies = new List<Tenancy__c>();
        for (Integer i = 0; i < 50; i++) {
            tenancies.add(new Tenancy__c(
                Property__c = propertyRecord.Id,
                Tenant__c = tenantContacts[i].Id,
                Status__c = 'Active'
            ));
        }
        insert tenancies;

        List<Invoice__c> invoicesToInsert = new List<Invoice__c>();
        for (Integer i = 0; i < 25; i++) {
            invoicesToInsert.add(new Invoice__c(
                Tenancy__c = tenancies[i].Id,
                Amount__c = 1000,
                Category__c = 'Rent',
                Invoice_Date__c = Date.today().addDays(-6),
                Due_Date__c = Date.today().addDays(1),
                Period_Start__c = Date.today().addDays(-6),
                Period_End__c = Date.today().addDays(1),
                Status__c = 'Scheduled'
            ));
        }
        for (Integer i = 25; i < 50; i++) {
            invoicesToInsert.add(new Invoice__c(
                Tenancy__c = tenancies[i].Id,
                Amount__c = 1000,
                Category__c = 'Rent',
                Invoice_Date__c = Date.today().addDays(-9),
                Due_Date__c = Date.today().addDays(-2),
                Period_Start__c = Date.today().addDays(-9),
                Period_End__c = Date.today().addDays(-2),
                Status__c = 'Scheduled'
            ));
        }
        insert invoicesToInsert;

        Set<Id> unpaidIds = new Set<Id>();
        Set<Id> overdueIds = new Set<Id>();
        for (Integer i = 0; i < invoicesToInsert.size(); i++) {
            invoicesToInsert[i].Status__c = i < 25 ? 'Unpaid' : 'Overdue';
            (i < 25 ? unpaidIds : overdueIds).add(invoicesToInsert[i].Id);
        }
        update invoicesToInsert;

        Test.startTest();
        NoticeService.issueOrReissueRentReminderNotices(unpaidIds);
        Integer emailsSentForReminders = EmailService.lastEmailsSentCount;
        NoticeService.issueOrReissueRentArrearsNotices(overdueIds);
        Integer emailsSentForArrears = EmailService.lastEmailsSentCount;
        Test.stopTest();

        Assert.areEqual(
            25,
            [SELECT COUNT() FROM Notice__c WHERE Notice_Type__c = 'Rent Reminder'],
            'Every unpaid invoice should get its own Rent Reminder notice.'
        );
        Assert.areEqual(
            25,
            [SELECT COUNT() FROM Notice__c WHERE Notice_Type__c = 'Rent Arrears'],
            'Every overdue invoice should get its own Rent Arrears notice.'
        );
        // lastEmailsSentCount reflects only the most recent EmailService call, so each bucket is
        // captured immediately after its own NoticeService call rather than summed at the end.
        Assert.areEqual(25, emailsSentForReminders, 'Every unpaid-bucket tenant should receive a reminder email.');
        Assert.areEqual(25, emailsSentForArrears, 'Every overdue-bucket tenant should receive an arrears email.');
    }

    @IsTest
    static void givenGeneralSpecificTenantNoticePublished_whenSent_thenTenantEmailedAndMarkedSent() {
        Tenancy__c tenancyRecord = [SELECT Id FROM Tenancy__c LIMIT 1];
        Notice__c noticeRecord = new Notice__c(
            Name = 'Lease Renewal Notice',
            Audience__c = 'Specific Tenant',
            Tenancy__c = tenancyRecord.Id,
            Notice_Type__c = 'Lease Renewal',
            Status__c = 'Draft',
            Effective_Date__c = Date.today()
        );
        insert noticeRecord;

        EmailService.lastEmailsSentCount = 0;

        Test.startTest();
        noticeRecord.Status__c = 'Published';
        update noticeRecord;
        Test.stopTest();

        Notice__c reloaded = [SELECT Email_Sent__c FROM Notice__c WHERE Id = :noticeRecord.Id];
        Assert.isTrue(reloaded.Email_Sent__c, 'The notice should be marked as email-sent.');
        Assert.areEqual(1, EmailService.lastEmailsSentCount, 'One email should have been sent to the specific tenant.');
    }

    @IsTest
    static void givenSpecificTenantContactWithoutEmail_whenNoticePublished_thenNoEmailSentAndNotMarked() {
        Account tenantAccount = new Account(Name = 'No Email Tenant Account');
        insert tenantAccount;
        Contact tenantContactNoEmail = new Contact(FirstName = 'No', LastName = 'Email', AccountId = tenantAccount.Id);
        insert tenantContactNoEmail;
        Property__c propertyRecord = [SELECT Id FROM Property__c LIMIT 1];
        Tenancy__c tenancyNoEmail = new Tenancy__c(
            Property__c = propertyRecord.Id,
            Tenant__c = tenantContactNoEmail.Id,
            Status__c = 'Active'
        );
        insert tenancyNoEmail;

        Notice__c noticeRecord = new Notice__c(
            Name = 'General Notice',
            Audience__c = 'Specific Tenant',
            Tenancy__c = tenancyNoEmail.Id,
            Notice_Type__c = 'General Information',
            Status__c = 'Draft',
            Effective_Date__c = Date.today()
        );
        insert noticeRecord;

        EmailService.lastEmailsSentCount = 0;

        Test.startTest();
        noticeRecord.Status__c = 'Published';
        update noticeRecord;
        Test.stopTest();

        Notice__c reloaded = [SELECT Email_Sent__c FROM Notice__c WHERE Id = :noticeRecord.Id];
        Assert.isFalse(reloaded.Email_Sent__c, 'A tenant without an email should never be marked as email-sent.');
        Assert.areEqual(0, EmailService.lastEmailsSentCount, 'No email should be sent when the tenant has no email.');
    }

    @IsTest
    static void givenAllTenantsInPropertyNoticePublished_whenSent_thenEveryActiveTenantEmailed() {
        Account landlord = new Account(Name = 'All Tenants Notice Landlord');
        insert landlord;
        Property__c propertyRecord = new Property__c(Property_Type__c = 'House', Landlord__c = landlord.Id);
        insert propertyRecord;

        List<Account> tenantAccounts = new List<Account>();
        for (Integer i = 0; i < 3; i++) {
            tenantAccounts.add(new Account(Name = 'All Tenants Notice Tenant Account ' + i));
        }
        insert tenantAccounts;

        List<Contact> tenantContacts = new List<Contact>();
        tenantContacts.add(new Contact(FirstName = 'A', LastName = 'One', Email = 'all.one@rentit.test', AccountId = tenantAccounts[0].Id));
        tenantContacts.add(new Contact(FirstName = 'A', LastName = 'Two', Email = 'all.two@rentit.test', AccountId = tenantAccounts[1].Id));
        tenantContacts.add(new Contact(FirstName = 'A', LastName = 'NoEmail', AccountId = tenantAccounts[2].Id));
        insert tenantContacts;

        List<Tenancy__c> tenancies = new List<Tenancy__c>();
        for (Integer i = 0; i < 3; i++) {
            tenancies.add(new Tenancy__c(Property__c = propertyRecord.Id, Tenant__c = tenantContacts[i].Id, Status__c = 'Active'));
        }
        insert tenancies;

        Notice__c noticeRecord = new Notice__c(
            Name = 'Property Wide Notice',
            Audience__c = 'All Tenants in Property',
            Property__c = propertyRecord.Id,
            Notice_Type__c = 'Scheduled Maintenance',
            Status__c = 'Draft',
            Effective_Date__c = Date.today()
        );
        insert noticeRecord;

        EmailService.lastEmailsSentCount = 0;

        Test.startTest();
        noticeRecord.Status__c = 'Published';
        update noticeRecord;
        Test.stopTest();

        Notice__c reloaded = [SELECT Email_Sent__c FROM Notice__c WHERE Id = :noticeRecord.Id];
        Assert.isTrue(reloaded.Email_Sent__c, 'The notice should be marked email-sent once the property tenants have been processed, even with a mixed no-email tenant.');
        Assert.areEqual(2, EmailService.lastEmailsSentCount, 'Only the 2 tenants with an email address should receive the notice.');
    }

    @IsTest
    static void givenAlreadyPublishedNotice_whenResaved_thenNoEmailIsResent() {
        Tenancy__c tenancyRecord = [SELECT Id FROM Tenancy__c LIMIT 1];
        Notice__c noticeRecord = new Notice__c(
            Name = 'Already Published Notice',
            Audience__c = 'Specific Tenant',
            Tenancy__c = tenancyRecord.Id,
            Notice_Type__c = 'Urgent',
            Status__c = 'Published',
            Effective_Date__c = Date.today()
        );
        insert noticeRecord;

        EmailService.lastEmailsSentCount = 0;

        Test.startTest();
        noticeRecord.Content__c = '<p>Updated content, still Published.</p>';
        update noticeRecord;
        Test.stopTest();

        Assert.areEqual(0, EmailService.lastEmailsSentCount, 'Re-saving an already-Published notice should not resend the email.');
    }

    @IsTest
    static void givenRentReminderOrArrearsNoticePublishedDirectly_whenSent_thenSkippedToAvoidDuplicateEmail() {
        Tenancy__c tenancyRecord = [SELECT Id FROM Tenancy__c LIMIT 1];
        Invoice__c invoiceRecord = createInvoice(tenancyRecord.Id, 'Unpaid', Date.today().addDays(1));

        Notice__c reminderNotice = new Notice__c(
            Name = 'Manual Reminder',
            Audience__c = 'Specific Tenant',
            Tenancy__c = tenancyRecord.Id,
            Invoice__c = invoiceRecord.Id,
            Notice_Type__c = 'Rent Reminder',
            Status__c = 'Draft',
            Effective_Date__c = Date.today()
        );
        insert reminderNotice;

        EmailService.lastEmailsSentCount = 0;

        Test.startTest();
        reminderNotice.Status__c = 'Published';
        update reminderNotice;
        Test.stopTest();

        Notice__c reloaded = [SELECT Email_Sent__c FROM Notice__c WHERE Id = :reminderNotice.Id];
        Assert.isFalse(
            reloaded.Email_Sent__c,
            'sendPublishedNoticeEmails must skip Rent Reminder/Rent Arrears notices entirely — they are emailed by the dedicated Reminder/Arrears methods only.'
        );
        Assert.areEqual(0, EmailService.lastEmailsSentCount, 'No email should be sent by sendPublishedNoticeEmails for a Rent Reminder notice.');
    }

    @IsTest
    static void givenPersonAccountLandlord_whenGeneralNoticePublished_thenLandlordIsCcd() {
        Id landlordRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Landlord_Account').getRecordTypeId();

        Account landlordPersonAccount = new Account(
            RecordTypeId = landlordRecordTypeId,
            LastName = 'PublishedNoticeCcLandlord',
            PersonEmail = 'published.notice.landlord@rentit.test'
        );
        insert landlordPersonAccount;

        Property__c propertyRecord = new Property__c(Property_Type__c = 'House', Landlord__c = landlordPersonAccount.Id);
        insert propertyRecord;

        Account tenantAccount = new Account(Name = 'Published Notice Cc Tenant Account');
        insert tenantAccount;
        Contact tenantContact = new Contact(
            FirstName = 'Published',
            LastName = 'NoticeCc',
            Email = 'published.notice.tenant@rentit.test',
            AccountId = tenantAccount.Id
        );
        insert tenantContact;
        Tenancy__c tenancyRecord = new Tenancy__c(
            Property__c = propertyRecord.Id,
            Tenant__c = tenantContact.Id,
            Status__c = 'Active'
        );
        insert tenancyRecord;

        Notice__c noticeRecord = new Notice__c(
            Name = 'Inspection Notice',
            Audience__c = 'Specific Tenant',
            Tenancy__c = tenancyRecord.Id,
            Notice_Type__c = 'Inspection Notice',
            Status__c = 'Draft',
            Effective_Date__c = Date.today()
        );
        insert noticeRecord;

        Test.startTest();
        noticeRecord.Status__c = 'Published';
        update noticeRecord;
        Test.stopTest();

        Assert.areEqual(1, EmailService.lastProcessedRequests.size(), 'One email request should have been built.');
        Assert.areEqual(
            'published.notice.landlord@rentit.test',
            EmailService.lastProcessedRequests[0].ccAddress,
            'The property landlord should be CC\'d on the published-notice email.'
        );
    }

    @IsTest
    static void givenNullOrEmptyNotices_whenSendPublishedNoticeEmailsCalled_thenNothingHappens() {
        EmailService.lastEmailsSentCount = 0;

        Test.startTest();
        NoticeService.sendPublishedNoticeEmails(null, null);
        NoticeService.sendPublishedNoticeEmails(new List<Notice__c>(), null);
        Test.stopTest();

        Assert.areEqual(0, EmailService.lastEmailsSentCount, 'No email should be sent for empty input.');
    }
}
