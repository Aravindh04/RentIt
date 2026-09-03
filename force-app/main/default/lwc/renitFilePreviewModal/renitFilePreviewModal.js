import { LightningElement, api } from 'lwc';

export default class RenitFilePreviewModal extends LightningElement {
    @api isOpen = false;
    @api fileName = 'Document Preview';
    _versionId;

    // Setter to dynamically construct the Salesforce preview URL when the ID updates
    @api 
    get versionId() {
        return this._versionId;
    }
    set versionId(value) {
        this._versionId = value;
        if (value) {
            // Uses the standard renderStored servlet optimized for Experience Cloud rendering
            this.filePreviewUrl = `/sfc/servlet.shepherd/version/renderStored?versionId=${value}`;
        } else {
            this.filePreviewUrl = undefined;
        }
    }

    filePreviewUrl;

    // Dispatches a close event back to the parent to update the modal state
    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }
}
