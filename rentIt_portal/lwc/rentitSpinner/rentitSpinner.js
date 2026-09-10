import { LightningElement, api } from 'lwc';

/**
 * Single source of truth for the portal's loading spinner, so every
 * component shows the exact same size/animation/timing while loading.
 * Reuse this instead of hand-rolling a new `.ri-spinner` per component.
 *
 * Usage:
 *   <template lwc:if={isLoading}>
 *       <c-rentit-spinner></c-rentit-spinner>
 *   </template>
 *
 * On a dark background (e.g. the login pages' brand-gradient panels),
 * pass variant="inverse" to render a white spinner instead of the
 * default brand-blue-on-light-gray one.
 */
export default class RentitSpinner extends LightningElement {
    @api variant = 'default'; // 'default' | 'inverse'
    @api label = '';
    @api size = 'medium'; // 'small' | 'medium' | 'large'

    get wrapClass() {
        return `ri-spinner-wrap ri-spinner-wrap--${this.size}`;
    }

    get spinnerClass() {
        return `ri-spinner ri-spinner--${this.variant}`;
    }
}
