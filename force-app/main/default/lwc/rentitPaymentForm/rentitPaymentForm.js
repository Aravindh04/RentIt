import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getActiveTenancy from '@salesforce/apex/RentItPortalController.getActiveTenancy';
import getInvoices from '@salesforce/apex/RentItPortalController.getInvoices';
import submitPayment from '@salesforce/apex/RentItPortalController.submitPayment';

const PAYMENT_METHODS = [
    { label: 'Bank Transfer',  value: 'Bank Transfer' },
    { label: 'Credit Card',    value: 'Credit Card' },
    { label: 'Debit Card',     value: 'Debit Card' },
    { label: 'Cash',           value: 'Cash' },
    { label: 'Other',          value: 'Other' }
];

const MAX_FILE_BYTES = 3 * 1024 * 1024; // 3 MB

export default class RentitPaymentForm extends NavigationMixin(LightningElement) {
    @track tenancy;
    @track invoiceOptions = [];
    @track formError;
    @track submitSuccess = false;
    @track submittedId;

    isLoading    = true;
    isSubmitting = false;
    paymentType  = 'invoice'; // 'invoice' | 'general'

    // Form fields
    selectedInvoiceId = null;
    amount        = null;
    paymentDate   = null;
    paymentMethod = null;
    paymentReference = '';
    comment       = '';

    // File state
    selectedFile    = null;
    imagePreviewUrl = null;
    fileError       = null;
    _base64Content  = null;
    _contentType    = null;

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

    // Payment type
    get isInvoicePayment() { return this.paymentType === 'invoice'; }
    get isGeneralPayment()  { return this.paymentType === 'general'; }
    get btnInvoice() { return 'ri-type-btn' + (this.isInvoicePayment ? ' ri-type-btn--active' : ''); }
    get btnGeneral()  { return 'ri-type-btn' + (this.isGeneralPayment  ? ' ri-type-btn--active' : ''); }
    get successSubMessage() {
        return this.paymentType === 'general'
            ? 'Your payment has been submitted and will be credited to your account once approved.'
            : 'Your payment has been submitted for landlord approval.';
    }

    handleTypeInvoice() { this.paymentType = 'invoice'; this.selectedInvoiceId = null; }
    handleTypeGeneral()  { this.paymentType = 'general'; this.selectedInvoiceId = null; }

    // Form field handlers
    handleInvoiceChange(e)     { this.selectedInvoiceId = e.detail.value; }
    handleAmountChange(e)      { this.amount = parseFloat(e.detail.value); }
    handlePaymentDateChange(e) { this.paymentDate = e.detail.value; }
    handleMethodChange(e)      { this.paymentMethod = e.detail.value; }
    handleReferenceChange(e)   { this.paymentReference = e.detail.value; }
    handleCommentChange(e)     { this.comment = e.detail.value; }

    // File handlers
    handleFileChange(event) {
        this.fileError = null;
        const file = event.target.files && event.target.files[0];
        if (!file) return;
        if (file.size > MAX_FILE_BYTES) {
            this.fileError = 'File is too large. Maximum size is 3 MB.';
            event.target.value = '';
            return;
        }
        this.selectedFile = { name: file.name, size: file.size };
        this._contentType = file.type;
        const reader = new FileReader();
        reader.onload = (e) => {
            const dataUrl = e.target.result;
            this._base64Content = dataUrl.split(',')[1];
            this.imagePreviewUrl = file.type.startsWith('image/') ? dataUrl : null;
        };
        reader.readAsDataURL(file);
    }

    handleFileRemove() {
        this.selectedFile    = null;
        this._base64Content  = null;
        this._contentType    = null;
        this.imagePreviewUrl = null;
        this.fileError       = null;
        const input = this.template.querySelector('input[type="file"]');
        if (input) input.value = '';
    }

    // Computed getters for file display
    get selectedFileName() {
        return this.selectedFile?.name || '';
    }

    get selectedFileSizeFormatted() {
        const bytes = this.selectedFile?.size || 0;
        if (bytes < 1024)       return `${bytes} B`;
        if (bytes < 1048576)    return `${(bytes / 1024).toFixed(1)} KB`;
        return `${(bytes / 1048576).toFixed(1)} MB`;
    }

    get screenshotAttached() {
        return !!this._base64Content;
    }

    // Submit
    handleSubmit() {
        this.formError = null;
        const invoiceRequired = this.isInvoicePayment && !this.selectedInvoiceId;
        if (invoiceRequired || !this.amount || !this.paymentDate || !this.paymentMethod) {
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
            invoiceId:        this.isInvoicePayment ? this.selectedInvoiceId : null,
            amount:           this.amount,
            paymentDate:      this.paymentDate,
            paymentMethod:    this.paymentMethod,
            paymentReference: this.paymentReference,
            comment:          this.comment,
            base64Content:    this._base64Content || null,
            fileName:         this.selectedFile?.name || null,
            contentType:      this._contentType || null
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
