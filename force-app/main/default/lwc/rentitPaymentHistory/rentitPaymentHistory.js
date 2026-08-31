import { LightningElement, wire, track } from 'lwc';
import getActiveTenancy from '@salesforce/apex/RentItPortalController.getActiveTenancy';
import getPayments from '@salesforce/apex/RentItPortalController.getPayments';

const COLUMNS = [
    { label: 'Reference',      fieldName: 'Payment_Reference__c', type: 'text' },
    { label: 'Amount',         fieldName: 'Amount__c',            type: 'currency',
      typeAttributes: { currencyCode: 'AUD', minimumFractionDigits: 2 } },
    { label: 'Payment Date',   fieldName: 'Payment_Date__c',      type: 'date' },
    { label: 'Method',         fieldName: 'Payment_Method__c',    type: 'text' },
    { label: 'Status',         fieldName: 'Status__c',            type: 'text' },
    { label: 'Comment',        fieldName: 'Comment__c',           type: 'text' }
];

export default class RentitPaymentHistory extends LightningElement {
    @track payments = [];
    @track error;
    isLoading = true;
    activeTab = 'all';
    columns = COLUMNS;

    @wire(getActiveTenancy)
    wiredTenancy({ data, error }) {
        if (data) {
            this._loadPayments(data.Id, null);
        } else if (error) {
            this.error = 'Unable to load tenancy information.';
            this.isLoading = false;
        }
    }

    _loadPayments(tenancyId, statusFilter) {
        this.isLoading = true;
        getPayments({ tenancyId, statusFilter: statusFilter || '' })
            .then(data => {
                this.payments = data;
                this.isLoading = false;
            })
            .catch(err => {
                this.error = err?.body?.message || 'Failed to load payments.';
                this.isLoading = false;
            });
    }

    handleTabChange(e) {
        this.activeTab = e.target.value;
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
