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

const FIELDS = [USER_NAME, USER_FIRSTNAME, USER_EMAIL, USER_PHOTO];

export default class RentitHeader extends NavigationMixin(LightningElement) {
    isDropdownOpen   = false;
    isMobileMenuOpen = false;

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
    get userInitial()  { return this.userName ? this.userName.charAt(0).toUpperCase() : '?'; }
    get hasPhoto()     { return !!this.userPhotoUrl; }

    // ── Active route detection ────────────────────────────────────
    get activeRoute() {
        const url = this.currentPageRef?.attributes?.url || window.location.pathname;
        const parts = (url || '').split('/').filter(Boolean);
        return parts[parts.length - 1] || '';
    }

    // Desktop nav classes
    get navMyTenancy() { return this._navClass('my-tenancy'); }
    get navInvoices()  { return this._navClass('invoices'); }
    get navPayments()  { return this._navClass('payments'); }
    get navNotices()   { return this._navClass('notices'); }
    get navSupport()   { return this._navClass('support'); }

    _navClass(route) {
        return 'ri-nav-item' + (this.activeRoute === route ? ' ri-nav-item--active' : '');
    }

    // Mobile nav classes
    get mobileNavMyTenancy() { return this._mobileClass('my-tenancy'); }
    get mobileNavInvoices()  { return this._mobileClass('invoices'); }
    get mobileNavPayments()  { return this._mobileClass('payments'); }
    get mobileNavNotices()   { return this._mobileClass('notices'); }
    get mobileNavSupport()   { return this._mobileClass('support'); }

    _mobileClass(route) {
        return 'ri-mobile-nav__item' + (this.activeRoute === route ? ' ri-mobile-nav__item--active' : '');
    }

    // ── Navigation ────────────────────────────────────────────────
    _go(urlSuffix) {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: `${BasePath}/${urlSuffix}` }
        });
        this.isMobileMenuOpen = false;
    }

    handleNavHome()      { this._go('home'); }
    handleNavMyTenancy() { this._go('my-tenancy'); }
    handleNavInvoices()  { this._go('invoices'); }
    handleNavPayments()  { this._go('payments'); }
    handleNavNotices()   { this._go('notices'); }
    handleNavSupport()   { this._go('support'); }

    // ── Dropdown ──────────────────────────────────────────────────
    toggleDropdown() { this.isDropdownOpen = !this.isDropdownOpen; }
    closeDropdown()  { this.isDropdownOpen = false; }

    handleProfile() { this._go('profile'); }
    handleLogout()  {
        window.location.href = '/secur/logout.jsp?retUrl=' + encodeURIComponent(BasePath + '/login');
    }

    // ── Mobile menu ───────────────────────────────────────────────
    toggleMobileMenu() { this.isMobileMenuOpen = !this.isMobileMenuOpen; }
}
