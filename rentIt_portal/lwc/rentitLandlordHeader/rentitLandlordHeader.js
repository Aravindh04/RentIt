import { LightningElement, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import userId from '@salesforce/user/Id';
import isGuest from '@salesforce/user/isGuest';
import BasePath from '@salesforce/community/basePath';
import USER_NAME  from '@salesforce/schema/User.Name';
import USER_EMAIL from '@salesforce/schema/User.Email';
import USER_PHOTO from '@salesforce/schema/User.SmallPhotoUrl';

const FIELDS = [USER_NAME, USER_EMAIL, USER_PHOTO];

export default class RentitLandlordHeader extends NavigationMixin(LightningElement) {
    isDropdownOpen = false;
    isMobileMenuOpen = false;

    @wire(getRecord, { recordId: userId, fields: FIELDS })
    currentUser;

    @wire(CurrentPageReference)
    currentPageRef;

    get isLoggedIn()   { return !isGuest; }
    get loginUrl()     { return `${BasePath}/login`; }
    get userName()     { return getFieldValue(this.currentUser.data, USER_NAME)  || ''; }
    get userEmail()    { return getFieldValue(this.currentUser.data, USER_EMAIL) || ''; }
    get userPhotoUrl() { return getFieldValue(this.currentUser.data, USER_PHOTO); }
    get hasPhoto()     { return !!this.userPhotoUrl; }
    get userInitial()  { return this.userName ? this.userName.charAt(0).toUpperCase() : '?'; }

    // ── Active route detection ────────────────────────────────────
    get activeRoute() {
        const url = this.currentPageRef?.attributes?.url || window.location.pathname;
        const parts = (url || '').split('/').filter(Boolean);
        const last = parts[parts.length - 1] || '';
        return last.split('?')[0];
    }

    get navDashboard()  { return this._navClass('landlord'); }
    get navProperties() { return this._navClass('landlord-properties'); }
    get navApprovals()  { return this._navClass('landlord-approvals'); }
    get navRequests()   { return this._navClass('landlord-support'); }

    _navClass(route) {
        return 'ri-nav-item' + (this.activeRoute === route ? ' ri-nav-item--active' : '');
    }

    get mobileNavDashboard()  { return this._mobileClass('landlord'); }
    get mobileNavProperties() { return this._mobileClass('landlord-properties'); }
    get mobileNavApprovals()  { return this._mobileClass('landlord-approvals'); }
    get mobileNavRequests()   { return this._mobileClass('landlord-support'); }

    _mobileClass(route) {
        return 'ri-mobile-nav__item' + (this.activeRoute === route ? ' ri-mobile-nav__item--active' : '');
    }

    // ── Navigation ────────────────────────────────────────────────
    _go(suffix) {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: suffix ? `${BasePath}/${suffix}` : BasePath }
        });
        this.isMobileMenuOpen = false;
        this.isDropdownOpen = false;
    }

    handleNavDashboard()  { this._go('landlord'); }
    handleNavProperties() { this._go('landlord-properties'); }
    handleNavApprovals()  { this._go('landlord-approvals'); }
    handleNavRequests()   { this._go('landlord-support'); }

    toggleDropdown()  { this.isDropdownOpen = !this.isDropdownOpen; }
    closeDropdown()   { this.isDropdownOpen = false; }
    toggleMobileMenu(){ this.isMobileMenuOpen = !this.isMobileMenuOpen; }

    handleLogout() {
        // retUrl must be fully qualified or logout.jsp falls back to the
        // standard employee login page instead of the RentIt community login.
        const absoluteLoginUrl = window.location.origin + BasePath + '/login';
        const logoutUrl = `${BasePath}/secur/logout.jsp?retUrl=${encodeURIComponent(absoluteLoginUrl)}`;
        window.location.assign(logoutUrl);
    }
}
