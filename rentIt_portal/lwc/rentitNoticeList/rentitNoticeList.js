import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import BasePath from '@salesforce/community/basePath';
import getActiveTenancy from '@salesforce/apex/RentItPortalController.getActiveTenancy';
import getNotices from '@salesforce/apex/RentItPortalController.getNotices';

export default class RentitNoticeList extends NavigationMixin(LightningElement) {
    @track notices = [];
    @track error;
    isLoading = true;
    selectedNotice = null;

    // Deep-link support: capture ?noticeId=... from the URL the component
    // was loaded with, so a bookmarked/shared/back-navigated link reopens
    // the same notice's detail view once the list has loaded.
    _pendingNoticeId = new URLSearchParams(window.location.search).get('noticeId');

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
                if (this._pendingNoticeId) {
                    this.selectedNotice = this.notices.find(n => n.Id === this._pendingNoticeId) || null;
                    this._pendingNoticeId = null;
                }
            })
            .catch(err => {
                this.error = err?.body?.message || 'Failed to load notices.';
                this.isLoading = false;
            });
    }

    get hasNotices() {
        return this.notices && this.notices.length > 0;
    }

    get showList()   { return !this.selectedNotice; }
    get showDetail() { return !!this.selectedNotice; }

    handleNoticeSelect(event) {
        const id = event.currentTarget.dataset.id;
        this.selectedNotice = this.notices.find(n => n.Id === id) || null;
        this._updateUrl(id);
    }

    handleCloseDetail() {
        this.selectedNotice = null;
        this._updateUrl(null);
    }

    // Reflects the selected notice in the address bar (?noticeId=...) so
    // the detail view is bookmarkable/shareable and survives a refresh or
    // browser back/forward. Uses pushState-style navigation (no full page
    // reload) since this stays on the same /notices route.
    _updateUrl(noticeId) {
        const url = noticeId ? `${BasePath}/notices?noticeId=${noticeId}` : `${BasePath}/notices`;
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url }
        });
    }
}
