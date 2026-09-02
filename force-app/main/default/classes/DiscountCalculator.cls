public with sharing class DiscountCalculator {

    public class Result {
        public Decimal discountAmount;   // total pro-rated discount in dollars; 0 if none applies
        public Id primaryDiscountId;     // Id of the first discount that contributed; null if none
    }

    /**
     * Calculates the total pro-rated discount to apply to an invoice, based on how many
     * calendar days each Discount__c record overlaps with the invoice period.
     *
     * Pro-rating logic (example — 10-day invoice $100, 10% discount covering last 5 days):
     *   non-discounted portion: 5 days × $10/day        = $50  (full price)
     *   discounted portion:     5 days × $10/day × 90%  = $45
     *   effectiveRent = $50 + $45 = $95  →  discountAmount = $100 − $95 = $5
     *
     * Multiple discounts are accumulated. The result is clamped so discountAmount
     * never exceeds invoiceAmount (invoice cannot go negative).
     *
     * Callers apply the discount by setting Invoice.Discount_Amount__c = result.discountAmount.
     * Invoice.Amount__c (original rent) is NEVER modified.
     * Invoice.Total_Amount__c formula computes: (Amount__c − Discount_Amount__c) + GST.
     *
     * @param invoiceAmount   Full rent from Contract.Rent_Amount__c (Invoice.Amount__c)
     * @param periodStart     Invoice Period_Start__c
     * @param periodEnd       Invoice Period_End__c
     * @param contractId      Contract driving this invoice (may be null)
     * @param discounts       All Discount__c records for the tenancy, pre-loaded by the caller
     */
    public static Result apply(
        Decimal invoiceAmount,
        Date periodStart,
        Date periodEnd,
        Id contractId,
        List<Discount__c> discounts
    ) {
        Result res = new Result();
        res.discountAmount    = 0;
        res.primaryDiscountId = null;

        if (invoiceAmount == null || invoiceAmount == 0
                || discounts == null || discounts.isEmpty()) {
            return res;
        }

        Integer totalDays = periodStart.daysBetween(periodEnd) + 1;

        for (Discount__c d : discounts) {
            if (d.Contract__c != null && d.Contract__c != contractId) continue;

            Date overlapStart = d.Start_Date__c > periodStart ? d.Start_Date__c : periodStart;
            Date discountEnd  = d.End_Date__c == null ? periodEnd
                              : (d.End_Date__c < periodEnd ? d.End_Date__c : periodEnd);

            Integer overlapDays = overlapStart.daysBetween(discountEnd) + 1;
            if (overlapDays <= 0) continue;

            Decimal discountAmt;
            if (d.Discount_Type__c == 'Percentage') {
                Decimal eligibleAmt = (invoiceAmount / totalDays) * overlapDays;
                discountAmt = (eligibleAmt * d.Discount_Value__c / 100).setScale(2);
            } else {
                discountAmt = ((d.Discount_Value__c / totalDays) * overlapDays).setScale(2);
            }

            res.discountAmount += discountAmt;
            if (res.primaryDiscountId == null) res.primaryDiscountId = d.Id;
        }

        // Clamp: discount cannot exceed the invoice amount
        if (res.discountAmount > invoiceAmount) {
            res.discountAmount = invoiceAmount;
        }
        res.discountAmount = res.discountAmount.setScale(2);

        if (res.discountAmount == 0) res.primaryDiscountId = null;

        return res;
    }
}
