/**
 * Community-facing Apex controller for the RentIT Landlord Portal (LWR site).
 *
 * Security contract:
 *  - Declared `without sharing` because Partner Community licenses cannot be
 *    granted ViewAllRecords/ModifyAllRecords on the custom objects. Instead,
 *    EVERY query and DML in this class is scoped to the running landlord's
 *    own Account via getLandlordAccountId(), which resolves
 *    User.AccountId for the running user. A landlord can therefore only ever
 *    reach Properties where Landlord__c = their own Account, and records that
 *    hang off those Properties.
 *  - assertOwnsTenancy() / assertOwnsProperty() guard every write path.
 *  - Field-level security on writes is enforced with Security.stripInaccessible.
 */
public without sharing class RentItLandlordController {

    // ──────────────────────────────────────────────────────────────
    // Identity + ownership guards
    // ──────────────────────────────────────────────────────────────

    /** Resolves the Account (Landlord) behind the running community user. */
    private static Id getLandlordAccountId() {
        List<User> us = [
            SELECT AccountId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1
        ];
        if (us.isEmpty() || us[0].AccountId == null) {
            throw new AuraHandledException('Your user is not linked to a Landlord account.');
        }
        return us[0].AccountId;
    }

    /** Throws unless the given Tenancy sits under a Property this landlord owns. */
    private static void assertOwnsTenancy(Id tenancyId) {
        Id acc = getLandlordAccountId();
        Integer n = [
            SELECT COUNT() FROM Tenancy__c
            WHERE  Id = :tenancyId AND Property__r.Landlord__c = :acc
        ];
        if (n == 0) {
            throw new AuraHandledException('You do not have access to this tenancy.');
        }
    }

    /** Throws unless the given Property belongs to this landlord. */
    private static void assertOwnsProperty(Id propertyId) {
        Id acc = getLandlordAccountId();
        Integer n = [
            SELECT COUNT() FROM Property__c
            WHERE  Id = :propertyId AND Landlord__c = :acc
        ];
        if (n == 0) {
            throw new AuraHandledException('You do not have access to this property.');
        }
    }

    // ──────────────────────────────────────────────────────────────
    // Dashboard — portfolio KPIs
    // ──────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getPortfolioSummary() {
        Id acc = getLandlordAccountId();
        Map<String, Object> r = new Map<String, Object>();

        r.put('properties', [SELECT COUNT() FROM Property__c WHERE Landlord__c = :acc]);
        r.put('activeTenancies', [
            SELECT COUNT() FROM Tenancy__c
            WHERE Property__r.Landlord__c = :acc AND Status__c = 'Active'
        ]);
        r.put('pendingApprovals', [
            SELECT COUNT() FROM Payment__c
            WHERE Tenancy__r.Property__r.Landlord__c = :acc
              AND Status__c = 'Pending Approval'
        ]);
        r.put('openCases', [
            SELECT COUNT() FROM Case
            WHERE Property__r.Landlord__c = :acc AND IsClosed = false
        ]);

        AggregateResult[] fin = [
            SELECT SUM(Total_Arrears__c) arrears,
                   SUM(Total_Received__c) received,
                   SUM(Total_Unpaid__c)  unpaid
            FROM   Tenancy__c
            WHERE  Property__r.Landlord__c = :acc
        ];
        if (!fin.isEmpty()) {
            r.put('totalArrears',  fin[0].get('arrears'));
            r.put('totalReceived', fin[0].get('received'));
            r.put('totalUnpaid',   fin[0].get('unpaid'));
        }
        return r;
    }

    /** Income actually received, grouped by Property — drives the income report. */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getIncomeByProperty() {
        Id acc = getLandlordAccountId();
        List<Map<String, Object>> out = new List<Map<String, Object>>();

        for (AggregateResult ar : [
            SELECT Tenancy__r.Property__c pid,
                   Tenancy__r.Property__r.Name pname,
                   SUM(Amount__c) total,
                   COUNT(Id) cnt
            FROM   Payment__c
            WHERE  Tenancy__r.Property__r.Landlord__c = :acc
              AND  Status__c = 'Received'
            GROUP BY Tenancy__r.Property__c, Tenancy__r.Property__r.Name
            ORDER BY SUM(Amount__c) DESC
        ]) {
            out.add(new Map<String, Object>{
                'propertyId'   => ar.get('pid'),
                'propertyName' => ar.get('pname'),
                'total'        => ar.get('total'),
                'paymentCount' => ar.get('cnt')
            });
        }
        return out;
    }

    // ──────────────────────────────────────────────────────────────
    // Properties + Tenancies
    // ──────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Property__c> getProperties() {
        Id acc = getLandlordAccountId();
        return [
            SELECT Id, Name, Property_Type__c, Description__c,
                   Address__Street__s, Address__City__s, Address__StateCode__s,
                   Address__PostalCode__s, Address__CountryCode__s,
                   Total_Rooms__c, Available_Rooms__c, Occupied_Rooms__c
            FROM   Property__c
            WHERE  Landlord__c = :acc
            ORDER BY Name
        ];
    }

    /** Tenancies for one property, or across the whole portfolio when null. */
    @AuraEnabled(cacheable=true)
    public static List<Tenancy__c> getTenancies(Id propertyId) {
        Id acc = getLandlordAccountId();
        if (propertyId != null) {
            assertOwnsProperty(propertyId);
            return [
                SELECT Id, Name, Status__c, Deposit_Amount__c,
                       Property__c, Property__r.Name,
                       Room__c, Room__r.Name,
                       Tenant__c, Tenant__r.Name, Tenant__r.Email, Tenant__r.Phone,
                       Total_Arrears__c, Total_Received__c, Total_Unpaid__c,
                       Available_Credits__c
                FROM   Tenancy__c
                WHERE  Property__c = :propertyId
                ORDER BY Status__c, Name
            ];
        }
        return [
            SELECT Id, Name, Status__c, Deposit_Amount__c,
                   Property__c, Property__r.Name,
                   Room__c, Room__r.Name,
                   Tenant__c, Tenant__r.Name, Tenant__r.Email, Tenant__r.Phone,
                   Total_Arrears__c, Total_Received__c, Total_Unpaid__c,
                   Available_Credits__c
            FROM   Tenancy__c
            WHERE  Property__r.Landlord__c = :acc
            ORDER BY Property__r.Name, Status__c, Name
        ];
    }

    @AuraEnabled(cacheable=true)
    public static Tenancy__c getTenancyDetail(Id tenancyId) {
        assertOwnsTenancy(tenancyId);
        return [
            SELECT Id, Name, Status__c, Deposit_Amount__c, Rent_a_room__c,
                   Property__c, Property__r.Name,
                   Room__c, Room__r.Name, Room__r.Room_Type__c, Room__r.Facilities__c,
                   Tenant__c, Tenant__r.Name, Tenant__r.Email, Tenant__r.Phone,
                   Total_Arrears__c, Total_Received__c, Total_Unpaid__c,
                   Total_Credits__c, Available_Credits__c
            FROM   Tenancy__c
            WHERE  Id = :tenancyId
            LIMIT  1
        ];
    }

    @AuraEnabled(cacheable=true)
    public static Contract getTenancyContract(Id tenancyId) {
        assertOwnsTenancy(tenancyId);
        List<Contract> cs = [
            SELECT Id, ContractNumber, Status, StartDate, EndDate,
                   Rent_Amount__c, Rent_Frequency__c, Deposit_Amount__c,
                   Special_Conditions__c
            FROM   Contract
            WHERE  Tenancy__c = :tenancyId
            ORDER BY CreatedDate DESC
            LIMIT  1
        ];
        return cs.isEmpty() ? null : cs[0];
    }

    /** Updates the landlord-editable fields on a tenancy. */
    @AuraEnabled
    public static void updateTenancy(Id tenancyId, String status, Decimal depositAmount) {
        assertOwnsTenancy(tenancyId);
        Tenancy__c t = new Tenancy__c(Id = tenancyId);
        if (String.isNotBlank(status))  t.Status__c = status;
        if (depositAmount != null)      t.Deposit_Amount__c = depositAmount;
        SObjectAccessDecision d = Security.stripInaccessible(
            AccessType.UPDATABLE, new List<Tenancy__c>{ t });
        update d.getRecords();
    }

    // ──────────────────────────────────────────────────────────────
    // Invoices
    // ──────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Invoice__c> getInvoices(Id tenancyId) {
        assertOwnsTenancy(tenancyId);
        return [
            SELECT Id, Name, Category__c, Status__c,
                   Amount__c, Discount_Amount__c, GST_Amount__c,
                   Total_Amount__c, Total_Paid__c, Balance_Due__c,
                   Invoice_Date__c, Due_Date__c, Period_Start__c, Period_End__c,
                   Discount__c, Discount__r.Name
            FROM   Invoice__c
            WHERE  Tenancy__c = :tenancyId
            ORDER BY Period_Start__c DESC
        ];
    }

    /** Issues a new invoice against a tenancy. */
    @AuraEnabled
    public static Id createInvoice(Id tenancyId, String category, Decimal amount,
                                   Decimal gstAmount, Date invoiceDate, Date dueDate,
                                   Date periodStart, Date periodEnd) {
        assertOwnsTenancy(tenancyId);
        if (amount == null || amount <= 0) {
            throw new AuraHandledException('Amount must be greater than zero.');
        }
        Invoice__c inv = new Invoice__c(
            Tenancy__c     = tenancyId,
            Category__c    = String.isBlank(category) ? 'Rent' : category,
            Amount__c      = amount,
            GST_Amount__c  = gstAmount,
            Status__c      = 'Unpaid',
            Invoice_Date__c= invoiceDate == null ? Date.today() : invoiceDate,
            Due_Date__c    = dueDate,
            Period_Start__c= periodStart,
            Period_End__c  = periodEnd
        );
        SObjectAccessDecision d = Security.stripInaccessible(
            AccessType.CREATABLE, new List<Invoice__c>{ inv });
        insert d.getRecords();
        return ((Invoice__c) d.getRecords()[0]).Id;
    }

    // ──────────────────────────────────────────────────────────────
    // Payments
    // ──────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Payment__c> getPayments(Id tenancyId) {
        assertOwnsTenancy(tenancyId);
        return [
            SELECT Id, Name, Amount__c, Status__c, Payment_Type__c,
                   Payment_Date__c, Payment_Method__c,
                   Payment_Reference__c, Comment__c,
                   Invoice__c, Invoice__r.Name
            FROM   Payment__c
            WHERE  Tenancy__c = :tenancyId
            ORDER BY Payment_Date__c DESC
        ];
    }

    /** All payments across the portfolio awaiting the landlord's approval. */
    @AuraEnabled(cacheable=true)
    public static List<Payment__c> getPendingPayments() {
        Id acc = getLandlordAccountId();
        return [
            SELECT Id, Name, Amount__c, Status__c,
                   Payment_Date__c, Payment_Method__c,
                   Payment_Reference__c, Comment__c,
                   Tenancy__c, Tenancy__r.Name,
                   Tenancy__r.Tenant__r.Name,
                   Tenancy__r.Property__r.Name,
                   Invoice__c, Invoice__r.Name
            FROM   Payment__c
            WHERE  Tenancy__r.Property__r.Landlord__c = :acc
              AND  Status__c = 'Pending Approval'
            ORDER BY Payment_Date__c ASC
        ];
    }

    /**
     * Approves or rejects a submitted payment through the standard Approval
     * Process, so the configured approve/reject email actions still fire.
     * action must be 'Approve' or 'Reject'.
     */
    @AuraEnabled
    public static void processPaymentApproval(Id paymentId, String action, String comments) {
        if (action != 'Approve' && action != 'Reject') {
            throw new AuraHandledException('Invalid action: ' + action);
        }
        Id acc = getLandlordAccountId();
        Integer owned = [
            SELECT COUNT() FROM Payment__c
            WHERE  Id = :paymentId AND Tenancy__r.Property__r.Landlord__c = :acc
        ];
        if (owned == 0) {
            throw new AuraHandledException('You do not have access to this payment.');
        }

        List<ProcessInstanceWorkitem> items = [
            SELECT Id FROM ProcessInstanceWorkitem
            WHERE  ProcessInstance.TargetObjectId = :paymentId
              AND  ProcessInstance.Status = 'Pending'
            LIMIT  1
        ];
        if (items.isEmpty()) {
            throw new AuraHandledException('No pending approval request found for this payment.');
        }

        Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
        req.setWorkitemId(items[0].Id);
        req.setAction(action);
        if (String.isNotBlank(comments)) req.setComments(comments);
        Approval.process(req);
    }

    // ──────────────────────────────────────────────────────────────
    // Discounts
    // ──────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Discount__c> getDiscounts(Id tenancyId) {
        assertOwnsTenancy(tenancyId);
        return [
            SELECT Id, Name, Discount_Type__c, Discount_Value__c,
                   Start_Date__c, End_Date__c, Description__c,
                   Contract__c, Contract__r.ContractNumber
            FROM   Discount__c
            WHERE  Tenancy__c = :tenancyId
            ORDER BY Start_Date__c DESC
        ];
    }

    /** Adds a discount to a tenancy. */
    @AuraEnabled
    public static Id createDiscount(Id tenancyId, String name, String discountType,
                                    Decimal discountValue, Date startDate, Date endDate,
                                    String description) {
        assertOwnsTenancy(tenancyId);
        if (discountValue == null || discountValue <= 0) {
            throw new AuraHandledException('Discount value must be greater than zero.');
        }
        if (startDate == null) {
            throw new AuraHandledException('Start date is required.');
        }
        if (endDate != null && endDate < startDate) {
            throw new AuraHandledException('End date cannot be before the start date.');
        }
        Discount__c d = new Discount__c(
            Tenancy__c       = tenancyId,
            Name             = String.isBlank(name) ? 'Discount' : name,
            Discount_Type__c = discountType,
            Discount_Value__c= discountValue,
            Start_Date__c    = startDate,
            End_Date__c      = endDate,
            Description__c   = description
        );
        SObjectAccessDecision dec = Security.stripInaccessible(
            AccessType.CREATABLE, new List<Discount__c>{ d });
        insert dec.getRecords();
        return ((Discount__c) dec.getRecords()[0]).Id;
    }

    // ──────────────────────────────────────────────────────────────
    // Cases — requests and complaints
    // ──────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Case> getCases() {
        Id acc = getLandlordAccountId();
        return [
            SELECT Id, CaseNumber, Subject, Description, Status, Priority,
                   Type, Origin, CreatedDate, IsClosed,
                   RecordType.Name,
                   Tenancy__c, Tenancy__r.Name,
                   Property__c, Property__r.Name,
                   Room__c, Room__r.Name,
                   Contact.Name
            FROM   Case
            WHERE  Property__r.Landlord__c = :acc
            ORDER BY CreatedDate DESC
        ];
    }

    /** Lets the landlord move a case along (e.g. Working, Closed). */
    @AuraEnabled
    public static void updateCaseStatus(Id caseId, String status) {
        Id acc = getLandlordAccountId();
        Integer owned = [
            SELECT COUNT() FROM Case
            WHERE  Id = :caseId AND Property__r.Landlord__c = :acc
        ];
        if (owned == 0) {
            throw new AuraHandledException('You do not have access to this case.');
        }
        Case c = new Case(Id = caseId, Status = status);
        SObjectAccessDecision d = Security.stripInaccessible(
            AccessType.UPDATABLE, new List<Case>{ c });
        update d.getRecords();
    }
}
