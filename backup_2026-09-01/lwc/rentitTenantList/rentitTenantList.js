import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getAllTenancies from '@salesforce/apex/RentItPortalController.getAllTenancies';

const COLUMNS = [
    { label: 'Tenancy',   fieldName: 'Name',                  type: 'text' },
    { label: 'Property',  fieldName: 'Property__r.Name',       type: 'text' },
    { label: 'Room',      fieldName: 'Room__r.Name',           type: 'text' },
    { label: 'Tenant',    fieldName: 'Tenant__r.Name',         type: 'text' },
    { label: 'Status',    fieldName: 'Status__c',              type: 'text' },
    { label: 'Community User', fieldName: 'Community_User__r.Name', type: 'text' },
    { label: 'Arrears',   fieldName: 'Total_Arrears__c',       type: 'currency',
      typeAttributes: { currencyCode: 'AUD', minimumFractionDigits: 2 } },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'Assign Community User', name: 'assign_user' }
            ]
        }
    }
];

export default class RentitTenantList extends LightningElement {
    @track tenancies;
    @track error;
    @track editingTenancyId;
    isLoading = true;
    columns = COLUMNS;
    editFields = ['Community_User__c'];
    _wiredResult;

    @wire(getAllTenancies)
    wiredTenancies(result) {
        this._wiredResult = result;
        if (result.data) {
            // Flatten nested relationship fields for datatable
            this.tenancies = result.data.map(t => ({
                ...t,
                'Property__r.Name':       t.Property__r?.Name,
                'Room__r.Name':           t.Room__r?.Name,
                'Tenant__r.Name':         t.Tenant__r?.Name,
                'Community_User__r.Name': t.Community_User__r?.Name
            }));
            this.isLoading = false;
        } else if (result.error) {
            this.error = result.error?.body?.message || 'Failed to load tenancies.';
            this.isLoading = false;
        }
    }

    get hasTenancies() {
        return this.tenancies && this.tenancies.length > 0;
    }

    handleRowAction(e) {
        const action = e.detail.action;
        const row    = e.detail.row;
        if (action.name === 'assign_user') {
            this.editingTenancyId = row.Id;
        }
    }

    closeModal() {
        this.editingTenancyId = null;
    }

    handleSaveSuccess() {
        this.editingTenancyId = null;
        refreshApex(this._wiredResult);
    }

    handleSaveError(e) {
        this.error = e.detail?.message || 'Save failed.';
    }
}