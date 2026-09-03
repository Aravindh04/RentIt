import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getActiveTenancy from '@salesforce/apex/RentItPortalController.getActiveTenancy';
import getInvoices from '@salesforce/apex/RentItPortalController.getInvoices';
import submitPayment from '@salesforce/apex/RentItPortalController.submitPayment';

const PAYMENT_METHODS = [
    { label: 'Bank Transfer',  value: 'Bank Transfer' },
    { label: 'Pay ID',    value: 'Pay ID' },
    { label: 'Cash',           value: 'Cash' }
];

export default class RentitPaymentForm extends NavigationMixin(LightningElement) {
    @track tenancy;
    @track invoiceOptions = [];
    @track formError;
    @track submitSuccess = false;
    @track submittedId;

    isLoading    = true;
    isSubmitting = false;

    // Form field values — only tenant-editable fields
    selectedInvoiceId = null;
    amount        = null;
    paymentDate   = null;
    paymentMethod = null;
    paymentReference = '';
    comment       = '';

    paymentMethodOptions = PAYMENT_METHODS;

    @wire(getActiveTenancy)
    wiredTenancy({ data, error }) {
        if (data) {
            this.tenancy = data;
            this._loadInvoices(data.Id);
        } else if (error) {
            this.formError = 'Unable to load your tenancy. Please contact support.';
            this.isLoading = false;
        }
    }

    _loadInvoices(tenancyId) {
        getInvoices({ tenancyId })
            .then(invoices => {
                this.invoiceOptions = invoices
                    .filter(inv => inv.Balance_Due__c > 0)
                    .map(inv => ({
                        label: `${inv.Name} — Balance: $${inv.Balance_Due__c}`,
                        value: inv.Id
                    }));
                this.isLoading = false;
            })
            .catch(err => {
                this.formError = err?.body?.message || 'Failed to load invoices.';
                this.isLoading = false;
            });
    }

    handleInvoiceChange(e)   { this.selectedInvoiceId = e.detail.value; }
    handleAmountChange(e)    { this.amount = parseFloat(e.detail.value); }
    handlePaymentDateChange(e) { this.paymentDate = e.detail.value; }
    handleMethodChange(e)    { this.paymentMethod = e.detail.value; }
    handleReferenceChange(e) { this.paymentReference = e.detail.value; }
    handleCommentChange(e)   { this.comment = e.detail.value; }

    handleSubmit() {
        this.formError = null;
        if (!this.selectedInvoiceId || !this.amount || !this.paymentDate || !this.paymentMethod) {
            this.formError = 'Please fill in all required fields.';
            return;
        }
        if (this.amount <= 0) {
            this.formError = 'Amount must be greater than zero.';
            return;
        }

        this.isSubmitting = true;
        submitPayment({
            tenancyId:        this.tenancy.Id,
            invoiceId:        this.selectedInvoiceId,
            amount:           this.amount,
            paymentDate:      this.paymentDate,
            paymentMethod:    this.paymentMethod,
            paymentReference: this.paymentReference,
            comment:          this.comment
        })
            .then(paymentId => {
                this.submittedId = paymentId;
                this.submitSuccess = true;
                this.isSubmitting = false;
            })
            .catch(err => {
                this.formError = err?.body?.message || 'Submission failed. Please try again.';
                this.isSubmitting = false;
            });
    }
}