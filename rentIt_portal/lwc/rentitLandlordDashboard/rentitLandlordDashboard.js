import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import BasePath from '@salesforce/community/basePath';
import getPortfolioSummary from '@salesforce/apex/RentItLandlordController.getPortfolioSummary';
import getIncomeByProperty from '@salesforce/apex/RentItLandlordController.getIncomeByProperty';

export default class RentitLandlordDashboard extends NavigationMixin(LightningElement) {
    summary = null;
    income = [];
    error = null;
    isLoading = true;

    @wire(getPortfolioSummary)
    wiredSummary(result) {
        if (result.data !== undefined || result.error) {
            if (result.data) this.summary = result.data;
            if (result.error) this.error = result.error?.body?.message || 'Unable to load your portfolio.';
            this.isLoading = false;
        }
    }

    @wire(getIncomeByProperty)
    wiredIncome({ data }) {
        if (data) this.income = data;
    }

    // ── KPIs ──────────────────────────────────────────────────────
    get propertyCount()   { return this.summary?.properties ?? 0; }
    get tenancyCount()    { return this.summary?.activeTenancies ?? 0; }
    get pendingCount()    { return this.summary?.pendingApprovals ?? 0; }
    get openCaseCount()   { return this.summary?.openCases ?? 0; }
    get totalArrears()    { return this.summary?.totalArrears ?? 0; }
    get totalReceived()   { return this.summary?.totalReceived ?? 0; }
    get totalUnpaid()     { return this.summary?.totalUnpaid ?? 0; }
    get hasPending()      { return this.pendingCount > 0; }

    // ── Income report ─────────────────────────────────────────────
    get hasIncome() { return this.income.length > 0; }

    /** Adds a share-of-total percentage and bar width to each income row. */
    get incomeRows() {
        const total = this.income.reduce((s, r) => s + (r.total || 0), 0);
        return this.income.map((r, i) => {
            const pct = total > 0 ? Math.round(((r.total || 0) / total) * 100) : 0;
            return {
                key: r.propertyId || i,
                propertyName: r.propertyName,
                total: r.total,
                paymentCount: r.paymentCount,
                pct,
                barStyle: `width:${pct}%`
            };
        });
    }

    get grandTotal() {
        return this.income.reduce((s, r) => s + (r.total || 0), 0);
    }

    // ── Navigation ────────────────────────────────────────────────
    _go(path) {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: `${BasePath}/${path}` }
        });
    }

    handleViewProperties() { this._go('landlord-properties'); }
    handleViewApprovals()  { this._go('landlord-approvals'); }
    handleViewCases()      { this._go('landlord-support'); }
}
