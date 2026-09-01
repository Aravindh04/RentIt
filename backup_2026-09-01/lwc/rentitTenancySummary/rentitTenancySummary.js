import { LightningElement, wire, track } from 'lwc';
import getActiveTenancy from '@salesforce/apex/RentItPortalController.getActiveTenancy';
import TENANCY_NAME from '@salesforce/schema/Tenancy__c.Name';
import TENANCY_PROPERTY from '@salesforce/schema/Tenancy__c.Property__c';
import TENANCY_STATUS from '@salesforce/schema/Tenancy__c.Status__c';
import TENANCY_DEPOSIT from '@salesforce/schema/Tenancy__c.Deposit_Amount__c';
import TENANCY_ARREARS from '@salesforce/schema/Tenancy__c.Total_Arrears__c';
import TENANCY_RECEIVED from '@salesforce/schema/Tenancy__c.Total_Received__c';
import TENANCY_CREDITS from '@salesforce/schema/Tenancy__c.Available_Credits__c';

export default class RentitTenancySummary extends LightningElement {
    @track tenancyId;
    isLoading = true;

    fields = [
        TENANCY_NAME,
        TENANCY_PROPERTY,
        TENANCY_STATUS,
        TENANCY_DEPOSIT,
        TENANCY_ARREARS,
        TENANCY_RECEIVED,
        TENANCY_CREDITS
    ];

    @wire(getActiveTenancy)
    wiredTenancy({ data, error }) {
        if (data) {
            this.tenancyId = data.Id;
        }
        this.isLoading = false;
    }
}
