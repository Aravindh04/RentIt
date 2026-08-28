public class InvoiceBatch implements Database.Batchable<SObject> {

    private static final Integer LOOKAHEAD_DAYS = 30;

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

        Map<Id, Set<Date>> existingPeriodStartsByTenancy = new Map<Id, Set<Date>>();
        for (Id tid : tenancyIds) {
            existingPeriodStartsByTenancy.put(tid, new Set<Date>());
        }
        for (Invoice__c inv : [
            SELECT Id, Tenancy__c, Period_Start__c
            FROM Invoice__c
            WHERE Tenancy__c IN :tenancyIds
            AND Status__c NOT IN ('Void')
            AND Due_Date__c >= :Date.today()
        ]) {
            existingPeriodStartsByTenancy.get(inv.Tenancy__c).add(inv.Period_Start__c);
        }

        Date today = Date.today();
        Date createUntil = today.addDays(LOOKAHEAD_DAYS);
        List<Invoice__c> toCreate = new List<Invoice__c>();

        for (Contract c : contracts) {
            Decimal amount = c.Rent_Amount__c;
            String freq = c.Rent_Frequency__c;
            Date startDate = c.StartDate;

            if (amount == null || freq == null || startDate == null) continue;
            if (c.EndDate != null && c.EndDate < today) continue;

            Integer intervalDays = freq == 'Weekly' ? 7 : freq == 'Fortnightly' ? 14 : 30;
            Set<Date> existingPeriods = existingPeriodStartsByTenancy.get(c.Tenancy__c);
            if (existingPeriods == null) existingPeriods = new Set<Date>();

            Date nextDue = advanceToFuture(startDate, intervalDays, today);

            while (nextDue <= createUntil) {
                if (!existingPeriods.contains(nextDue)) {
                    toCreate.add(new Invoice__c(
                        Tenancy__c      = c.Tenancy__c,
                        Amount__c       = amount,
                        Invoice_Date__c = today,
                        Due_Date__c     = nextDue,
                        Period_Start__c = nextDue,
                        Period_End__c   = nextDue.addDays(intervalDays - 1),
                        Status__c       = 'Scheduled'
                    ));
                    existingPeriods.add(nextDue);
                }
                nextDue = nextDue.addDays(intervalDays);
            }
        }

        if (!toCreate.isEmpty()) { insert toCreate; }
    }

    public void finish(Database.BatchableContext bc) {}

    private Date advanceToFuture(Date startDate, Integer intervalDays, Date today) {
        Date d = startDate;
        while (d <= today) { d = d.addDays(intervalDays); }
        return d;
    }
}
