@IsTest
private class DiscountCalculatorTest {

    // ── helpers ─────────────────────────────────────────────────────────────

    private static Discount__c pctDiscount(Date start, Date endDt, Decimal pct) {
        return new Discount__c(
            Discount_Type__c  = 'Percentage',
            Discount_Value__c = pct,
            Start_Date__c     = start,
            End_Date__c       = endDt
        );
    }

    private static Discount__c fixedDiscount(Date start, Date endDt, Decimal amount) {
        return new Discount__c(
            Discount_Type__c  = 'Fixed Amount',
            Discount_Value__c = amount,
            Start_Date__c     = start,
            End_Date__c       = endDt
        );
    }

    // ── no discount ─────────────────────────────────────────────────────────

    @IsTest
    static void noDiscounts_returnsZero() {
        DiscountCalculator.Result r = DiscountCalculator.apply(
            100, Date.newInstance(2026,1,1), Date.newInstance(2026,1,10), null, null
        );
        System.assertEquals(0, r.discountAmount);
        Assert.isNull(r.primaryDiscountId);
    }

    @IsTest
    static void discountOutsidePeriod_noEffect() {
        Discount__c d = pctDiscount(Date.newInstance(2026,1,15), Date.newInstance(2026,1,31), 10);
        DiscountCalculator.Result r = DiscountCalculator.apply(
            100, Date.newInstance(2026,1,1), Date.newInstance(2026,1,10), null,
            new List<Discount__c>{ d }
        );
        System.assertEquals(0, r.discountAmount);
        Assert.isNull(r.primaryDiscountId);
    }

    // ── full-period percentage ───────────────────────────────────────────────

    @IsTest
    static void fullOverlap_percentage_appliesFullDiscount() {
        // 10-day invoice, 10% discount covering entire period → $10 discount
        Discount__c d = pctDiscount(Date.newInstance(2026,1,1), Date.newInstance(2026,1,10), 10);
        DiscountCalculator.Result r = DiscountCalculator.apply(
            100, Date.newInstance(2026,1,1), Date.newInstance(2026,1,10), null,
            new List<Discount__c>{ d }
        );
        System.assertEquals(10, r.discountAmount, 'Expected $10 discount (10% of $100)');
        Assert.isNotNull(r.primaryDiscountId);
    }

    // ── partial-period percentage ────────────────────────────────────────────

    @IsTest
    static void partialOverlap_percentage_proRated() {
        // $100 for 10 days; 10% discount active for 7 of those days
        // Discount = 10% × ($100/10) × 7 = $7
        Discount__c d = pctDiscount(Date.newInstance(2026,1,4), Date.newInstance(2026,1,10), 10);
        DiscountCalculator.Result r = DiscountCalculator.apply(
            100, Date.newInstance(2026,1,1), Date.newInstance(2026,1,10), null,
            new List<Discount__c>{ d }
        );
        System.assertEquals(7, r.discountAmount, 'Expected $7 discount (pro-rated 10% for 7/10 days)');
    }

    // ── full-period fixed amount ─────────────────────────────────────────────

    @IsTest
    static void fullOverlap_fixedAmount_appliesFullDiscount() {
        // $50 fixed discount on a 10-day, $100 invoice (full overlap) → $50 discount
        Discount__c d = fixedDiscount(Date.newInstance(2026,1,1), Date.newInstance(2026,1,10), 50);
        DiscountCalculator.Result r = DiscountCalculator.apply(
            100, Date.newInstance(2026,1,1), Date.newInstance(2026,1,10), null,
            new List<Discount__c>{ d }
        );
        System.assertEquals(50, r.discountAmount);
    }

    // ── partial-period fixed amount ──────────────────────────────────────────

    @IsTest
    static void partialOverlap_fixedAmount_proRated() {
        // $50 fixed / 10-day period; 7 days overlap → $50/10×7 = $35 discount
        Discount__c d = fixedDiscount(Date.newInstance(2026,1,4), Date.newInstance(2026,1,10), 50);
        DiscountCalculator.Result r = DiscountCalculator.apply(
            100, Date.newInstance(2026,1,1), Date.newInstance(2026,1,10), null,
            new List<Discount__c>{ d }
        );
        System.assertEquals(35, r.discountAmount, 'Expected $35 discount (pro-rated $50 for 7/10 days)');
    }

    // ── multiple discounts accumulate ────────────────────────────────────────

    @IsTest
    static void multipleDiscounts_accumulate() {
        // 10% (full period, $10 off) + $5 fixed (full period, $5 off) → $15 total discount
        Discount__c pct   = pctDiscount(Date.newInstance(2026,1,1), Date.newInstance(2026,1,10), 10);
        Discount__c fixed = fixedDiscount(Date.newInstance(2026,1,1), Date.newInstance(2026,1,10), 5);
        DiscountCalculator.Result r = DiscountCalculator.apply(
            100, Date.newInstance(2026,1,1), Date.newInstance(2026,1,10), null,
            new List<Discount__c>{ pct, fixed }
        );
        System.assertEquals(15, r.discountAmount);
    }

    // ── clamp at invoice amount ──────────────────────────────────────────────

    @IsTest
    static void excessiveDiscount_clampedAtInvoiceAmount() {
        // $200 fixed discount on a $100 invoice → clamped to $100
        Discount__c d = fixedDiscount(Date.newInstance(2026,1,1), Date.newInstance(2026,1,10), 200);
        DiscountCalculator.Result r = DiscountCalculator.apply(
            100, Date.newInstance(2026,1,1), Date.newInstance(2026,1,10), null,
            new List<Discount__c>{ d }
        );
        System.assertEquals(100, r.discountAmount, 'Discount must be clamped to the invoice amount');
    }

    // ── open-ended discount (no End_Date__c) ─────────────────────────────────

    @IsTest
    static void openEndedDiscount_appliedForFullPeriod() {
        Discount__c d = pctDiscount(Date.newInstance(2026,1,1), null, 20);
        DiscountCalculator.Result r = DiscountCalculator.apply(
            100, Date.newInstance(2026,1,1), Date.newInstance(2026,1,10), null,
            new List<Discount__c>{ d }
        );
        System.assertEquals(20, r.discountAmount);
    }

    // ── contract-specific discount ───────────────────────────────────────────

    @IsTest
    static void contractSpecificDiscount_onlyMatchesCorrectContract() {
        Id fakeContractId1 = '8005g000000xxxxAAA';
        Id fakeContractId2 = '8005g000000yyyyAAA';
        Discount__c d = new Discount__c(
            Discount_Type__c  = 'Percentage',
            Discount_Value__c = 10,
            Start_Date__c     = Date.newInstance(2026,1,1),
            End_Date__c       = Date.newInstance(2026,1,10),
            Contract__c       = fakeContractId1
        );

        DiscountCalculator.Result r1 = DiscountCalculator.apply(
            100, Date.newInstance(2026,1,1), Date.newInstance(2026,1,10),
            fakeContractId1, new List<Discount__c>{ d }
        );
        System.assertEquals(10, r1.discountAmount, 'Should match contract and apply discount');

        DiscountCalculator.Result r2 = DiscountCalculator.apply(
            100, Date.newInstance(2026,1,1), Date.newInstance(2026,1,10),
            fakeContractId2, new List<Discount__c>{ d }
        );
        System.assertEquals(0, r2.discountAmount, 'Should not apply — wrong contract');
        Assert.isNull(r2.primaryDiscountId);
    }

    // ── zero invoice amount ──────────────────────────────────────────────────

    @IsTest
    static void zeroInvoiceAmount_noDiscount() {
        Discount__c d = pctDiscount(Date.newInstance(2026,1,1), Date.newInstance(2026,1,10), 10);
        DiscountCalculator.Result r = DiscountCalculator.apply(
            0, Date.newInstance(2026,1,1), Date.newInstance(2026,1,10), null,
            new List<Discount__c>{ d }
        );
        System.assertEquals(0, r.discountAmount);
        Assert.isNull(r.primaryDiscountId);
    }

    // ── single day overlap ───────────────────────────────────────────────────

    @IsTest
    static void singleDayOverlap_proRatedCorrectly() {
        // 10-day invoice; discount active only on day 1
        // 10% × ($100/10) × 1 = $1 discount
        Discount__c d = pctDiscount(Date.newInstance(2026,1,1), Date.newInstance(2026,1,1), 10);
        DiscountCalculator.Result r = DiscountCalculator.apply(
            100, Date.newInstance(2026,1,1), Date.newInstance(2026,1,10), null,
            new List<Discount__c>{ d }
        );
        System.assertEquals(1, r.discountAmount);
    }
}
