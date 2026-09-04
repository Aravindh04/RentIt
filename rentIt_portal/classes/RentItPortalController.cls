/**
 * Community-facing Apex controller for the RentIT Portal LWR site.
 *
 * Security contract:
 *  - All methods use WITH SHARING — community user sharing rules apply.
 *  - Tenant isolation: Tenancy__c.Tenant__c (Contact) matched against
 *    the running user's ContactId. Path: Tenancy__c.Tenant__c → Contact
 *    ← User.ContactId.
 *  - Field-level security enforced by WITH USER_MODE on reads, and by
 *    Security.stripInaccessible on writes.
 */
public with sharing class RentItPortalController {

    // ──────────────────────────────────────────────────────────────
    // Tenant — Tenancy
    // ──────────────────────────────────────────────────────────────

    /**
     * Returns the active Tenancy for the running community user.
     * Matches via Tenant__c (Contact lookup) = User.ContactId.
     */
    @AuraEnabled(cacheable=true)
    public static Tenancy__c getActiveTenancy() {
        return [
            SELECT Id, Name, Status__c,
                   Property__c, Property__r.Name,
                   Property__r.Address__Street__s, Property__r.Address__City__s,
                   Property__r.Address__StateCode__s, Property__r.Address__PostalCode__s,
                   Property__r.Address__CountryCode__s,
                   Property__r.Description__c,
                   Room__c, Room__r.Name,
                   Room__r.Room_Size__c, Room__r.Weekly_Rent__c, Room__r.Facilities__c,
                   Available_Credits__c, Total_Arrears__c,
                   Total_Credits__c, Total_Received__c, 
                   Total_Unpaid__c, Tenant__c
            FROM   Tenancy__c
            WHERE  Tenant__c IN (SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId())
              AND  Status__c = 'Active'
            WITH USER_MODE
            LIMIT  1
        ];
    }

    // ──────────────────────────────────────────────────────────────
    // Tenant — Profile (Contact linked to running community user)
    // ──────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static Contact getContactProfile() {
        List<Contact> contacts = [
            SELECT Id, FirstName, LastName, Email, Phone, MobilePhone,
                   MailingStreet, MailingCity, MailingState,
                   MailingPostalCode, MailingCountry,
                   Account.ABN__c, Account.GST_Number__c, Account.GST_Registered__c
            FROM   Contact
            WHERE  Id IN (SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId())
            WITH USER_MODE
            LIMIT  1
        ];
        return contacts.isEmpty() ? null : contacts[0];
    }

    // ──────────────────────────────────────────────────────────────
    // Tenant — Contract
    // ──────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static Contract getContract(Id tenancyId) {
        if (tenancyId == null) return null;
        return RentItPortalDataHelper.getContractForTenancy(tenancyId);
    }

    @AuraEnabled(cacheable=true)
    public static List<ContentDocumentLink> getContractFiles(Id contractId, Id tenancyId) {
        if (contractId == null || tenancyId == null) return new List<ContentDocumentLink>();
        return RentItPortalDataHelper.getContractFilesForTenancy(contractId, tenancyId);
    }

    // ──────────────────────────────────────────────────────────────
    // Tenant — Invoices
    // ──────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Invoice__c> getInvoices(Id tenancyId) {
        return [
            SELECT Id, Name, Category__c, Period_Start__c, Period_End__c,
                   Amount__c, Total_Amount__c, Total_Paid__c, Balance_Due__c,
                   GST_Amount__c, Status__c, Due_Date__c,
                   Discount__c, Discount_Amount__c,
                   Discount__r.Discount_Type__c, Discount__r.Discount_Value__c,
                   Discount__r.Start_Date__c, Discount__r.End_Date__c
            FROM   Invoice__c
            WHERE  Tenancy__c = :tenancyId
            WITH USER_MODE
            ORDER BY Period_Start__c DESC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<ContentDocumentLink> getPaymentFiles(Id paymentId, Id tenancyId) {
        if (paymentId == null || tenancyId == null) return new List<ContentDocumentLink>();
        return RentItPortalDataHelper.getPaymentFilesForTenancy(paymentId, tenancyId);
    }

    // ──────────────────────────────────────────────────────────────
    // Tenant — Payments
    // ──────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Payment__c> getPayments(Id tenancyId, String statusFilter) {
        if (String.isNotBlank(statusFilter)) {
            return [
                SELECT Id, Name, Amount__c, Status__c,
                       Payment_Date__c, Payment_Method__c,
                       Payment_Reference__c, Comment__c
                FROM   Payment__c
                WHERE  Tenancy__c = :tenancyId
                  AND  Status__c  = :statusFilter
                WITH USER_MODE
                ORDER BY Payment_Date__c DESC
            ];
        }
        return [
            SELECT Id, Name, Amount__c, Status__c,
                   Payment_Date__c, Payment_Method__c,
                   Payment_Reference__c, Comment__c
            FROM   Payment__c
            WHERE  Tenancy__c = :tenancyId
            WITH USER_MODE
            ORDER BY Payment_Date__c DESC
        ];
    }

    /**
     * Submits a new payment on behalf of the tenant.
     * Status is forced to 'Pending Approval' — tenants cannot set their own approval status.
     */
    @AuraEnabled
    public static Id submitPayment(Id tenancyId, Id invoiceId,
                                   Decimal amount, Date paymentDate,
                                   String paymentMethod, String paymentReference,
                                   String comment,
                                   String base64Content, String fileName, String contentType) {
        Payment__c pmt = new Payment__c(
            Tenancy__c           = tenancyId,
            Invoice__c           = invoiceId,
            Amount__c            = amount,
            Payment_Date__c      = paymentDate,
            Payment_Method__c    = paymentMethod,
            Payment_Reference__c = paymentReference,
            Comment__c           = comment,
            Status__c            = 'Pending Approval'
        );
        SObjectAccessDecision decision = Security.stripInaccessible(
            AccessType.CREATABLE, new List<Payment__c>{ pmt });
        insert decision.getRecords();
        Id paymentId = ((Payment__c) decision.getRecords()[0]).Id;

        if (String.isNotBlank(base64Content)) {
            ContentVersion cv = new ContentVersion(
                Title                  = String.isNotBlank(fileName) ? fileName : 'Payment Screenshot',
                PathOnClient           = String.isNotBlank(fileName) ? fileName : 'screenshot.jpg',
                VersionData            = EncodingUtil.base64Decode(base64Content),
                FirstPublishLocationId = paymentId
            );
            insert cv;
        }

        return paymentId;
    }

    // ──────────────────────────────────────────────────────────────
    // Tenant — Notices
    // ──────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Notice__c> getNotices(Id tenancyId) {
        return [
            SELECT Id, Name, Content__c, Expiry_Date__c,
                   Notice_Type__c, Status__c
            FROM   Notice__c
            WHERE  Tenancy__c = :tenancyId
              AND  Status__c = 'Active'
              AND  (Expiry_Date__c = null OR Expiry_Date__c >= TODAY)
            WITH USER_MODE
            ORDER BY CreatedDate DESC
        ];
    }

    // ──────────────────────────────────────────────────────────────
    // Landlord — Portfolio summary
    // ──────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getPortfolioSummary() {
        Map<String, Object> result = new Map<String, Object>();

        AggregateResult[] agg = [
            SELECT COUNT(Id) total,
                   SUM(Total_Arrears__c) totalArrears,
                   SUM(Total_Credits__c) totalCredits
            FROM   Tenancy__c
            WHERE  Status__c = 'Active'
            WITH USER_MODE
        ];
        if (!agg.isEmpty()) {
            result.put('activeTenancies', agg[0].get('total'));
            result.put('totalArrears',    agg[0].get('totalArrears'));
            result.put('totalCredits',    agg[0].get('totalCredits'));
        }

        result.put('pendingPayments', [
            SELECT COUNT() FROM Payment__c WHERE Status__c = 'Pending Approval' WITH USER_MODE
        ]);
        result.put('activeNotices', [
            SELECT COUNT() FROM Notice__c WHERE Status__c = 'Active' WITH USER_MODE
        ]);

        return result;
    }

    // ──────────────────────────────────────────────────────────────
    // Landlord — Tenancy list
    // ──────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Tenancy__c> getAllTenancies() {
        return [
            SELECT Id, Name, Status__c,
                   Property__c, Property__r.Name,
                   Room__c, Room__r.Name,
                   Tenant__c, Tenant__r.Name,
                   Total_Arrears__c, Total_Credits__c,
                   Total_Received__c, Total_Unpaid__c
            FROM   Tenancy__c
            WITH USER_MODE
            ORDER BY Property__r.Name, Status__c
        ];
    }

    // ──────────────────────────────────────────────────────────────
    // Landlord — Payment approval
    // ──────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Payment__c> getPendingPayments() {
        return [
            SELECT Id, Name, Amount__c, Status__c,
                   Payment_Date__c, Payment_Method__c,
                   Payment_Reference__c, Comment__c,
                   Tenancy__c, Tenancy__r.Name,
                   Invoice__c, Invoice__r.Name
            FROM   Payment__c
            WHERE  Status__c = 'Pending Approval'
            WITH USER_MODE
            ORDER BY Payment_Date__c ASC
        ];
    }

    @AuraEnabled
    public static void updatePaymentStatus(Id paymentId, String newStatus) {
        if (newStatus != 'Approved' && newStatus != 'Rejected') {
            throw new AuraHandledException('Invalid status: ' + newStatus);
        }
        Payment__c pmt = new Payment__c(Id = paymentId, Status__c = newStatus);
        SObjectAccessDecision decision = Security.stripInaccessible(
            AccessType.UPDATABLE, new List<Payment__c>{ pmt });
        update decision.getRecords();
    }

    // ──────────────────────────────────────────────────────────────
    // Landlord — Notice management
    // ──────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Notice__c> getAllNotices() {
        return [
            SELECT Id, Name, Content__c, Expiry_Date__c,
                   Notice_Type__c, Status__c,
                   Tenancy__c, Tenancy__r.Name,
                   Property__c, Property__r.Name
            FROM   Notice__c
            WITH USER_MODE
            ORDER BY CreatedDate DESC
        ];
    }
}
