import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getPendingPayments from '@salesforce/apex/RentItPortalController.getPendingPayments';
import updatePaymentStatus from '@salesforce/apex/RentItPortalController.updatePaymentStatus';

const COLUMNS = [
    { label: 'Payment',     fieldName: 'Name',                  type: 'text' },
    { label: 'Tenancy',     fieldName: 'Tenancy__r.Name',       type: 'text' },
    { label: 'Invoice',     fieldName: 'Invoice__r.Name',       type: 'text' },
    { label: 'Amount',      fieldName: 'Amount__c',             type: 'currency',
      typeAttributes: { currencyCode: 'AUD', minimumFractionDigits: 2 } },
    { label: 'Payment Date', fieldName: 'Payment_Date__c',      type: 'date' },
    { label: 'Method',      fieldName: 'Payment_Method__c',     type: 'text' },
    { label: 'Reference',   fieldName: 'Payment_Reference__c',  type: 'text' },
    { label: 'Comment',     fieldName: 'Comment__c',            type: 'text' },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'Approve', name: 'approve' },
                { label: 'Reject',  name: 'reject' }
            ]
        }
    }
];

export default class RentitPaymentApproval extends LightningElement {
    @track payments;
    @track error;
    @track actionMessage;
    @track actionMessageClass = 'slds-notify slds-notify_toast slds-theme_success slds-m-top_small';
    isLoading = true;
    columns = COLUMNS;
    _wiredResult;

    @wire(getPendingPayments)
    wiredPayments(result) {
        this._wiredResult = result;
        if (result.data) {
            this.payments = result.data.map(p => ({
                ...p,
                'Tenancy__r.Name': p.Tenancy__r?.Name,
                'Invoice__r.Name': p.Invoice__r?.Name
            }));
            this.isLoading = false;
        } else if (result.error) {
            this.error = result.error?.body?.message || 'Failed to load pending payments.';
            this.isLoading = false;
        }
    }

    get hasPayments() {
        return this.payments && this.payments.length > 0;
    }

    handleRowAction(e) {
        const action     = e.detail.action;
        const paymentId  = e.detail.row.Id;
        const newStatus  = action.name === 'approve' ? 'Approved' : 'Rejected';

        updatePaymentStatus({ paymentId, newStatus })
            .then(() => {
                this.actionMessage      = `Payment ${newStatus} successfully.`;
                this.actionMessageClass = newStatus === 'Approved'
                    ? 'slds-notify slds-notify_toast slds-theme_success slds-m-top_small'
                    : 'slds-notify slds-notify_toast slds-theme_warning slds-m-top_small';
                return refreshApex(this._wiredResult);
            })
            .catch(err => {
                this.actionMessage      = err?.body?.message || 'Action failed.';
                this.actionMessageClass = 'slds-notify slds-notify_toast slds-theme_error slds-m-top_small';
            });
    }
}