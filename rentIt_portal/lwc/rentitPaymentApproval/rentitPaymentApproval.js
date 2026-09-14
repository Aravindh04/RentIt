import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getPendingPayments from '@salesforce/apex/RentItLandlordController.getPendingPayments';
import processPaymentApproval from '@salesforce/apex/RentItLandlordController.processPaymentApproval';

export default class RentitPaymentApproval extends LightningElement {
    @track payments = [];
    error = null;
    successMessage = null;
    isLoading = true;
    processingId = null;

    /** Per-payment approver comment, keyed by payment Id. */
    comments = {};

    _wiredResult;

    @wire(getPendingPayments)
    wiredPayments(result) {
        this._wiredResult = result;
        if (result.data !== undefined || result.error) {
            if (result.data) this.payments = result.data;
            if (result.error) {
                this.error = result.error?.body?.message || 'Unable to load pending payments.';
            }
            this.isLoading = false;
        }
    }

    get hasPayments() { return this.payments.length > 0; }
    get pendingCount() { return this.payments.length; }

    get paymentRows() {
        return this.payments.map(p => ({
            ...p,
            tenantName: p.Tenancy__r?.Tenant__r?.Name || '—',
            propertyName: p.Tenancy__r?.Property__r?.Name || '—',
            tenancyName: p.Tenancy__r?.Name || '—',
            invoiceName: p.Invoice__r?.Name || 'General payment',
            isProcessing: this.processingId === p.Id
        }));
    }

    handleComment(event) {
        this.comments = {
            ...this.comments,
            [event.currentTarget.dataset.id]: event.detail.value
        };
    }

    handleApprove(event) { this._process(event.currentTarget.dataset.id, 'Approve'); }
    handleReject(event)  { this._process(event.currentTarget.dataset.id, 'Reject'); }

    _process(paymentId, action) {
        this.error = null;
        this.successMessage = null;
        this.processingId = paymentId;

        processPaymentApproval({
            paymentId,
            action,
            comments: this.comments[paymentId] || ''
        })
            .then(() => {
                this.successMessage = action === 'Approve'
                    ? 'Payment approved. The tenant has been notified.'
                    : 'Payment rejected. The tenant has been notified.';
                this.processingId = null;
                const next = { ...this.comments };
                delete next[paymentId];
                this.comments = next;
                return refreshApex(this._wiredResult);
            })
            .catch(err => {
                this.error = err?.body?.message || `Failed to ${action.toLowerCase()} this payment.`;
                this.processingId = null;
            });
    }
}
