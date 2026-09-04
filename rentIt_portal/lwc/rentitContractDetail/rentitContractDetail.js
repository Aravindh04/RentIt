import { LightningElement, wire } from 'lwc';
import getActiveTenancy from '@salesforce/apex/RentItPortalController.getActiveTenancy';
import getContract      from '@salesforce/apex/RentItPortalController.getContract';
import getContractFiles from '@salesforce/apex/RentItPortalController.getContractFiles';

export default class RentitContractDetail extends LightningElement {

    tenancy  = null;
    contract = null;
    files    = [];
    isLoading         = true;
    isAttachmentsOpen = false;

    @wire(getActiveTenancy)
    wiredTenancy({ data }) {
        if (data) { this.tenancy = data; }
        this.isLoading = false;
    }

    @wire(getContract, { tenancyId: '$tenancyId' })
    wiredContract({ data }) {
        if (data) { this.contract = data; }
    }

    @wire(getContractFiles, { contractId: '$contractId', tenancyId: '$tenancyId' })
    wiredFiles({ data }) {
        if (data) {
            this.files = data.map(f => ({
                id:          f.ContentDocumentId,
                title:       f.ContentDocument.Title,
                fileType:    (f.ContentDocument.FileType || '').toUpperCase(),
                size:        this._formatSize(f.ContentDocument.ContentSize),
                downloadUrl: `/sfc/servlet.shepherd/document/download/${f.ContentDocumentId}`
            }));
        }
    }

    // ── Tenancy ───────────────────────────────────────────────────
    get tenancyId()  { return this.tenancy?.Id  || null; }
    get hasContract(){ return !!this.contract; }

    // ── Contract ──────────────────────────────────────────────────
    get contractId()        { return this.contract?.Id || null; }
    get contractNumber()    { return this.contract?.ContractNumber || '—'; }
    get contractStatus()    { return this.contract?.Status || ''; }
    get contractStart()     { return this.contract?.StartDate; }
    get contractEnd()       { return this.contract?.EndDate; }
    get contractRent()      { return this.contract?.Rent_Amount__c; }
    get contractFrequency() { return this.contract?.Rent_Frequency__c || ''; }
    get contractDeposit()   { return this.contract?.Deposit_Amount__c; }
    get hasConditions()     { return !!this.contract?.Special_Conditions__c; }
    get contractConditions(){ return this.contract?.Special_Conditions__c || ''; }

    // ── Attachments ───────────────────────────────────────────────
    get hasFiles()  { return this.files.length > 0; }
    get fileCount() { return this.files.length; }
    get attachmentLabel() {
        return this.fileCount > 0 ? `Attachments (${this.fileCount})` : 'Attachments';
    }
    get toggleIcon() {
        return this.isAttachmentsOpen ? 'utility:chevronup' : 'utility:chevrondown';
    }

    toggleAttachments() { this.isAttachmentsOpen = !this.isAttachmentsOpen; }

    _formatSize(bytes) {
        if (!bytes) return '';
        if (bytes < 1024)    return `${bytes} B`;
        if (bytes < 1048576) return `${(bytes / 1024).toFixed(1)} KB`;
        return `${(bytes / 1048576).toFixed(1)} MB`;
    }
}
