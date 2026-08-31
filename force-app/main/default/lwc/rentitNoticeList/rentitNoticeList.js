import { LightningElement, wire, track } from 'lwc';
import getActiveTenancy from '@salesforce/apex/RentItPortalController.getActiveTenancy';
import getNotices from '@salesforce/apex/RentItPortalController.getNotices';

export default class RentitNoticeList extends LightningElement {
    @track notices = [];
    @track error;
    isLoading = true;

    @wire(getActiveTenancy)
    wiredTenancy({ data, error }) {
        if (data) {
            this._loadNotices(data.Id);
        } else if (error) {
            this.error = 'Unable to load tenancy information.';
            this.isLoading = false;
        }
    }

    _loadNotices(tenancyId) {
        getNotices({ tenancyId })
            .then(data => {
                this.notices = data;
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
}
