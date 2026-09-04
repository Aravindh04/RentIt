import { LightningElement, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import userId from '@salesforce/user/Id';
import isGuest from '@salesforce/user/isGuest';
import BasePath from '@salesforce/community/basePath';
import USER_NAME       from '@salesforce/schema/User.Name';
import USER_FIRSTNAME  from '@salesforce/schema/User.FirstName';
import USER_EMAIL      from '@salesforce/schema/User.Email';
import USER_PHOTO      from '@salesforce/schema/User.SmallPhotoUrl';
import USER_TYPE       from '@salesforce/schema/User.UserType';

const FIELDS = [USER_NAME, USER_FIRSTNAME, USER_EMAIL, USER_PHOTO, USER_TYPE];

const TENANT_NAV_ITEMS = [
    { key: 'home', label: 'Home', target: '' },
    { key: 'my-tenancy', label: 'My Tenancy', target: 'my-tenancy' },
    { key: 'invoices', label: 'Invoices', target: 'invoices' },
    { key: 'payments', label: 'Payments', target: 'payments' },
    { key: 'notices', label: 'Notices', target: 'notices' },
    { key: 'my-contract', label: 'Contract', target: 'my-contract' },
    { key: 'support', label: 'Support', target: 'support' }
];

const LANDLORD_NAV_ITEMS = [
    { key: 'overview', label: 'Dashboard', target: '' },
    { key: 'operations', label: 'Operations', target: '#operations' },
    { key: 'tenancies', label: 'Tenancies', target: '#tenancies' },
    { key: 'payments', label: 'Payments', target: '#payments' },
    { key: 'notices', label: 'Notices', target: '#notices' },
    { key: 'profile', label: 'Profile', target: 'profile' }
];

export default class RentitHeader extends NavigationMixin(LightningElement) {
    isDropdownOpen   = false;
    isMobileMenuOpen = false;
    hasRedirected    = false;

    @wire(getRecord, { recordId: userId, fields: FIELDS })
    currentUser;

    @wire(CurrentPageReference)
    currentPageRef;

    get isLoggedIn()   { return !isGuest; }
    get loginUrl()     { return `${BasePath}/login`; }
    get userName()     { return getFieldValue(this.currentUser.data, USER_NAME)      || ''; }
    get userFirstName(){ return getFieldValue(this.currentUser.data, USER_FIRSTNAME) || ''; }
    get userEmail()    { return getFieldValue(this.currentUser.data, USER_EMAIL)     || ''; }
    get userPhotoUrl() { return getFieldValue(this.currentUser.data, USER_PHOTO); }
    get userType()     { return getFieldValue(this.currentUser.data, USER_TYPE)      || ''; }
    get portalMode()   { return this.userType === 'PowerPartner' ? 'landlord' : 'tenant'; }
    get userInitial()  { return this.userName ? this.userName.charAt(0).toUpperCase() : '?'; }
    get hasPhoto()     { return !!this.userPhotoUrl; }

    get navItems() {
        const items = this.portalMode === 'landlord' ? LANDLORD_NAV_ITEMS : TENANT_NAV_ITEMS;
        return items.map(item => {
            const isActive = this.activeRoute === item.key;
            return {
                ...item,
                className: isActive ? 'ri-nav-item ri-nav-item--active' : 'ri-nav-item',
                mobileClassName: isActive ? 'ri-mobile-nav__item ri-mobile-nav__item--active' : 'ri-mobile-nav__item'
            };
        });
    }

    get portalBaseUrl() {
        return this.portalMode === 'landlord'
            ? `${BasePath}/landlord`
            : BasePath;
    }

    get currentLocation() {
        return this.currentPageRef?.attributes?.url || window.location.pathname + window.location.hash;
    }

    get activeRoute() {
        const location = (this.currentLocation || '').split('?')[0];
        const hashIndex = location.indexOf('#');
        const path = hashIndex >= 0 ? location.substring(0, hashIndex) : location;
        const hash = hashIndex >= 0 ? location.substring(hashIndex + 1) : '';
        const base = BasePath.replace(/\/$/, '');
        let relative = path;
        if (base && relative.indexOf(base) === 0) {
            relative = relative.substring(base.length);
        }
        relative = relative.replace(/^\/+/, '').replace(/\/+$/, '');
        if (this.portalMode === 'landlord') {
            if (!relative || relative === 'landlord') {
                return hash || 'overview';
            }
            if (relative.indexOf('landlord/') === 0) {
                return relative.substring('landlord/'.length);
            }
            return hash || relative;
        }
        if (!relative) {
            return 'home';
        }
        return relative.split('/').pop() || 'home';
    }

    renderedCallback() {
        if (this.hasRedirected || !this.isLoggedIn) {
            return;
        }

        const location = (this.currentLocation || '').split('?')[0];
        const base = BasePath.replace(/\/$/, '');
        const normalized = location.split('#')[0].replace(base, '').replace(/^\/+/, '').replace(/\/+$/, '');
        const isLandlordPath = normalized.indexOf('landlord') === 0;
        const shouldRedirectToLandlord = this.portalMode === 'landlord' && normalized !== 'landlord' && !isLandlordPath;
        const shouldRedirectToTenant = this.portalMode !== 'landlord' && isLandlordPath;

        if (shouldRedirectToLandlord || shouldRedirectToTenant) {
            this.hasRedirected = true;
            this._go('');
        }
    }

    _go(urlSuffix) {
        let navurl = this.portalBaseUrl;
        if (urlSuffix) {
            if (urlSuffix.charAt(0) === '#') {
                navurl = `${navurl}${urlSuffix}`;
            } else {
                navurl = `${navurl}/${urlSuffix}`;
            }
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: navurl }
        });
        this.isMobileMenuOpen = false;
    }

    handleNavClick(event) {
        this._go(event.currentTarget.dataset.target || '');
    }

    handleNavHome() {
        this._go('');
    }

    toggleDropdown() { this.isDropdownOpen = !this.isDropdownOpen; }
    closeDropdown()  { this.isDropdownOpen = false; }

    handleProfile() { this._go('profile'); }
    handleLogout()  {
        window.location.href = '/secur/logout.jsp?retUrl=' + encodeURIComponent(BasePath + '/login');
    }

    toggleMobileMenu() { this.isMobileMenuOpen = !this.isMobileMenuOpen; }
}
