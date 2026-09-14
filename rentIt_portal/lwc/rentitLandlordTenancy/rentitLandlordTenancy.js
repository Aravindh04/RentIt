import { LightningElement, wire, track } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import BasePath from '@salesforce/community/basePath';
import getTenancyDetail from '@salesforce/apex/RentItLandlordController.getTenancyDetail';
import getTenancyContract from '@salesforce/apex/RentItLandlordController.getTenancyContract';
import getInvoices from '@salesforce/apex/RentItLandlordController.getInvoices';
import getPayments from '@salesforce/apex/RentItLandlordController.getPayments';
import getDiscounts from '@salesforce/apex/RentItLandlordController.getDiscounts';
import createInvoice from '@salesforce/apex/RentItLandlordController.createInvoice';
import createDiscount from '@salesforce/apex/RentItLandlordController.createDiscount';
import updateTenancy from '@salesforce/apex/RentItLandlordController.updateTenancy';

const TENANCY_STATUS = ['Pending', 'Active', 'Expired', 'Terminated']
    .map(v => ({ label: v, value: v }));
const INVOICE_CATEGORY = ['Rent', 'Utilities'].map(v => ({ label: v, value: v }));
const DISCOUNT_TYPE = ['Percentage', 'Fixed Amount'].map(v => ({ label: v, value: v }));

export default class RentitLandlordTenancy extends NavigationMixin(LightningElement) {
    tenancyId = null;
    @track tenancy = null;
    @track contract = null;
    @track invoices = [];
    @track payments = [];
    @track discounts = [];

    isLoading = true;
    error = null;
    successMessage = null;
    activeTab = 'overview';

    // Open form panels
    showTenancyForm = false;
    showInvoiceForm = false;
    showDiscountForm = false;
    isSaving = false;

    // Tenancy edit fields
    editStatus = null;

    // Invoice form fields
    invCategory = 'Rent';
    invAmount = null;
    invGst = null;
    invDate = null;
    invDueDate = null;
    invPeriodStart = null;
    invPeriodEnd = null;

    // Discount form fields
    discName = '';
    discType = 'Percentage';
    discValue = null;
    discStart = null;
    discEnd = null;
    discDescription = '';

    tenancyStatusOptions = TENANCY_STATUS;
    invoiceCategoryOptions = INVOICE_CATEGORY;
    discountTypeOptions = DISCOUNT_TYPE;

    // ── Read tenancyId from the URL ───────────────────────────────
    @wire(CurrentPageReference)
    setPageRef(ref) {
        if (!ref) return;
        const url = ref.attributes?.url || window.location.href;
        const qIdx = url.indexOf('?');
        if (qIdx === -1) { this.isLoading = false; return; }
        try {
            const id = new URLSearchParams(url.substring(qIdx + 1)).get('tenancyId');
            if (id && id !== this.tenancyId) {
                this.tenancyId = id;
                this._loadAll();
            } else if (!id) {
                this.isLoading = false;
            }
        } catch (_) {
            this.isLoading = false;
        }
    }

    _loadAll() {
        this.isLoading = true;
        this.error = null;
        Promise.all([
            getTenancyDetail({ tenancyId: this.tenancyId }),
            getTenancyContract({ tenancyId: this.tenancyId }),
            getInvoices({ tenancyId: this.tenancyId }),
            getPayments({ tenancyId: this.tenancyId }),
            getDiscounts({ tenancyId: this.tenancyId })
        ])
            .then(([t, c, inv, pay, disc]) => {
                this.tenancy = t;
                this.contract = c;
                this.invoices = inv;
                this.payments = pay;
                this.discounts = disc;
                this.editStatus = t?.Status__c;
                this.isLoading = false;
            })
            .catch(err => {
                this.error = err?.body?.message || 'Unable to load this tenancy.';
                this.isLoading = false;
            });
    }

    _refresh(section) {
        const loader = { invoices: getInvoices, payments: getPayments, discounts: getDiscounts }[section];
        if (!loader) return;
        loader({ tenancyId: this.tenancyId })
            .then(data => { this[section] = data; })
            .catch(() => { /* surfaced on next full load */ });
    }

    // ── Header / overview getters ─────────────────────────────────
    get hasTenancy()    { return !!this.tenancy; }
    get missingId()     { return !this.tenancyId && !this.isLoading; }
    get tenancyName()   { return this.tenancy?.Name || ''; }
    get tenancyStatus() { return this.tenancy?.Status__c || ''; }
    get tenantName()    { return this.tenancy?.Tenant__r?.Name || '—'; }
    get tenantEmail()   { return this.tenancy?.Tenant__r?.Email || '—'; }
    get tenantPhone()   { return this.tenancy?.Tenant__r?.Phone || '—'; }
    get propertyName()  { return this.tenancy?.Property__r?.Name || '—'; }
    get roomName()      { return this.tenancy?.Room__r?.Name || '—'; }
    // Deposit of record lives on the Contract, not the Tenancy
    get deposit()       { return this.contract?.Deposit_Amount__c || 0; }
    get arrears()       { return this.tenancy?.Total_Arrears__c || 0; }
    get received()      { return this.tenancy?.Total_Received__c || 0; }
    get unpaid()        { return this.tenancy?.Total_Unpaid__c || 0; }
    get credits()       { return this.tenancy?.Available_Credits__c || 0; }

    get hasContract()      { return !!this.contract; }
    get contractNumber()   { return this.contract?.ContractNumber || '—'; }
    get contractStatus()   { return this.contract?.Status || ''; }
    get contractRent()     { return this.contract?.Rent_Amount__c; }
    get contractFrequency(){ return this.contract?.Rent_Frequency__c || ''; }
    get contractStart()    { return this.contract?.StartDate; }
    get contractEnd()      { return this.contract?.EndDate; }

    // ── Sub-tabs ──────────────────────────────────────────────────
    get isOverview()  { return this.activeTab === 'overview'; }
    get isInvoices()  { return this.activeTab === 'invoices'; }
    get isPayments()  { return this.activeTab === 'payments'; }
    get isDiscounts() { return this.activeTab === 'discounts'; }

    get tabOverview()  { return this._tab('overview'); }
    get tabInvoices()  { return this._tab('invoices'); }
    get tabPayments()  { return this._tab('payments'); }
    get tabDiscounts() { return this._tab('discounts'); }

    _tab(v) { return 'ri-subtab' + (this.activeTab === v ? ' ri-subtab--active' : ''); }

    handleTab(event) {
        this.activeTab = event.currentTarget.dataset.tab;
        this._closeForms();
    }

    get hasInvoices()  { return this.invoices.length > 0; }
    get hasPayments()  { return this.payments.length > 0; }
    get hasDiscounts() { return this.discounts.length > 0; }

    /** Formats each discount's value with the right $ / % symbol. */
    get discountRows() {
        return this.discounts.map(d => ({
            ...d,
            displayValue: d.Discount_Type__c === 'Percentage'
                ? `${d.Discount_Value__c}%`
                : `$${Number(d.Discount_Value__c || 0).toFixed(2)}`,
            endLabel: d.End_Date__c ? null : 'Open-ended'
        }));
    }

    // ── Form open/close ───────────────────────────────────────────
    _closeForms() {
        this.showTenancyForm = false;
        this.showInvoiceForm = false;
        this.showDiscountForm = false;
        this.successMessage = null;
    }

    handleToggleTenancyForm() {
        const open = this.showTenancyForm;
        this._closeForms();
        this.showTenancyForm = !open;
        this.editStatus = this.tenancy?.Status__c;
    }

    handleToggleInvoiceForm() {
        const open = this.showInvoiceForm;
        this._closeForms();
        this.showInvoiceForm = !open;
    }

    handleToggleDiscountForm() {
        const open = this.showDiscountForm;
        this._closeForms();
        this.showDiscountForm = !open;
    }

    handleCancel() { this._closeForms(); }

    // ── Field handlers ────────────────────────────────────────────
    handleEditStatus(e)  { this.editStatus = e.detail.value; }

    handleInvCategory(e)    { this.invCategory = e.detail.value; }
    handleInvAmount(e)      { this.invAmount = parseFloat(e.detail.value); }
    handleInvGst(e)         { this.invGst = parseFloat(e.detail.value); }
    handleInvDate(e)        { this.invDate = e.detail.value; }
    handleInvDueDate(e)     { this.invDueDate = e.detail.value; }
    handleInvPeriodStart(e) { this.invPeriodStart = e.detail.value; }
    handleInvPeriodEnd(e)   { this.invPeriodEnd = e.detail.value; }

    handleDiscName(e)        { this.discName = e.detail.value; }
    handleDiscType(e)        { this.discType = e.detail.value; }
    handleDiscValue(e)       { this.discValue = parseFloat(e.detail.value); }
    handleDiscStart(e)       { this.discStart = e.detail.value; }
    handleDiscEnd(e)         { this.discEnd = e.detail.value; }
    handleDiscDescription(e) { this.discDescription = e.detail.value; }

    // ── Save handlers ─────────────────────────────────────────────
    handleSaveTenancy() {
        this.error = null;
        this.isSaving = true;
        updateTenancy({
            tenancyId: this.tenancyId,
            status: this.editStatus
        })
            .then(() => getTenancyDetail({ tenancyId: this.tenancyId }))
            .then(t => {
                this.tenancy = t;
                this.successMessage = 'Tenancy updated.';
                this.showTenancyForm = false;
                this.isSaving = false;
            })
            .catch(err => {
                this.error = err?.body?.message || 'Failed to update tenancy.';
                this.isSaving = false;
            });
    }

    handleSaveInvoice() {
        this.error = null;
        if (!this.invAmount || this.invAmount <= 0) {
            this.error = 'Enter an invoice amount greater than zero.';
            return;
        }
        if (!this.invDueDate) {
            this.error = 'Due date is required.';
            return;
        }
        this.isSaving = true;
        createInvoice({
            tenancyId: this.tenancyId,
            category: this.invCategory,
            amount: this.invAmount,
            gstAmount: this.invGst,
            invoiceDate: this.invDate,
            dueDate: this.invDueDate,
            periodStart: this.invPeriodStart,
            periodEnd: this.invPeriodEnd
        })
            .then(() => {
                this.successMessage = 'Invoice issued.';
                this.showInvoiceForm = false;
                this.isSaving = false;
                this._resetInvoiceForm();
                this._refresh('invoices');
            })
            .catch(err => {
                this.error = err?.body?.message || 'Failed to issue invoice.';
                this.isSaving = false;
            });
    }

    _resetInvoiceForm() {
        this.invCategory = 'Rent';
        this.invAmount = null;
        this.invGst = null;
        this.invDate = null;
        this.invDueDate = null;
        this.invPeriodStart = null;
        this.invPeriodEnd = null;
    }

    handleSaveDiscount() {
        this.error = null;
        if (!this.discValue || this.discValue <= 0) {
            this.error = 'Enter a discount value greater than zero.';
            return;
        }
        if (!this.discStart) {
            this.error = 'Start date is required.';
            return;
        }
        this.isSaving = true;
        createDiscount({
            tenancyId: this.tenancyId,
            name: this.discName,
            discountType: this.discType,
            discountValue: this.discValue,
            startDate: this.discStart,
            endDate: this.discEnd,
            description: this.discDescription
        })
            .then(() => {
                this.successMessage = 'Discount added.';
                this.showDiscountForm = false;
                this.isSaving = false;
                this._resetDiscountForm();
                this._refresh('discounts');
            })
            .catch(err => {
                this.error = err?.body?.message || 'Failed to add discount.';
                this.isSaving = false;
            });
    }

    _resetDiscountForm() {
        this.discName = '';
        this.discType = 'Percentage';
        this.discValue = null;
        this.discStart = null;
        this.discEnd = null;
        this.discDescription = '';
    }

    // ── Navigation ────────────────────────────────────────────────
    handleBack() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: `${BasePath}/landlord-properties` }
        });
    }
}
