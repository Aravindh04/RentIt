public class InvoiceBatch implements Database.Batchable<SObject> {

    private static final Integer LOOKAHEAD_DAYS = 1;

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

                    // Amount__c holds the original rent; Discount_Amount__c stores the reduction.
                    // Total_Amount__c formula = (Amount - Discount) + GST — used for credit checks.
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
                        Status__c          = applyCredit ? 'Paid' : 'Scheduled'
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

            // Credit Applied payment amount mirrors Total_Amount__c at creation time
            // (GST is 0 here, so it equals Amount__c - Discount_Amount__c).
            List<Payment__c> creditApplications = new List<Payment__c>();
            for (Invoice__c inv : toCreate) {
                if (inv.Status__c == 'Paid') {
                    Decimal discountAmt = inv.Discount_Amount__c != null ? inv.Discount_Amount__c : 0;
                    creditApplications.add(new Payment__c(
                        Tenancy__c      = inv.Tenancy__c,
                        Invoice__c      = inv.Id,
                        Payment_Type__c = 'Credit Applied',
                        Status__c       = 'Received',
                        Amount__c       = inv.Amount__c - discountAmt,
                        Payment_Date__c = today
                    ));
                }
            }
            if (!creditApplications.isEmpty()) {
                insert creditApplications;
            }
        }
    }

    public void finish(Database.BatchableContext bc) {}

    private Date advanceToFuture(Date startDate, Integer intervalDays, Date today) {
        Date d = startDate;
        while (d <= today) { d = d.addDays(intervalDays); }
        return d;
    }
}
