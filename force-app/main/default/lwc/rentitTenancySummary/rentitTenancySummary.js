import { LightningElement, api } from 'lwc';
import TENANCY_NAME from '@salesforce/schema/Tenancy__c.Name';
import TENANCY_PROPERTY from '@salesforce/schema/Tenancy__c.Property__c';
import TENANCY_STATUS from '@salesforce/schema/Tenancy__c.Status__c';
import TENANCY_DEPOSIT from '@salesforce/schema/Tenancy__c.Deposit_Amount__c';
import TENANCY_ARREARS from '@salesforce/schema/Tenancy__c.Total_Arrears__c';
import TENANCY_RECEIVED from '@salesforce/schema/Tenancy__c.Total_Received__c';
import TENANCY_CREDITS from '@salesforce/schema/Tenancy__c.Available_Credits__c';

export default class RentitTenancySummary extends LightningElement {
    @api recordId;

    fields = [
        TENANCY_NAME,
        TENANCY_PROPERTY,
        TENANCY_STATUS,
        TENANCY_DEPOSIT,
        TENANCY_ARREARS,
        TENANCY_RECEIVED,
        TENANCY_CREDITS
    ];
}