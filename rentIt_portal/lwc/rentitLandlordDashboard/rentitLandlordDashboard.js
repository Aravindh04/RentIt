import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getPortfolioSummary from '@salesforce/apex/RentItPortalController.getPortfolioSummary';

const OPERATIONS = [
    { key: 'properties', label: 'Properties', buttonLabel: 'Open Properties', icon: 'standard:account', objectApiName: 'Property__c', description: 'List and update property records.' },
    { key: 'rooms', label: 'Rooms', buttonLabel: 'Open Rooms', icon: 'standard:individual', objectApiName: 'Room__c', description: 'Manage room specs and availability.' },
    { key: 'tenancies', label: 'Tenancies', buttonLabel: 'Open Tenancies', icon: 'standard:service_contract', objectApiName: 'Tenancy__c', description: 'Create and update tenancy records.' },
    { key: 'tenants', label: 'Tenants', buttonLabel: 'Open Tenants', icon: 'standard:contact', objectApiName: 'Account', description: 'Manage tenant Person Accounts.' },
    { key: 'contracts', label: 'Contracts', buttonLabel: 'Open Contracts', icon: 'standard:contract', objectApiName: 'Contract', description: 'Create and update rental agreements.' },
    { key: 'invoices', label: 'Invoices', buttonLabel: 'Open Invoices', icon: 'standard:invoice', objectApiName: 'Invoice__c', description: 'Issue invoices and review balances.' },
    { key: 'payments', label: 'Payments', buttonLabel: 'Open Payments', icon: 'utility:money', objectApiName: 'Payment__c', description: 'Approve or reject submitted payments.' },
    { key: 'discounts', label: 'Discounts', buttonLabel: 'Open Discounts', icon: 'standard:pricebook_entry', objectApiName: 'Discount__c', description: 'Create and manage rent discounts.' },
    { key: 'notices', label: 'Notices', buttonLabel: 'Open Notices', icon: 'utility:notification', objectApiName: 'Notice__c', description: 'Publish notices for tenancies and properties.' }
];

export default class RentitLandlordDashboard extends NavigationMixin(LightningElement) {
    @track summary;
    @track error;
    isLoading = true;

    @wire(getPortfolioSummary)
    wiredSummary({ data, error }) {
        if (data) {
            this.summary = data;
            this.isLoading = false;
        } else if (error) {
            this.error = error?.body?.message || 'Failed to load dashboard.';
            this.isLoading = false;
        }
    }

    get operations() {
        return OPERATIONS;
    }

    handleOpenOperation(event) {
        const objectApiName = event.currentTarget.dataset.objectApiName;
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName,
                actionName: 'home'
            }
        });
    }
}
