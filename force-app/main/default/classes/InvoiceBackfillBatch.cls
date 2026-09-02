public class InvoiceBackfillBatch implements Database.Batchable<SObject> {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Tenancy__c, Rent_Amount__c, Rent_Frequency__c,
                   StartDate, EndDate, Status,
                   Tenancy__r.Id, Tenancy__r.Status__c
            FROM Contract
            WHERE Status = 'Activated'
            AND Tenancy__c != null
            AND StartDate <= :Date.today()
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

        // Fetch full invoice history — not just future — to skip already-created periods
        Map<Id, Set<Date>> existingPeriodsByTenancy = new Map<Id, Set<Date>>();
        for (Id tid : tenancyIds) {
            existingPeriodsByTenancy.put(tid, new Set<Date>());
        }
        for (Invoice__c inv : [
            SELECT Id, Tenancy__c, Period_Start__c
            FROM Invoice__c
            WHERE Tenancy__c IN :tenancyIds
            AND Status__c != 'Void'
        ]) {
            existingPeriodsByTenancy.get(inv.Tenancy__c).add(inv.Period_Start__c);
        }

        Date today = Date.today();
        List<Invoice__c> toCreate = new List<Invoice__c>();

        for (Contract c : contracts) {
            Decimal amount    = c.Rent_Amount__c;
            String  freq      = c.Rent_Frequency__c;
            Date    startDate = c.StartDate;

            if (amount == null || freq == null || startDate == null) continue;

            Integer intervalDays = freq == 'Weekly' ? 7 : freq == 'Fortnightly' ? 14 : 30;

            // Cap at the earlier of contract end and today
            Date ceiling = (c.EndDate != null && c.EndDate < today) ? c.EndDate : today;

            Set<Date> existingPeriods = existingPeriodsByTenancy.get(c.Tenancy__c);
            if (existingPeriods == null) existingPeriods = new Set<Date>();

            Decimal credits = availableCreditsByTenancy.containsKey(c.Tenancy__c)
                ? availableCreditsByTenancy.get(c.Tenancy__c) : 0;

            Date periodStart = startDate;
            while (periodStart <= ceiling) {
                if (!existingPeriods.contains(periodStart)) {
                    Date periodEnd = periodStart.addDays(intervalDays - 1);

                    DiscountCalculator.Result dr = DiscountCalculator.apply(
                        amount, periodStart, periodEnd, c.Id,
                        discountsByTenancy.get(c.Tenancy__c)
                    );

                    Decimal netAmount   = (amount - dr.discountAmount).setScale(2);
                    Boolean applyCredit = credits >= netAmount;
                    String  status;
                    if (applyCredit) {
                        status = 'Paid';
                    } else if (periodStart < today) {
                        status = 'Overdue';
                    } else {
                        status = 'Unpaid';
                    }

                    toCreate.add(new Invoice__c(
                        Tenancy__c         = c.Tenancy__c,
                        Amount__c          = amount,
                        Discount_Amount__c = dr.discountAmount > 0 ? dr.discountAmount : null,
                        Discount__c        = dr.primaryDiscountId,
                        Invoice_Date__c    = periodStart,
                        Due_Date__c        = periodStart,
                        Period_Start__c    = periodStart,
                        Period_End__c      = periodEnd,
                        Status__c          = status
                    ));
                    existingPeriods.add(periodStart);

                    if (applyCredit) {
                        credits -= netAmount;
                        availableCreditsByTenancy.put(c.Tenancy__c, credits);
                    }
                }
                periodStart = periodStart.addDays(intervalDays);
            }
        }

        if (!toCreate.isEmpty()) {
            insert toCreate;

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
                        Payment_Date__c = inv.Invoice_Date__c
                    ));
                }
            }
            if (!creditApplications.isEmpty()) {
                insert creditApplications;
            }
        }
    }

    public void finish(Database.BatchableContext bc) {}
}
