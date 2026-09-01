import { LightningElement } from 'lwc';

export default class RentitSupportHub extends LightningElement {
    activeTab = 'complaint';

    get isComplaint()    { return this.activeTab === 'complaint'; }
    get isMaintenance()  { return this.activeTab === 'maintenance'; }

    get tabComplaint() {
        return 'ri-support-tab' + (this.isComplaint ? ' ri-support-tab--active' : '');
    }
    get tabMaintenance() {
        return 'ri-support-tab' + (this.isMaintenance ? ' ri-support-tab--active' : '');
    }

    handleTabComplaint()   { this.activeTab = 'complaint'; }
    handleTabMaintenance() { this.activeTab = 'maintenance'; }
}
