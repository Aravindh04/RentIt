import { LightningElement } from 'lwc';
import BasePath from '@salesforce/community/basePath';

export default class RentitFooter extends LightningElement {
    get myTenancyUrl()      { return `${BasePath}/my-tenancy`; }
    get invoicesUrl()       { return `${BasePath}/invoices`; }
    get makePaymentUrl()    { return `${BasePath}/make-a-payment`; }
    get paymentHistoryUrl() { return `${BasePath}/payment-history`; }
    get noticesUrl()        { return `${BasePath}/notices`; }
}
