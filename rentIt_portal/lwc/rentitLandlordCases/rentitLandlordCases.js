import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getCases from '@salesforce/apex/RentItLandlordController.getCases';
import updateCaseStatus from '@salesforce/apex/RentItLandlordController.updateCaseStatus';

const STATUS_OPTIONS = ['New', 'Working', 'Escalated', 'Closed']
    .map(v => ({ label: v, value: v }));

export default class RentitLandlordCases extends LightningElement {
    @track cases = [];
    error = null;
    successMessage = null;
    isLoading = true;
    typeFilter = 'all';
    statusFilter = 'open';
    expandedId = null;
    processingId = null;

    statusOptions = STATUS_OPTIONS;
    _wiredResult;

    @wire(getCases)
    wiredCases(result) {
        this._wiredResult = result;
        if (result.data !== undefined || result.error) {
            if (result.data) this.cases = result.data;
            if (result.error) {
                this.error = result.error?.body?.message || 'Unable to load requests.';
            }
            this.isLoading = false;
        }
    }

    // ── Filters ───────────────────────────────────────────────────
    get filteredCases() {
        return this.cases.filter(c => {
            const typeOk = this.typeFilter === 'all'
                || (c.RecordType && c.RecordType.Name === this.typeFilter);
            const statusOk = this.statusFilter === 'all'
                || (this.statusFilter === 'open' ? !c.IsClosed : c.IsClosed);
            return typeOk && statusOk;
        });
    }

    get caseRows() {
        return this.filteredCases.map(c => ({
            ...c,
            recordTypeName: c.RecordType?.Name || '—',
            contactName: c.Contact?.Name || '—',
            propertyName: c.Property__r?.Name || '—',
            tenancyName: c.Tenancy__r?.Name || '—',
            detailKey: `${c.Id}-detail`,
            isExpanded: this.expandedId === c.Id,
            isProcessing: this.processingId === c.Id,
            toggleIcon: this.expandedId === c.Id ? 'utility:chevronup' : 'utility:chevrondown'
        }));
    }

    get hasCases() { return this.filteredCases.length > 0; }

    handleTypeFilter(event)   { this.typeFilter = event.currentTarget.dataset.type; }
    handleStatusFilter(event) { this.statusFilter = event.currentTarget.dataset.status; }

    get tabTypeAll()      { return this._tab(this.typeFilter, 'all'); }
    get tabComplaint()    { return this._tab(this.typeFilter, 'Complaint'); }
    get tabMaintenance()  { return this._tab(this.typeFilter, 'Maintenance Request'); }
    get tabOpen()         { return this._tab(this.statusFilter, 'open'); }
    get tabClosed()       { return this._tab(this.statusFilter, 'closed'); }
    get tabStatusAll()    { return this._tab(this.statusFilter, 'all'); }

    _tab(current, value) {
        return 'ri-tab' + (current === value ? ' ri-tab--active' : '');
    }

    // ── Expand / update ───────────────────────────────────────────
    handleToggle(event) {
        const id = event.currentTarget.dataset.id;
        this.expandedId = this.expandedId === id ? null : id;
    }

    handleStatusChange(event) {
        const caseId = event.currentTarget.dataset.id;
        const status = event.detail.value;
        this.error = null;
        this.successMessage = null;
        this.processingId = caseId;

        updateCaseStatus({ caseId, status })
            .then(() => {
                this.successMessage = 'Request updated.';
                this.processingId = null;
                return refreshApex(this._wiredResult);
            })
            .catch(err => {
                this.error = err?.body?.message || 'Failed to update this request.';
                this.processingId = null;
            });
    }
}
