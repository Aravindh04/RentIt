public class InvoiceBatch implements Database.Batchable<SObject> {

    // New invoices are scheduled this many days before the rent period start date.
    private static final Integer LOOKAHEAD_DAYS = 2;

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Tenancy__c, Rent_Amount__c, Rent_Frequency__c,
                   StartDate, EndDate, Status,
                   Tenancy__r.Id, Tenancy__r.Status__c
            FROM Contract
            WHERE Status = 'Activated'
            AND Tenancy__c != null
            AND Tenancy__r.Status__c = 'Active'
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Contract> contracts) {
        Set<Id> tenancyIds = new Set<Id>();
        for (Contract c : contracts) {
            tenancyIds.add(c.Tenancy__c);
        }

        Map<Id, Decimal> availableCreditsByTenancy = new Map<Id, Decimal>();
        for (Tenancy__c t : [SELECT Id, Available_Credits__c FROM Tenancy__c WHERE Id IN :tenancyIds]) {
            availableCreditsByTenancy.put(t.Id, t.Available_Credits__c != null ? t.Available_Credits__c : 0);
        }

        Map<Id, List<Discount__c>> discountsByTenancy = new Map<Id, List<Discount__c>>();
        for (Discount__c d : [
            SELECT Id, Tenancy__c, Contract__c, Discount_Type__c, Discount_Value__c,
                   Start_Date__c, End_Date__c
            FROM Discount__c
            WHERE Tenancy__c IN :tenancyIds
        ]) {
            if (!discountsByTenancy.containsKey(d.Tenancy__c)) {
                discountsByTenancy.put(d.Tenancy__c, new List<Discount__c>());
            }
            discountsByTenancy.get(d.Tenancy__c).add(d);
        }

        Map<Id, Set<Date>> existingPeriodsByTenancy = new Map<Id, Set<Date>>();
        for (Id tid : tenancyIds) {
            existingPeriodsByTenancy.put(tid, new Set<Date>());
        }
        for (Invoice__c inv : [
            SELECT Id, Tenancy__c, Period_Start__c
            FROM Invoice__c
            WHERE Tenancy__c IN :tenancyIds
            AND Status__c NOT IN ('Void')
            AND Due_Date__c >= :Date.today()
        ]) {
            existingPeriodsByTenancy.get(inv.Tenancy__c).add(inv.Period_Start__c);
        }

        Date today      = Date.today();
        Date createUntil = today.addDays(LOOKAHEAD_DAYS);
        List<Invoice__c> toCreate = new List<Invoice__c>();

        for (Contract c : contracts) {
            Decimal amount    = c.Rent_Amount__c;
            String  freq      = c.Rent_Frequency__c;
            Date    startDate = c.StartDate;

            if (amount == null || freq == null || startDate == null) continue;
            if (c.EndDate != null && c.EndDate < today) continue;

            Integer intervalDays = freq == 'Weekly' ? 7 : freq == 'Fortnightly' ? 14 : 30;
            Set<Date> existingPeriods = existingPeriodsByTenancy.get(c.Tenancy__c);
            if (existingPeriods == null) existingPeriods = new Set<Date>();

            Decimal credits = availableCreditsByTenancy.containsKey(c.Tenancy__c)
                ? availableCreditsByTenancy.get(c.Tenancy__c) : 0;

            Date nextDue = advanceToFuture(startDate, intervalDays, today);

            while (nextDue <= createUntil) {
                if (!existingPeriods.contains(nextDue)) {
                    Date periodEnd = nextDue.addDays(intervalDays - 1);

                    DiscountCalculator.Result dr = DiscountCalculator.apply(
                        amount, nextDue, periodEnd, c.Id,
                        discountsByTenancy.get(c.Tenancy__c)
                    );

                    Decimal netAmount   = (amount - dr.discountAmount).setScale(2);
                    Boolean applyCredit = credits >= netAmount;

                    toCreate.add(new Invoice__c(
                        Tenancy__c         = c.Tenancy__c,
                        Amount__c          = amount,
                        Discount_Amount__c = dr.discountAmount > 0 ? dr.discountAmount : null,
                        Discount__c        = dr.primaryDiscountId,
                        Invoice_Date__c    = today,
                        Due_Date__c        = nextDue,
                        Period_Start__c    = nextDue,
                        Period_End__c      = periodEnd,
                        Status__c          = 'Scheduled'
                    ));
                    existingPeriods.add(nextDue);
                    if (applyCredit) {
                        credits -= netAmount;
                        availableCreditsByTenancy.put(c.Tenancy__c, credits);
                    }
                }
                nextDue = nextDue.addDays(intervalDays);
            }
        }

        if (!toCreate.isEmpty()) {
            insert toCreate;
        }
    }

    // Runs once after all chunks of invoice creation have completed. Handles the
    // batch's second responsibility: keeping not-yet-paid invoices' Status__c current, and driving the
    // Rent Reminder / Rent Arrears notice lifecycle (see NoticeService) for every existing invoice that
    // is currently Unpaid or Overdue — this is what used to be four separate Flows:
    //   Rent_Payment_Scheduled_To_Unpaid, Rent_Payment_Due_Tomorrow_Reminder,
    //   Rent_Invoice_Unpaid_Task_And_Email, Rent_Payment_Overdue_Create_Notice.
    public void finish(Database.BatchableContext bc) {
        transitionUnpaidInvoiceStatuses();
    }

    private Date advanceToFuture(Date startDate, Integer intervalDays, Date today) {
        Date d = startDate;
        while (d <= today) { d = d.addDays(intervalDays); }
        return d;
    }

    // Moves every invoice that is not yet Paid (and not Void) into the correct status for today:
    //  - Due tomorrow  -> Unpaid   (1 day before Due_Date__c; also replaces Rent_Payment_Scheduled_To_Unpaid)
    //  - Due date has passed -> Overdue
    // Also collects the FULL set of invoices whose resulting status is Unpaid/Overdue today (not just
    // ones that newly transitioned), so NoticeService can issue/reissue the matching Rent Reminder /
    // Rent Arrears notice for every one of them, every day, until the tenant pays or a property manager
    // closes the notice's follow-up Task.
    private void transitionUnpaidInvoiceStatuses() {
        Date today    = Date.today();
        Date tomorrow = today.addDays(1);
        List<Invoice__c> toUpdate = new List<Invoice__c>();
        Set<Id> unpaidInvoiceIds = new Set<Id>();
        Set<Id> overdueInvoiceIds = new Set<Id>();

        for (Invoice__c inv : [
            SELECT Id, Status__c, Due_Date__c
            FROM Invoice__c
            WHERE Status__c NOT IN ('Paid', 'Void')
            AND Due_Date__c != null
        ]) {
            if (inv.Due_Date__c < today) {
                overdueInvoiceIds.add(inv.Id);
                if (inv.Status__c != 'Overdue') {
                    toUpdate.add(new Invoice__c(Id = inv.Id, Status__c = 'Overdue'));
                }
            } else if (inv.Due_Date__c == tomorrow || inv.Status__c == 'Unpaid') {
                unpaidInvoiceIds.add(inv.Id);
                if (inv.Status__c != 'Unpaid') {
                    toUpdate.add(new Invoice__c(Id = inv.Id, Status__c = 'Unpaid'));
                }
            }
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }

        // Bulk-safe: each call issues one SOQL query, one bulk DML per list, and one bulk email send
        // (Messaging.sendEmail with the whole batch of messages) — no per-invoice email sends.
        NoticeService.issueOrReissueRentReminderNotices(unpaidInvoiceIds);
        NoticeService.issueOrReissueRentArrearsNotices(overdueInvoiceIds);
    }
}
