import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, getFieldValue, updateRecord } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';
import userId from '@salesforce/user/Id';
import getContactProfile from '@salesforce/apex/RentItPortalController.getContactProfile';

import USER_NAME       from '@salesforce/schema/User.Name';
import USER_EMAIL      from '@salesforce/schema/User.Email';
import USER_PHONE      from '@salesforce/schema/User.Phone';
import USER_TITLE      from '@salesforce/schema/User.Title';
import USER_DEPARTMENT from '@salesforce/schema/User.Department';
import USER_PHOTO      from '@salesforce/schema/User.SmallPhotoUrl';
import USER_LAST_LOGIN from '@salesforce/schema/User.LastLoginDate';

const USER_FIELDS = [USER_NAME, USER_EMAIL, USER_PHONE,
                     USER_TITLE, USER_DEPARTMENT, USER_PHOTO, USER_LAST_LOGIN];

export default class RentitProfile extends LightningElement {
    contact = null;
    userRecord = {};
    isEditMode = false;
    isLoading = true;
    isSaving = false;
    wiredContactResult;
    draftValues = {};
    hasUserRecordLoaded = false;
    hasContactLoaded = false;

    @wire(getRecord, { recordId: userId, fields: USER_FIELDS })
    wiredUserRecord(result) {
        this.userRecord = result;
        if (result.data !== undefined || result.error) {
            this.hasUserRecordLoaded = true;
            this.updateLoadingState();
        }
    }

    @wire(getContactProfile)
    wiredContact(result) {
        this.wiredContactResult = result;
        if (result.data) {
            this.contact = result.data;
        }
        if (result.data !== undefined || result.error) {
            this.hasContactLoaded = true;
            this.updateLoadingState();
        }
    }

    updateLoadingState() {
        this.isLoading = !(this.hasUserRecordLoaded && this.hasContactLoaded);
    }

    // ── User ──────────────────────────────────────────────────────
    get userNameRaw()    { return getFieldValue(this.userRecord?.data, USER_NAME) || ''; }
    get userEmailRaw()   { return getFieldValue(this.userRecord?.data, USER_EMAIL) || ''; }
    get userPhoneRaw()   { return getFieldValue(this.userRecord?.data, USER_PHONE) || ''; }
    get userTitleRaw()   { return getFieldValue(this.userRecord?.data, USER_TITLE) || ''; }
    get userDeptRaw()    { return getFieldValue(this.userRecord?.data, USER_DEPARTMENT) || ''; }
    get userName()       { return getFieldValue(this.userRecord?.data, USER_NAME)       || ''; }
    get userInitial()    { return this.userName ? this.userName.charAt(0).toUpperCase() : '?'; }
    get userEmail()      { return getFieldValue(this.userRecord?.data, USER_EMAIL)      || '—'; }
    get userPhone()      { return getFieldValue(this.userRecord?.data, USER_PHONE)      || '—'; }
    get userTitle()      { return getFieldValue(this.userRecord?.data, USER_TITLE)      || '—'; }
    get userDepartment() { return getFieldValue(this.userRecord?.data, USER_DEPARTMENT) || '—'; }
    get userPhotoUrl()   { return getFieldValue(this.userRecord?.data, USER_PHOTO); }
    get userLastLogin()  { return getFieldValue(this.userRecord?.data, USER_LAST_LOGIN); }
    get hasPhoto()       { return !!this.userPhotoUrl; }

    // ── Contact ───────────────────────────────────────────────────
    get hasContact()       { return !!this.contact; }
    get contactName()      { return [this.contact?.FirstName, this.contact?.LastName].filter(Boolean).join(' ') || '—'; }
    get contactEmail()     { return this.contact?.Email       || '—'; }
    get contactPhone()     { return this.contact?.Phone       || '—'; }
    get contactPhoneRaw()  { return this.contact?.Phone       || ''; }
    get contactMobile()    { return this.contact?.MobilePhone || '—'; }
    get contactStreetRaw() { return this.contact?.MailingStreet || ''; }
    get contactCityRaw()   { return this.contact?.MailingCity || ''; }
    get contactStateRaw()  { return this.contact?.MailingState || ''; }
    get contactPostRaw()   { return this.contact?.MailingPostalCode || ''; }
    get contactCountryRaw(){ return this.contact?.MailingCountry || ''; }
    get contactAddress() {
        if (!this.contact) return '—';
        const street  = this.contact.MailingStreet      || '';
        const city    = this.contact.MailingCity        || '';
        const state   = this.contact.MailingState       || '';
        const post    = this.contact.MailingPostalCode  || '';
        const country = this.contact.MailingCountry     || '';
        const line2   = [city, state, post].filter(Boolean).join(' ');
        return [street, line2, country].filter(Boolean).join(', ') || '—';
    }

    // ── Account (ABN / GST) ───────────────────────────────────────
    get abn()          { return this.contact?.Account?.ABN__c       || '—'; }
    get gstNumber()    { return this.contact?.Account?.GST_Number__c || '—'; }
    get gstRegistered(){ return this.contact?.Account?.GST_Registered__c ? 'Yes' : 'No'; }
    get hasAbn()       { return !!(this.contact?.Account?.ABN__c || this.contact?.Account?.GST_Number__c || this.contact?.Account?.GST_Registered__c !== undefined); }
    get abnRaw()       { return this.contact?.Account?.ABN__c || ''; }
    get gstNumberRaw() { return this.contact?.Account?.GST_Number__c || ''; }
    get gstRegRaw()    { return !!this.contact?.Account?.GST_Registered__c; }

    get draftUserTitle()      { return this.draftValues.userTitle; }
    get draftUserDepartment() { return this.draftValues.userDepartment; }
    get draftUserPhone()      { return this.draftValues.userPhone; }
    get draftContactPhone()   { return this.draftValues.contactPhone; }
    get draftMailingStreet()  { return this.draftValues.mailingStreet; }
    get draftMailingCity()    { return this.draftValues.mailingCity; }
    get draftMailingState()   { return this.draftValues.mailingState; }
    get draftMailingPost()    { return this.draftValues.mailingPostalCode; }
    get draftMailingCountry() { return this.draftValues.mailingCountry; }
    get draftAbn()            { return this.draftValues.abn; }
    get draftGstNumber()      { return this.draftValues.gstNumber; }
    get draftGstRegistered()  { return this.draftValues.gstRegistered; }

    handleEditClick() {
        this.draftValues = {
            userTitle: this.userTitleRaw,
            userDepartment: this.userDeptRaw,
            userPhone: this.userPhoneRaw,
            contactPhone: this.contactPhoneRaw,
            mailingStreet: this.contactStreetRaw,
            mailingCity: this.contactCityRaw,
            mailingState: this.contactStateRaw,
            mailingPostalCode: this.contactPostRaw,
            mailingCountry: this.contactCountryRaw,
            abn: this.abnRaw,
            gstNumber: this.gstNumberRaw,
            gstRegistered: this.gstRegRaw
        };
        this.isEditMode = true;
    }

    handleCancelClick() {
        this.isEditMode = false;
        this.isSaving = false;
    }

    handleInputChange(event) {
        const fieldName = event.target.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        this.draftValues = { ...this.draftValues, [fieldName]: value };
    }

    async handleSaveClick() {
        if (this.isSaving) return;

        this.isSaving = true;
        try {
            const saveRequests = [
                updateRecord({
                    fields: {
                        Id: userId,
                        Phone: this.toNull(this.draftValues.userPhone),
                        Title: this.toNull(this.draftValues.userTitle),
                        Department: this.toNull(this.draftValues.userDepartment)
                    }
                })
            ];

            if (this.contact?.Id) {
                saveRequests.push(
                    updateRecord({
                        fields: {
                            Id: this.contact.Id,
                            Phone: this.toNull(this.draftValues.contactPhone),
                            MailingStreet: this.toNull(this.draftValues.mailingStreet),
                            MailingCity: this.toNull(this.draftValues.mailingCity),
                            MailingState: this.toNull(this.draftValues.mailingState),
                            MailingPostalCode: this.toNull(this.draftValues.mailingPostalCode),
                            MailingCountry: this.toNull(this.draftValues.mailingCountry)
                        }
                    })
                );
            }

            if (this.contact?.AccountId) {
                saveRequests.push(
                    updateRecord({
                        fields: {
                            Id: this.contact.AccountId,
                            ABN__c: this.toNull(this.draftValues.abn),
                            GST_Number__c: this.toNull(this.draftValues.gstNumber),
                            GST_Registered__c: !!this.draftValues.gstRegistered
                        }
                    })
                );
            }

            await Promise.all(saveRequests);
            await Promise.all([refreshApex(this.userRecord), refreshApex(this.wiredContactResult)]);

            this.isEditMode = false;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Profile updated',
                    message: 'Your profile details were saved successfully.',
                    variant: 'success'
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Unable to save profile',
                    message: this.getErrorMessage(error),
                    variant: 'error'
                })
            );
        } finally {
            this.isSaving = false;
        }
    }

    toNull(value) {
        if (value === undefined || value === null) return null;
        if (typeof value === 'string') {
            const trimmed = value.trim();
            return trimmed === '' ? null : trimmed;
        }
        return value;
    }

    getErrorMessage(error) {
        const body = error?.body;
        if (Array.isArray(body)) {
            return body.map((e) => e.message).join(', ');
        }
        return body?.message || error?.message || 'An unexpected error occurred while saving.';
    }
}
