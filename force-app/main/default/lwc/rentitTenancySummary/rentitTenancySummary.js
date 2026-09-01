import { LightningElement, wire } from 'lwc';
import getActiveTenancy from '@salesforce/apex/RentItPortalController.getActiveTenancy';
import getContract from '@salesforce/apex/RentItPortalController.getContract';

export default class RentitTenancySummary extends LightningElement {
    tenancy  = null;
    contract = null;
    isLoading = true;

    @wire(getActiveTenancy)
    wiredTenancy({ data, error }) {
        if (data) { this.tenancy = data; }
        this.isLoading = false;
    }

    @wire(getContract, { tenancyId: '$tenancyId' })
    wiredContract({ data }) {
        if (data) { this.contract = data; }
    }

    // ── Tenancy ───────────────────────────────────────────────────
    get tenancyId()   { return this.tenancy?.Id || null; }
    get hasTenancy()  { return !!this.tenancy; }
    get tenancyName() { return this.tenancy?.Name || ''; }
    get status()      { return this.tenancy?.Status__c || ''; }
    get arrears()     { return this.tenancy?.Total_Arrears__c || 0; }
    get credits()     { return this.tenancy?.Available_Credits__c || 0; }
    get deposit()     { return this.tenancy?.Deposit_Amount__c || 0; }
    get received()    { return this.tenancy?.Total_Received__c || 0; }

    // ── Property ──────────────────────────────────────────────────
    get hasProperty()         { return !!this.tenancy?.Property__c; }
    get propertyName()        { return this.tenancy?.Property__r?.Name || ''; }
    get propertyDescription() { return this.tenancy?.Property__r?.Description__c || ''; }
    get propertyAddress() {
        const p = this.tenancy?.Property__r;
        const line1 = p?.Address__Street__s || '';
        const line2 = [p?.Address__City__s, p?.Address__StateCode__s, p?.Address__PostalCode__s]
            .filter(Boolean).join(' ');
        const line3 = p?.Address__CountryCode__s || '';
        return [line1, line2, line3].filter(Boolean).join(', ') || '—';
    }

    // ── Room ──────────────────────────────────────────────────────
    get hasRoom()  { return !!this.tenancy?.Room__c; }
    get roomName() { return this.tenancy?.Room__r?.Name || ''; }
    get roomSize() { return this.tenancy?.Room__r?.Room_Size__c || '—'; }

    get facilityPills() {
        const raw = this.tenancy?.Room__r?.Facilities__c;
        if (!raw) return [];
        return raw.split(';')
            .map(f => f.trim())
            .filter(Boolean)
            .map((label, i) => ({ id: i, label }));
    }
    get hasFacilities() { return this.facilityPills.length > 0; }

    // ── Contract ──────────────────────────────────────────────────
    get hasContract()            { return !!this.contract; }
    get contractNumber()         { return this.contract?.ContractNumber || '—'; }
    get contractStatus()         { return this.contract?.Status || ''; }
    get contractStart()          { return this.contract?.StartDate; }
    get contractEnd()            { return this.contract?.EndDate; }
    get contractRent()           { return this.contract?.Rent_Amount__c; }
    get contractFrequency()      { return this.contract?.Rent_Frequency__c || ''; }
    get contractDeposit()        { return this.contract?.Deposit_Amount__c; }
    get contractConditions()     { return this.contract?.Special_Conditions__c || ''; }
    get hasContractConditions()  { return !!this.contract?.Special_Conditions__c; }
}
