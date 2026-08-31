import { LightningElement, wire, track } from 'lwc';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';
import CASE_OBJECT from '@salesforce/schema/Case';
import getActiveTenancy from '@salesforce/apex/RentItPortalController.getActiveTenancy';

export default class RentitComplaintForm extends LightningElement {
    @track tenancy;
    @track submitSuccess = false;
    @track submittedCaseNumber;
    isLoading = true;

    // Resolve the Complaint record type ID from the object info
    complaintRecordTypeId;

    @wire(getObjectInfo, { objectApiName: CASE_OBJECT })
    caseObjectInfo({ data, error }) {
        if (data) {
            const rtInfo = Object.values(data.recordTypeInfos).find(
                rt => rt.developerName === 'Complaint' && rt.available
            );
            this.complaintRecordTypeId = rtInfo ? rtInfo.recordTypeId : null;
        }
        // isLoading is cleared by the tenancy wire
    }

    @wire(getActiveTenancy)
    wiredTenancy({ data, error }) {
        if (data) {
            this.tenancy = data;
        }
        // Always clear loading — even if error (landlord user will see the form without pre-fill)
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
        // lightning-messages handles display within lightning-record-edit-form
        console.error('Complaint form error:', JSON.stringify(e.detail));
    }
}