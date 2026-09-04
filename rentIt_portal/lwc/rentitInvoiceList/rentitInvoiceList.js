import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import BasePath from '@salesforce/community/basePath';
import getActiveTenancy from '@salesforce/apex/RentItPortalController.getActiveTenancy';
import getInvoices from '@salesforce/apex/RentItPortalController.getInvoices';

export default class RentitInvoiceList extends NavigationMixin(LightningElement) {
    @track invoices;
    @track error;
    isLoading       = true;
    selectedInvoice = null;
    activeStatusTab = 'all';
    activeCatTab    = 'all';
    isDiscountOpen  = false;

    @wire(getActiveTenancy)
    wiredTenancy({ data, error }) {
        if (data) {
            this._loadInvoices(data.Id);
        } else if (error) {
            this.error = 'Unable to load tenancy information.';
            this.isLoading = false;
        }
    }

    _loadInvoices(tenancyId) {
        getInvoices({ tenancyId })
            .then(data => {
                this.invoices = data;
                this.isLoading = false;
            })
            .catch(err => {
                this.error = err?.body?.message || 'Failed to load invoices.';
                this.isLoading = false;
            });
    }

    // ── Filtered list ─────────────────────────────────────────────
    get filteredInvoices() {
        if (!this.invoices) return [];
        return this.invoices.filter(inv => {
            const statusOk = this.activeStatusTab === 'all' || inv.Status__c === this.activeStatusTab;
            const catOk    = this.activeCatTab    === 'all' || inv.Category__c === this.activeCatTab;
            return statusOk && catOk;
        });
    }

    get hasInvoices() { return this.filteredInvoices.length > 0; }
    get showList()    { return !this.selectedInvoice; }
    get showDetail()  { return !!this.selectedInvoice; }

    // ── Status filter tabs ────────────────────────────────────────
    handleTabAll()       { this.activeStatusTab = 'all'; }
    handleTabScheduled() { this.activeStatusTab = 'Scheduled'; }
    handleTabUnpaid()    { this.activeStatusTab = 'Unpaid'; }
    handleTabOverdue()   { this.activeStatusTab = 'Overdue'; }
    handleTabPaid()      { this.activeStatusTab = 'Paid'; }

    get tabAll()       { return this._stClass('all'); }
    get tabScheduled() { return this._stClass('Scheduled'); }
    get tabUnpaid()    { return this._stClass('Unpaid'); }
    get tabOverdue()   { return this._stClass('Overdue'); }
    get tabPaid()      { return this._stClass('Paid'); }

    _stClass(tab) {
        return 'ri-tab' + (this.activeStatusTab === tab ? ' ri-tab--active' : '');
    }

    // ── Category filter tabs ──────────────────────────────────────
    handleCatAll()       { this.activeCatTab = 'all'; }
    handleCatRent()      { this.activeCatTab = 'Rent'; }
    handleCatUtilities() { this.activeCatTab = 'Utilities'; }

    get catAll()       { return this._catClass('all'); }
    get catRent()      { return this._catClass('Rent'); }
    get catUtilities() { return this._catClass('Utilities'); }

    _catClass(cat) {
        return 'ri-cat-tab' + (this.activeCatTab === cat ? ' ri-cat-tab--active' : '');
    }

    // ── Row interaction ───────────────────────────────────────────
    handleInvoiceSelect(event) {
        const id = event.currentTarget.dataset.id;
        this.selectedInvoice = this.invoices.find(inv => inv.Id === id) || null;
    }

    handleCloseDetail() {
        this.selectedInvoice = null;
        this.isDiscountOpen = false;
    }

    // ── Invoice detail — dynamic metrics (Feedback 26) ───────────
    get isPaidInvoice()        { return this.selectedInvoice?.Status__c === 'Paid'; }
    get selectedHasDiscount()  { return !!(this.selectedInvoice?.Discount_Amount__c); }
    get selectedHasGst()       { return !!(this.selectedInvoice?.GST_Amount__c); }
    get selectedOriginalAmount(){ return this.selectedInvoice?.Amount__c; }
    get selectedDiscountAmount(){ return this.selectedInvoice?.Discount_Amount__c; }
    get selectedGstAmount()    { return this.selectedInvoice?.GST_Amount__c; }

    // ── Discount collapsible ──────────────────────────────────────
    get hasDiscount()          { return !!this.selectedInvoice?.Discount__c; }
    get discountAmount()       { return this.selectedInvoice?.Discount_Amount__c; }
    get discountType()         { return this.selectedInvoice?.Discount__r?.Discount_Type__c || ''; }
    get discountValue()        { return this.selectedInvoice?.Discount__r?.Discount_Value__c; }
    get discountIsPercentage() { return this.discountType === 'Percentage'; }
    get discountIsFixed()      { return this.discountType === 'Fixed Amount'; }
    get discountToggleIcon() {
        return this.isDiscountOpen ? 'utility:chevronup' : 'utility:chevrondown';
    }
    toggleDiscount() { this.isDiscountOpen = !this.isDiscountOpen; }

    // ── Discount period + coverage (Feedback 28) ──────────────────
    get discountPeriodStart()    { return this.selectedInvoice?.Discount__r?.Start_Date__c; }
    get discountPeriodEnd()      { return this.selectedInvoice?.Discount__r?.End_Date__c; }
    get discountHasPeriodInfo()  { return !!this.discountPeriodStart; }

    get discountCoverageText() {
        const inv = this.selectedInvoice;
        if (!inv?.Period_Start__c || !inv?.Period_End__c || !this.discountPeriodStart) return null;
        const invStart  = new Date(inv.Period_Start__c);
        const invEnd    = new Date(inv.Period_End__c);
        const discStart = new Date(this.discountPeriodStart);
        const discEnd   = this.discountPeriodEnd ? new Date(this.discountPeriodEnd) : null;
        const overlapStart = discStart > invStart ? discStart : invStart;
        const overlapEnd   = discEnd && discEnd < invEnd ? discEnd : invEnd;
        const coverDays = Math.max(0, Math.round((overlapEnd - overlapStart) / 86400000) + 1);
        const invDays   = Math.round((invEnd - invStart) / 86400000) + 1;
        return `${coverDays} of ${invDays} days`;
    }

    handleMakePayment() {
        const invoiceId = this.selectedInvoice?.Id || '';
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: `${BasePath}/payments?invoiceId=${invoiceId}` }
        });
    }
}
