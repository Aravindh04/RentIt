import { LightningElement } from 'lwc';

export default class RentitLoginBranding extends LightningElement {
    isLoading = true;

    connectedCallback() {
        // Mirrors rentitInvoiceList's loading-spinner pattern. There's no
        // remote data to fetch here, so this only spans one microtask —
        // just enough to render a consistent "content is loading" frame
        // before the panel and its nested login form paint.
        Promise.resolve().then(() => {
            this.isLoading = false;
        });
    }
}
