import { LightningElement, wire, track } from 'lwc';
import getActiveTenancy from '@salesforce/apex/RentItPortalController.getActiveTenancy';
import getPayments from '@salesforce/apex/RentItPortalController.getPayments';
import getPaymentFiles from '@salesforce/apex/RentItPortalController.getPaymentFiles';

export default class RentitPaymentHistory extends LightningElement {
    @track payments = [];
    @track paymentFiles = [];
    @track error;
    isLoading         = true;
    activeTab         = 'all';
    selectedPayment   = null;
    isAttachmentsOpen = false;
    _tenancyId        = null;

    @wire(getActiveTenancy)
    wiredTenancy({ data, error }) {
        if (data) {
            this._tenancyId = data.Id;
            this._loadPayments(data.Id);
        } else if (error) {
            this.error = 'Unable to load tenancy information.';
            this.isLoading = false;
        }
    }

    @wire(getPaymentFiles, { paymentId: '$selectedPaymentId', tenancyId: '$tenancyId' })
    wiredPaymentFiles({ data }) {
        if (data) {
            this.paymentFiles = data.map(f => ({
                id:          f.ContentDocumentId,
                title:       f.ContentDocument.Title,
                fileType:    (f.ContentDocument.FileType || '').toUpperCase(),
                size:        this._formatSize(f.ContentDocument.ContentSize),
                downloadUrl: `/sfc/servlet.shepherd/document/download/${f.ContentDocumentId}`
            }));
        } else {
            this.paymentFiles = [];
        }
    }

    _loadPayments(tenancyId) {
        this.isLoading = true;
        getPayments({ tenancyId, statusFilter: '' })
            .then(data => {
                this.payments = data;
                this.isLoading = false;
            })
            .catch(err => {
                this.error = err?.body?.message || 'Failed to load payments.';
                this.isLoading = false;
            });
    }

    // Tab handlers
    handleTabAll()      { this.activeTab = 'all'; }
    handleTabPending()  { this.activeTab = 'Pending Approval'; }
    handleTabReceived() { this.activeTab = 'Received'; }
    handleTabRejected() { this.activeTab = 'Rejected'; }

    get tabAll()      { return this._tabClass('all'); }
    get tabPending()  { return this._tabClass('Pending Approval'); }
    get tabReceived() { return this._tabClass('Received'); }
    get tabRejected() { return this._tabClass('Rejected'); }

    _tabClass(tab) {
        return 'ri-tab' + (this.activeTab === tab ? ' ri-tab--active' : '');
    }

    get filteredPayments() {
        if (!this.payments) return [];
        if (this.activeTab === 'all') return this.payments;
        return this.payments.filter(p => p.Status__c === this.activeTab);
    }

    get hasPayments()        { return this.filteredPayments.length > 0; }
    get showList()           { return !this.selectedPayment; }
    get showDetail()         { return !!this.selectedPayment; }
    get tenancyId()          { return this._tenancyId; }
    get selectedPaymentId()  { return this.selectedPayment?.Id || null; }

    handlePaymentSelect(event) {
        const id = event.currentTarget.dataset.id;
        this.selectedPayment   = this.payments.find(p => p.Id === id) || null;
        this.isAttachmentsOpen = false;
        this.paymentFiles      = [];
    }

    handleCloseDetail() {
        this.selectedPayment   = null;
        this.isAttachmentsOpen = false;
        this.paymentFiles      = [];
    }

    // ── Attachments collapsible ───────────────────────────────────
    get hasFiles()   { return this.paymentFiles.length > 0; }
    get fileCount()  { return this.paymentFiles.length; }
    get attachmentLabel() {
        return this.fileCount > 0 ? `Attachments (${this.fileCount})` : 'Attachments';
    }
    get attachmentToggleIcon() {
        return this.isAttachmentsOpen ? 'utility:chevronup' : 'utility:chevrondown';
    }

    toggleAttachments() { this.isAttachmentsOpen = !this.isAttachmentsOpen; }

    _formatSize(bytes) {
        if (!bytes) return '';
        if (bytes < 1024)    return `${bytes} B`;
        if (bytes < 1048576) return `${(bytes / 1024).toFixed(1)} KB`;
        return `${(bytes / 1048576).toFixed(1)} MB`;
    }
}
