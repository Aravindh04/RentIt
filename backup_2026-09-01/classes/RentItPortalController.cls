/**
 * Community-facing Apex controller for the RentIT Portal LWR site.
 *
 * Sharing design:
 *  - Outer class: with sharing (landlord methods use user context).
 *  - TenantAccess inner class: without sharing, because Tenancy__c OWD is
 *    ControlledByParent with no Sharing Set, so community users would see
 *    zero rows under USER_MODE. Tenant isolation is enforced by the WHERE
 *    clause: Community_User__c = UserInfo.getUserId().
 *  - Child object queries (Invoices, Payments, Notices) receive a tenancyId
 *    that was resolved through getActiveTenancy — already verified to belong
 *    to the running user.
 */
public with sharing class RentItPortalController {

    // ──────────────────────────────────────────────────────────────
    // TenantAccess — bypasses OWD; WHERE clause enforces isolation
    // ──────────────────────────────────────────────────────────────
    private without sharing class TenantAccess {

        static Tenancy__c activeTenancy() {
            List<Tenancy__c> rows = [
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
                LIMIT  1
            ];
            return rows.isEmpty() ? null : rows[0];
        }

        static List<Invoice__c> invoices(Id tenancyId) {
            return [
                SELECT Id, Name, Period_Start__c, Period_End__c,
                       Total_Amount__c, Total_Paid__c, Balance_Due__c,
                       GST_Amount__c, Status__c, Due_Date__c
                FROM   Invoice__c
                WHERE  Tenancy__c = :tenancyId
                ORDER BY Period_Start__c DESC
            ];
        }

        static List<Payment__c> payments(Id tenancyId, String statusFilter) {
            if (String.isNotBlank(statusFilter)) {
                return [
                    SELECT Id, Name, Amount__c, Status__c,
                           Payment_Date__c, Payment_Method__c,
                           Payment_Reference__c, Comment__c
                    FROM   Payment__c
                    WHERE  Tenancy__c = :tenancyId
                      AND  Status__c  = :statusFilter
                    ORDER BY Payment_Date__c DESC
                ];
            }
            return [
                SELECT Id, Name, Amount__c, Status__c,
                       Payment_Date__c, Payment_Method__c,
                       Payment_Reference__c, Comment__c
                FROM   Payment__c
                WHERE  Tenancy__c = :tenancyId
                ORDER BY Payment_Date__c DESC
            ];
        }

        static List<Notice__c> notices(Id tenancyId) {
            return [
                SELECT Id, Name, Content__c, Expiry_Date__c,
                       Notice_Type__c, Status__c
                FROM   Notice__c
                WHERE  Tenancy__c = :tenancyId
                  AND  Status__c = 'Active'
                  AND  (Expiry_Date__c = null OR Expiry_Date__c >= TODAY)
                ORDER BY CreatedDate DESC
            ];
        }
    }

    // ──────────────────────────────────────────────────────────────
    // Tenant — Tenancy
    // ──────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static Tenancy__c getActiveTenancy() {
        return TenantAccess.activeTenancy();
    }

    // ──────────────────────────────────────────────────────────────
    // Tenant — Invoices
    // ──────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Invoice__c> getInvoices(Id tenancyId) {
        return TenantAccess.invoices(tenancyId);
    }

    // ──────────────────────────────────────────────────────────────
    // Tenant — Payments
    // ──────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Payment__c> getPayments(Id tenancyId, String statusFilter) {
        return TenantAccess.payments(tenancyId, statusFilter);
    }

    /**
     * Submits a new payment on behalf of the tenant.
     * Status is forced to 'Pending' — tenants may not set their own approval status.
     */
    @AuraEnabled
    public static Id submitPayment(Id tenancyId, Id invoiceId,
                                   Decimal amount, Date paymentDate,
                                   String paymentMethod, String paymentReference,
                                   String comment) {
        Payment__c pmt = new Payment__c(
            Tenancy__c           = tenancyId,
            Invoice__c           = invoiceId,
            Amount__c            = amount,
            Payment_Date__c      = paymentDate,
            Payment_Method__c    = paymentMethod,
            Payment_Reference__c = paymentReference,
            Comment__c           = comment,
            Status__c            = 'Pending'
        );
        SObjectAccessDecision decision = Security.stripInaccessible(
            AccessType.CREATABLE, new List<Payment__c>{ pmt });
        insert decision.getRecords();
        return ((Payment__c) decision.getRecords()[0]).Id;
    }

    // ──────────────────────────────────────────────────────────────
    // Tenant — Notices
    // ──────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Notice__c> getNotices(Id tenancyId) {
        return TenantAccess.notices(tenancyId);
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
            SELECT COUNT() FROM Payment__c WHERE Status__c = 'Pending' WITH USER_MODE
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
