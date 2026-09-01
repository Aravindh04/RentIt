import { LightningElement, wire, track } from 'lwc';
import getActiveTenancy from '@salesforce/apex/RentItPortalController.getActiveTenancy';
import getPayments from '@salesforce/apex/RentItPortalController.getPayments';

export default class RentitPaymentHistory extends LightningElement {
    @track payments = [];
    @track error;
    isLoading = true;
    activeTab = 'all';

    @wire(getActiveTenancy)
    wiredTenancy({ data, error }) {
        if (data) {
            this._loadPayments(data.Id);
        } else if (error) {
            this.error = 'Unable to load tenancy information.';
            this.isLoading = false;
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

    get hasPayments() {
        return this.filteredPayments.length > 0;
    }
}
