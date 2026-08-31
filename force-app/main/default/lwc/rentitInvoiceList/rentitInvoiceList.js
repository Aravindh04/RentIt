import { LightningElement, wire, track } from 'lwc';
import getActiveTenancy from '@salesforce/apex/RentItPortalController.getActiveTenancy';
import getInvoices from '@salesforce/apex/RentItPortalController.getInvoices';

const COLUMNS = [
    { label: 'Invoice',       fieldName: 'Name',             type: 'text' },
    { label: 'Period Start',  fieldName: 'Period_Start__c',  type: 'date' },
    { label: 'Period End',    fieldName: 'Period_End__c',    type: 'date' },
    { label: 'Total Amount',  fieldName: 'Total_Amount__c',  type: 'currency',
      typeAttributes: { currencyCode: 'AUD', minimumFractionDigits: 2 } },
    { label: 'GST Amount',    fieldName: 'GST_Amount__c',    type: 'currency',
      typeAttributes: { currencyCode: 'AUD', minimumFractionDigits: 2 } },
    { label: 'Total Paid',    fieldName: 'Total_Paid__c',    type: 'currency',
      typeAttributes: { currencyCode: 'AUD', minimumFractionDigits: 2 } },
    { label: 'Balance Due',   fieldName: 'Balance_Due__c',   type: 'currency',
      typeAttributes: { currencyCode: 'AUD', minimumFractionDigits: 2 } },
    { label: 'Due Date',      fieldName: 'Due_Date__c',      type: 'date' },
    { label: 'Status',        fieldName: 'Status__c',        type: 'text' }
];

export default class RentitInvoiceList extends LightningElement {
    @track invoices;
    @track error;
    isLoading = true;
    columns = COLUMNS;

    // Step 1: resolve tenancy
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

    get hasInvoices() {
        return this.invoices && this.invoices.length > 0;
    }
}
