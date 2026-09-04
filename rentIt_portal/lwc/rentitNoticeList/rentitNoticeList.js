import { LightningElement, api, track } from 'lwc';
import getActiveTenancy from '@salesforce/apex/RentItPortalController.getActiveTenancy';
import getNotices from '@salesforce/apex/RentItPortalController.getNotices';
import getAllNotices from '@salesforce/apex/RentItPortalController.getAllNotices';

export default class RentitNoticeList extends LightningElement {
    @track notices = [];
    @track error;
    isLoading = true;
    selectedNotice = null;
    _landlordMode = false;
    _isConnected = false;

    @api
    get landlordMode() {
        return this._landlordMode;
    }

    set landlordMode(value) {
        this._landlordMode = value !== false && value !== 'false';
        if (this._isConnected) {
            this.loadNotices();
        }
    }

    connectedCallback() {
        this._isConnected = true;
        this.loadNotices();
    }

    get title() {
        return this._landlordMode ? 'All Notices' : 'Notices';
    }

    loadNotices() {
        this.isLoading = true;
        this.error = undefined;
        this.selectedNotice = null;

        if (this._landlordMode) {
            getAllNotices()
                .then(data => {
                    this.notices = data;
                    this.isLoading = false;
                })
                .catch(err => {
                    this.error = err?.body?.message || 'Failed to load notices.';
                    this.isLoading = false;
                });
            return;
        }

        getActiveTenancy()
            .then(tenancy => {
                if (!tenancy?.Id) {
                    this.notices = [];
                    this.isLoading = false;
                    return null;
                }
                return getNotices({ tenancyId: tenancy.Id });
            })
            .then(data => {
                if (data) {
                    this.notices = data;
                }
                this.isLoading = false;
            })
            .catch(err => {
                this.error = err?.body?.message || 'Failed to load notices.';
                this.isLoading = false;
            });
    }

    get hasNotices() {
        return this.notices && this.notices.length > 0;
    }

    get showList() {
        return !this.selectedNotice;
    }

    get showDetail() {
        return !!this.selectedNotice;
    }

    handleNoticeSelect(event) {
        const id = event.currentTarget.dataset.id;
        this.selectedNotice = this.notices.find(n => n.Id === id) || null;
    }

    handleCloseDetail() {
        this.selectedNotice = null;
    }
}
