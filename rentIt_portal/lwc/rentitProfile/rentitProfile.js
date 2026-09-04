import { LightningElement, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import userId from '@salesforce/user/Id';
import getContactProfile from '@salesforce/apex/RentItPortalController.getContactProfile';

import USER_NAME       from '@salesforce/schema/User.Name';
import USER_FIRSTNAME  from '@salesforce/schema/User.FirstName';
import USER_EMAIL      from '@salesforce/schema/User.Email';
import USER_PHONE      from '@salesforce/schema/User.Phone';
import USER_TITLE      from '@salesforce/schema/User.Title';
import USER_DEPARTMENT from '@salesforce/schema/User.Department';
import USER_PHOTO      from '@salesforce/schema/User.SmallPhotoUrl';
import USER_LAST_LOGIN from '@salesforce/schema/User.LastLoginDate';

const USER_FIELDS = [USER_NAME, USER_FIRSTNAME, USER_EMAIL, USER_PHONE,
                     USER_TITLE, USER_DEPARTMENT, USER_PHOTO, USER_LAST_LOGIN];

export default class RentitProfile extends LightningElement {

    contact = null;

    @wire(getRecord, { recordId: userId, fields: USER_FIELDS })
    userRecord;

    @wire(getContactProfile)
    wiredContact({ data }) {
        if (data) { this.contact = data; }
    }

    // ── User ──────────────────────────────────────────────────────
    get userName()       { return getFieldValue(this.userRecord.data, USER_NAME)       || ''; }
    get userInitial()    { return this.userName ? this.userName.charAt(0).toUpperCase() : '?'; }
    get userEmail()      { return getFieldValue(this.userRecord.data, USER_EMAIL)      || '—'; }
    get userPhone()      { return getFieldValue(this.userRecord.data, USER_PHONE)      || '—'; }
    get userTitle()      { return getFieldValue(this.userRecord.data, USER_TITLE)      || '—'; }
    get userDepartment() { return getFieldValue(this.userRecord.data, USER_DEPARTMENT) || '—'; }
    get userPhotoUrl()   { return getFieldValue(this.userRecord.data, USER_PHOTO); }
    get userLastLogin()  { return getFieldValue(this.userRecord.data, USER_LAST_LOGIN); }
    get hasPhoto()       { return !!this.userPhotoUrl; }

    // ── Contact ───────────────────────────────────────────────────
    get hasContact()       { return !!this.contact; }
    get contactName()      { return [this.contact?.FirstName, this.contact?.LastName].filter(Boolean).join(' ') || '—'; }
    get contactEmail()     { return this.contact?.Email       || '—'; }
    get contactPhone()     { return this.contact?.Phone       || '—'; }
    get contactMobile()    { return this.contact?.MobilePhone || '—'; }
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
}
