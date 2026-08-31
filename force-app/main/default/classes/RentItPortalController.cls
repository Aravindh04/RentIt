/**
 * Community-facing Apex controller for the RentIT Portal LWR site.
 *
 * Security contract:
 *  - All methods use WITH SHARING — community user sharing rules apply.
 *  - Never use without sharing in community-exposed controllers.
 *  - Field-level security is enforced by the UI API (@wire) and by
 *    enforcing FLS manually when using Database.query.
 *  - Tenants may only write Payment__c.Comment__c and Payment__c.Payment_Reference__c.
 */
public with sharing class RentItPortalController {

    // ──────────────────────────────────────────────────────────────
    // Tenant — Tenancy
    // ──────────────────────────────────────────────────────────────

    /**
     * Returns the active Tenancy record for the running community user.
     * The Sharing Set on Tenancy__c (keyed on Community_User__c) grants read access.
     */
    @AuraEnabled(cacheable=true)
    public static Tenancy__c getActiveTenancy() {
        return [
            SELECT Id, Name, Status__c,
                   Property__c, Property__r.Name,
                   Room__c, Room__r.Name,
                   Available_Credits__c, Total_Arrears__c,
                   Deposit_Amount__c, Total_Credits__c,
                   Total_Received__c, Total_Unpaid__c,
                   Community_User__c
            FROM   Tenancy__c
            WHERE  Community_User__c = :UserInfo.getUserId()
              AND  Status__c = 'Active'
            WITH USER_MODE
            LIMIT  1
        ];
    }

    // ──────────────────────────────────────────────────────────────
    // Tenant — Invoices
    // ──────────────────────────────────────────────────────────────

    /**
     * Returns all invoices for the running tenant's active tenancy.
     */
    @AuraEnabled(cacheable=true)
    public static List<Invoice__c> getInvoices(Id tenancyId) {
        return [
            SELECT Id, Name, Period_Start__c, Period_End__c,
                   Total_Amount__c, Total_Paid__c, Balance_Due__c,
                   GST_Amount__c, Status__c, Due_Date__c
            FROM   Invoice__c
            WHERE  Tenancy__c = :tenancyId
            WITH USER_MODE
            ORDER BY Period_Start__c DESC
        ];
    }

    // ──────────────────────────────────────────────────────────────
    // Tenant — Payments
    // ──────────────────────────────────────────────────────────────

    /**
     * Returns payment records for the running tenant, optionally filtered by Status.
     * @param tenancyId  The active tenancy Id.
     * @param statusFilter  Pass null/empty string to return all statuses.
     */
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
     * Tenants may only supply: Amount__c, Payment_Date__c, Payment_Method__c,
     * Payment_Reference__c, Comment__c. Status is forced to Pending.
     */
    @AuraEnabled
    public static Id submitPayment(Id tenancyId, Id invoiceId,
                                   Decimal amount, Date paymentDate,
                                   String paymentMethod, String paymentReference,
                                   String comment) {
        Payment__c pmt = new Payment__c(
            Tenancy__c          = tenancyId,
            Invoice__c          = invoiceId,
            Amount__c           = amount,
            Payment_Date__c     = paymentDate,
            Payment_Method__c   = paymentMethod,
            Payment_Reference__c = paymentReference,
            Comment__c          = comment,
            Status__c           = 'Pending'
        );
        // Verify FLS before insert
        SObjectAccessDecision decision = Security.stripInaccessible(
            AccessType.CREATABLE, new List<Payment__c>{ pmt });
        insert decision.getRecords();
        return ((Payment__c) decision.getRecords()[0]).Id;
    }

    // ──────────────────────────────────────────────────────────────
    // Tenant — Notices
    // ──────────────────────────────────────────────────────────────

    /**
     * Returns active notices for the running tenant's tenancy.
     */
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

    /**
     * Returns aggregate portfolio stats for the landlord dashboard.
     * Landlord sees all Tenancy records via Profile-based visibility.
     */
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
            SELECT COUNT() FROM Payment__c
            WHERE Status__c = 'Pending'
            WITH USER_MODE
        ]);

        result.put('activeNotices', [
            SELECT COUNT() FROM Notice__c
            WHERE Status__c = 'Active'
            WITH USER_MODE
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
                   Community_User__c, Community_User__r.Name,
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
            WHERE  Status__c = 'Pending'
            WITH USER_MODE
            ORDER BY Payment_Date__c ASC
        ];
    }

    /**
     * Approve or reject a payment. newStatus must be 'Approved' or 'Rejected'.
     */
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
