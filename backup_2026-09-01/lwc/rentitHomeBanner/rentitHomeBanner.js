import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import userId from '@salesforce/user/Id';
import USER_NAME_FIELD from '@salesforce/schema/User.Name';
import getActiveTenancy from '@salesforce/apex/RentItPortalController.getActiveTenancy';
import getInvoices from '@salesforce/apex/RentItPortalController.getInvoices';

const ALERT_DAYS = 7;

export default class RentitHomeBanner extends NavigationMixin(LightningElement) {
    @track tenancy;
    @track upcomingInvoice;
    @track error;
    isLoading = true;

    @wire(getRecord, { recordId: userId, fields: [USER_NAME_FIELD] })
    currentUser;

    get userName() {
        return getFieldValue(this.currentUser.data, USER_NAME_FIELD) || '';
    }

    get firstName() {
        return this.userName ? this.userName.split(' ')[0] : 'there';
    }

    get avatarInitial() {
        return this.userName ? this.userName.charAt(0).toUpperCase() : '?';
    }

    get statusClass() {
        return this.tenancy ? (this.tenancy.Status__c || '').toLowerCase() : '';
    }

    @wire(getActiveTenancy)
    wiredTenancy({ data, error }) {
        if (data) {
            this.tenancy = data;
            this.isLoading = false;
            this._loadUpcomingInvoice(data.Id);
        } else if (error) {
            this.isLoading = false;
        }
    }

    _loadUpcomingInvoice(tenancyId) {
        getInvoices({ tenancyId })
            .then(invoices => {
                const today = new Date();
                const cutoff = new Date();
                cutoff.setDate(today.getDate() + ALERT_DAYS);
                this.upcomingInvoice = invoices.find(inv => {
                    if (!inv.Due_Date__c || inv.Balance_Due__c <= 0) return false;
                    const due = new Date(inv.Due_Date__c);
                    return due >= today && due <= cutoff;
                });
            })
            .catch(() => {});
    }

    navigateToInvoices() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: 'invoices' }
        });
    }
}
