import { LightningElement } from 'lwc';

/**
 * Form-agnostic branding panel reused across the auth pages that surround
 * Login (Forgot Password, Register, Check-Email, Error). Unlike
 * rentitLoginBranding, this component never nests a form inside itself —
 * it's placed as a plain sibling column next to whichever page-specific
 * component (standard or custom) lives in column 2, via the same
 * two-column CMS section pattern Login itself originally used.
 */
export default class RentitAuthBranding extends LightningElement {
    isLoading = true;

    connectedCallback() {
        // Mirrors rentitInvoiceList's loading-spinner pattern. There's no
        // remote data to fetch here, so this only spans one microtask —
        // just enough to render a consistent "content is loading" frame
        // before the panel paints.
        Promise.resolve().then(() => {
            this.isLoading = false;
        });
    }
}
