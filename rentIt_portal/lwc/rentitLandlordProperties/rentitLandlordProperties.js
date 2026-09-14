import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import BasePath from '@salesforce/community/basePath';
import getProperties from '@salesforce/apex/RentItLandlordController.getProperties';
import getTenancies from '@salesforce/apex/RentItLandlordController.getTenancies';

export default class RentitLandlordProperties extends NavigationMixin(LightningElement) {
    @track properties = [];
    @track tenancies = [];
    error = null;
    isLoading = true;
    isTenancyLoading = false;
    selectedPropertyId = null;
    statusFilter = 'all';

    @wire(getProperties)
    wiredProperties(result) {
        if (result.data !== undefined || result.error) {
            if (result.data) this.properties = result.data;
            if (result.error) this.error = result.error?.body?.message || 'Unable to load properties.';
            this.isLoading = false;
        }
    }

    // ── Property list ─────────────────────────────────────────────
    get hasProperties() { return this.properties.length > 0; }
    get showList()      { return !this.selectedPropertyId; }
    get showDetail()    { return !!this.selectedPropertyId; }

    get propertyRows() {
        return this.properties.map(p => ({
            ...p,
            address: this._formatAddress(p),
            occupancy: `${p.Occupied_Rooms__c || 0} / ${p.Total_Rooms__c || 0}`
        }));
    }

    _formatAddress(p) {
        const line = [p.Address__Street__s, p.Address__City__s,
                      p.Address__StateCode__s, p.Address__PostalCode__s]
            .filter(Boolean).join(', ');
        return line || '—';
    }

    get selectedProperty() {
        return this.properties.find(p => p.Id === this.selectedPropertyId) || null;
    }

    get selectedPropertyName()    { return this.selectedProperty?.Name || ''; }
    get selectedPropertyType()    { return this.selectedProperty?.Property_Type__c || ''; }
    get selectedPropertyAddress() {
        return this.selectedProperty ? this._formatAddress(this.selectedProperty) : '';
    }

    // ── Drill into a property ─────────────────────────────────────
    handleSelectProperty(event) {
        this.selectedPropertyId = event.currentTarget.dataset.id;
        this.statusFilter = 'all';
        this._loadTenancies(this.selectedPropertyId);
    }

    handleBack() {
        this.selectedPropertyId = null;
        this.tenancies = [];
    }

    _loadTenancies(propertyId) {
        this.isTenancyLoading = true;
        getTenancies({ propertyId })
            .then(data => {
                this.tenancies = data;
                this.isTenancyLoading = false;
            })
            .catch(err => {
                this.error = err?.body?.message || 'Failed to load tenancies.';
                this.isTenancyLoading = false;
            });
    }

    // ── Tenancy status filter ─────────────────────────────────────
    get filteredTenancies() {
        if (this.statusFilter === 'all') return this.tenancies;
        return this.tenancies.filter(t => t.Status__c === this.statusFilter);
    }

    get hasTenancies() { return this.filteredTenancies.length > 0; }

    handleFilter(event) { this.statusFilter = event.currentTarget.dataset.status; }

    get tabAll()        { return this._tabClass('all'); }
    get tabActive()     { return this._tabClass('Active'); }
    get tabPending()    { return this._tabClass('Pending'); }
    get tabExpired()    { return this._tabClass('Expired'); }
    get tabTerminated() { return this._tabClass('Terminated'); }

    _tabClass(v) {
        return 'ri-tab' + (this.statusFilter === v ? ' ri-tab--active' : '');
    }

    // ── Navigate to tenancy detail ────────────────────────────────
    handleOpenTenancy(event) {
        const tenancyId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: `${BasePath}/landlord-tenancy?tenancyId=${tenancyId}` }
        });
    }
}
