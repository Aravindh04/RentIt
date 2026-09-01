import { LightningElement } from 'lwc';

export default class RentitPaymentHub extends LightningElement {
    activeTab = 'make';

    get isMakePayment() { return this.activeTab === 'make'; }
    get isHistory()     { return this.activeTab === 'history'; }

    get tabMakePayment() {
        return 'ri-payment-tab' + (this.isMakePayment ? ' ri-payment-tab--active' : '');
    }
    get tabHistory() {
        return 'ri-payment-tab' + (this.isHistory ? ' ri-payment-tab--active' : '');
    }

    handleTabMakePayment() { this.activeTab = 'make'; }
    handleTabHistory()     { this.activeTab = 'history'; }
}
