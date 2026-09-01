import { LightningElement, wire, track } from 'lwc';
import getPortfolioSummary from '@salesforce/apex/RentItPortalController.getPortfolioSummary';

export default class RentitLandlordDashboard extends LightningElement {
    @track summary;
    @track error;
    isLoading = true;

    @wire(getPortfolioSummary)
    wiredSummary({ data, error }) {
        if (data) {
            this.summary = data;
            this.isLoading = false;
        } else if (error) {
            // A tenant user hitting this component gets an insufficient access error;
            // treat that as a non-error (landlord page only).
            const msg = error?.body?.message || '';
            if (!msg.toLowerCase().includes('insufficient')) {
                this.error = msg || 'Failed to load dashboard.';
            }
            this.isLoading = false;
        }
    }
}