/**
 * Retroactively applies existing Discount__c records to invoices and their Credit Applied
 * payments. Run after discounts are created for tenancies that already have invoices.
 *
 * Approach:
 *   1. Batch over Tenancy__c records that own at least one Discount
 *   2. For each chunk, load ALL discounts for those tenancies
 *   3. Query only invoices whose period overlaps the discount date range and have no
 *      discount applied yet (Discount__c = null)
 *   4. DiscountCalculator pro-rates the discount by overlap days:
 *        - Non-discounted days: days × dailyRate (full price)
 *        - Discounted days:     days × dailyRate × (1 − pct%) or fixed pro-ration
 *        - discountAmount = difference between full and effective rent
 *   5. Sets Invoice.Discount_Amount__c = discountAmount (Amount__c is NOT changed)
 *      Total_Amount__c formula = (Amount − Discount) + GST auto-updates.
 *   6. Updates linked Credit Applied payments to (Amount__c − Discount_Amount__c) so
 *      roll-up summaries on Tenancy (Total_Credits_Applied__c, Available_Credits__c)
 *      auto-recalculate.
 *
 * Run via Anonymous Apex after InvoiceBackfillBatch completes:
 *   Database.executeBatch(new InvoiceDiscountBackfillBatch(), 50);
 */
public class InvoiceDiscountBackfillBatch implements Database.Batchable<SObject> {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id
            FROM Tenancy__c
            WHERE Id IN (SELECT Tenancy__c FROM Discount__c)
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Tenancy__c> tenancies) {
        Set<Id> tenancyIds = new Set<Id>();
        for (Tenancy__c t : tenancies) tenancyIds.add(t.Id);

        // ── 1. Load all discounts; derive date span for the invoice SOQL filter ──
        Map<Id, List<Discount__c>> discountsByTenancy = new Map<Id, List<Discount__c>>();
        Date    earliestStart = null;
        Date    latestEnd     = null;
        Boolean hasOpenEnded  = false;

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

            if (earliestStart == null || d.Start_Date__c < earliestStart) earliestStart = d.Start_Date__c;
            if (d.End_Date__c == null) {
                hasOpenEnded = true;
            } else if (!hasOpenEnded && (latestEnd == null || d.End_Date__c > latestEnd)) {
                latestEnd = d.End_Date__c;
            }
        }

        if (earliestStart == null) return;

        // ── 2. Fetch invoices whose period overlaps the discount date span ─────
        List<Invoice__c> invoices;
        if (hasOpenEnded) {
            invoices = [
                SELECT Id, Tenancy__c, Amount__c, Period_Start__c, Period_End__c, Status__c
                FROM Invoice__c
                WHERE Tenancy__c IN :tenancyIds
                AND Status__c != 'Void'
                AND Discount__c = null
                AND Period_Start__c != null
                AND Period_End__c != null
                AND Period_End__c >= :earliestStart
            ];
        } else {
            invoices = [
                SELECT Id, Tenancy__c, Amount__c, Period_Start__c, Period_End__c, Status__c
                FROM Invoice__c
                WHERE Tenancy__c IN :tenancyIds
                AND Status__c != 'Void'
                AND Discount__c = null
                AND Period_Start__c != null
                AND Period_End__c != null
                AND Period_End__c >= :earliestStart
                AND Period_Start__c <= :latestEnd
            ];
        }

        if (invoices.isEmpty()) return;

        Set<Id> invoiceIds = new Set<Id>();
        for (Invoice__c inv : invoices) invoiceIds.add(inv.Id);

        // ── 3. Load contracts to resolve contract-specific discount matching ───
        Map<Id, List<Contract>> contractsByTenancy = new Map<Id, List<Contract>>();
        for (Contract c : [
            SELECT Id, Tenancy__c, StartDate, EndDate
            FROM Contract
            WHERE Tenancy__c IN :tenancyIds
            AND Status = 'Activated'
        ]) {
            if (!contractsByTenancy.containsKey(c.Tenancy__c)) {
                contractsByTenancy.put(c.Tenancy__c, new List<Contract>());
            }
            contractsByTenancy.get(c.Tenancy__c).add(c);
        }

        // ── 4. Load Credit Applied payments — adjust to (Amount - Discount) ───
        Map<Id, List<Payment__c>> creditPaymentsByInvoice = new Map<Id, List<Payment__c>>();
        for (Payment__c p : [
            SELECT Id, Invoice__c, Amount__c
            FROM Payment__c
            WHERE Invoice__c IN :invoiceIds
            AND Payment_Type__c = 'Credit Applied'
            AND Status__c = 'Received'
        ]) {
            if (!creditPaymentsByInvoice.containsKey(p.Invoice__c)) {
                creditPaymentsByInvoice.put(p.Invoice__c, new List<Payment__c>());
            }
            creditPaymentsByInvoice.get(p.Invoice__c).add(p);
        }

        // ── 5. Calculate and apply discount to each invoice ───────────────────
        List<Invoice__c> invoicesToUpdate = new List<Invoice__c>();
        List<Payment__c> paymentsToUpdate = new List<Payment__c>();

        for (Invoice__c inv : invoices) {
            List<Discount__c> tenancyDiscounts = discountsByTenancy.get(inv.Tenancy__c);
            if (tenancyDiscounts == null || tenancyDiscounts.isEmpty()) continue;

            Id contractId = null;
            List<Contract> contracts = contractsByTenancy.get(inv.Tenancy__c);
            if (contracts != null) {
                for (Contract c : contracts) {
                    if (c.StartDate <= inv.Period_Start__c
                            && (c.EndDate == null || c.EndDate >= inv.Period_Start__c)) {
                        contractId = c.Id;
                        break;
                    }
                }
            }

            DiscountCalculator.Result dr = DiscountCalculator.apply(
                inv.Amount__c,
                inv.Period_Start__c,
                inv.Period_End__c,
                contractId,
                tenancyDiscounts
            );

            if (dr.primaryDiscountId == null) continue;

            // Amount__c is never changed — discount is captured in Discount_Amount__c.
            // Total_Amount__c formula = (Amount - Discount) + GST will auto-reflect the reduction.
            invoicesToUpdate.add(new Invoice__c(
                Id                 = inv.Id,
                Discount_Amount__c = dr.discountAmount,
                Discount__c        = dr.primaryDiscountId
            ));

            // Sync Credit Applied payment to the net payable (Amount - Discount)
            List<Payment__c> cps = creditPaymentsByInvoice.get(inv.Id);
            if (cps != null) {
                Decimal netAmount = (inv.Amount__c - dr.discountAmount).setScale(2);
                for (Payment__c cp : cps) {
                    paymentsToUpdate.add(new Payment__c(
                        Id        = cp.Id,
                        Amount__c = netAmount
                    ));
                }
            }
        }

        if (!invoicesToUpdate.isEmpty()) update invoicesToUpdate;
        if (!paymentsToUpdate.isEmpty()) update paymentsToUpdate;
    }

    public void finish(Database.BatchableContext bc) {}
}
