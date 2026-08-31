import { LightningElement, wire, track } from 'lwc';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import CASE_OBJECT from '@salesforce/schema/Case';
import getActiveTenancy from '@salesforce/apex/RentItPortalController.getActiveTenancy';

export default class RentitMaintenanceForm extends LightningElement {
    @track tenancy;
    @track submitSuccess = false;
    @track submittedCaseNumber;
    isLoading = true;

    maintenanceRecordTypeId;

    @wire(getObjectInfo, { objectApiName: CASE_OBJECT })
    caseObjectInfo({ data, error }) {
        if (data) {
            const rtInfo = Object.values(data.recordTypeInfos).find(
                rt => rt.developerName === 'Maintenance_Request' && rt.available
            );
            this.maintenanceRecordTypeId = rtInfo ? rtInfo.recordTypeId : null;
        }
    }

    @wire(getActiveTenancy)
    wiredTenancy({ data, error }) {
        if (data) {
            this.tenancy = data;
        }
        this.isLoading = false;
    }

    get tenancyId()         { return this.tenancy?.Id; }
    get tenancyPropertyId() { return this.tenancy?.Property__c; }
    get tenancyRoomId()     { return this.tenancy?.Room__c; }

    handleSuccess(e) {
        this.submittedCaseNumber = e.detail.fields?.CaseNumber?.value || e.detail.id;
        this.submitSuccess = true;
    }

    handleError(e) {
        console.error('Maintenance form error:', JSON.stringify(e.detail));
    }
}
