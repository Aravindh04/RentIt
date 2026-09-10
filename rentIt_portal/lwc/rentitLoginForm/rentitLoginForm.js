import { LightningElement, api } from 'lwc';
import basePath from '@salesforce/community/basePath';
import login from '@salesforce/apex/RentItLoginHelper.login';

// RFC-5322-lite check: local@domain.tld — matches the "something@something.something" shape.
// Salesforce usernames are always email-shaped, so this validates both a username and an email.
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const REMEMBER_USERNAME_KEY = 'rentit_login_remember_username';
const GENERIC_LOGIN_ERROR = "We couldn't sign you in. Please check your username and password and try again.";

/**
 * Custom-styled Experience Cloud login form.
 *
 * This is an LWR ("Build Your Own") site, which has no classic Aura/VF
 * "{basePath}/login" form-POST endpoint (confirmed: that returns a "URL No
 * Longer Exists" error here). Instead, this calls RentItLoginHelper.login,
 * an @AuraEnabled Apex method that uses the platform's own `Site.login`
 * API — the documented mechanism for fully custom Experience Cloud login
 * pages. `Site.login` performs the real platform login (password policy,
 * lockout, MFA/verification challenges all still fully enforced
 * server-side) and, on success, establishes the actual session itself;
 * this component only supplies the presentation layer and client-side UX
 * (email format validation, show/hide password).
 *
 * `Site.login` only ever recognizes a Username, never an Email address —
 * RentItLoginHelper resolves Username-or-Email into the real Username
 * internally before calling it.
 */
export default class RentitLoginForm extends LightningElement {
    @api usernameLabel = 'Username or Email';
    @api passwordLabel = 'Password';
    @api loginButtonLabel = 'Log In';
    @api forgotPasswordLabel = 'Forgot your password?';
    @api forgotPasswordUrl = '/ForgotPassword';
    @api formTitle = 'Sign In';

    username = '';
    password = '';
    rememberMe = false;
    showPassword = false;
    usernameError = '';
    passwordError = '';
    loginError = '';
    isSubmitting = false;
    isLoading = true;

    connectedCallback() {
        // Mirrors rentitInvoiceList's loading-spinner pattern. There's no
        // remote data to fetch here, so this only spans one microtask —
        // just enough to render a consistent "content is loading" frame
        // before the form itself paints.
        Promise.resolve().then(() => {
            this.isLoading = false;
        });

        // "Remember me" is implemented client-side: only the username (never
        // the password) is persisted, purely as a convenience pre-fill.
        const savedUsername = window.localStorage.getItem(REMEMBER_USERNAME_KEY);
        if (savedUsername) {
            this.username = savedUsername;
            this.rememberMe = true;
        }
    }

    get startUrl() {
        const params = new URLSearchParams(window.location.search);
        return params.get('startURL') || '/';
    }

    get passwordInputType() {
        return this.showPassword ? 'text' : 'password';
    }

    get showPasswordIconName() {
        return this.showPassword ? 'utility:hide' : 'utility:preview';
    }

    get showPasswordLabel() {
        return this.showPassword ? 'Hide password' : 'Show password';
    }

    get showPasswordPressed() {
        return this.showPassword ? 'true' : 'false';
    }

    get usernameInputClass() {
        return 'ri-input' + (this.usernameError ? ' ri-input--error' : '');
    }

    get passwordInputClass() {
        return 'ri-input ri-input--password' + (this.passwordError ? ' ri-input--error' : '');
    }

    get hasLoginError() {
        return !!this.loginError;
    }

    handleUsernameInput(event) {
        this.username = event.target.value;
        if (this.usernameError) {
            this.validateUsername();
        }
    }

    handlePasswordInput(event) {
        this.password = event.target.value;
        if (this.passwordError) {
            this.validatePassword();
        }
    }

    toggleShowPassword() {
        this.showPassword = !this.showPassword;
        // Keep focus in the field after toggling so keyboard users aren't
        // dropped back to the top of the form.
        this.template.querySelector('[data-id="password"]')?.focus();
    }

    handleRememberChange(event) {
        this.rememberMe = event.target.checked;
    }

    validateUsername() {
        if (!this.username) {
            this.usernameError = 'Username or email is required.';
        } else if (!EMAIL_PATTERN.test(this.username)) {
            this.usernameError = 'Enter your username or email address, e.g. name@example.com.';
        } else {
            this.usernameError = '';
        }
        return !this.usernameError;
    }

    validatePassword() {
        this.passwordError = this.password ? '' : 'Password is required.';
        return !this.passwordError;
    }

    async handleSubmit(event) {
        // Always intercept: this authenticates via an imperative Apex call
        // (RentItLoginHelper.login → Site.login), not a native form POST.
        event.preventDefault();

        const isUsernameValid = this.validateUsername();
        const isPasswordValid = this.validatePassword();

        if (!isUsernameValid || !isPasswordValid) {
            const firstInvalidSelector = !isUsernameValid ? '[data-id="username"]' : '[data-id="password"]';
            this.template.querySelector(firstInvalidSelector)?.focus();
            return;
        }

        this.loginError = '';
        this.isSubmitting = true;

        if (this.rememberMe) {
            window.localStorage.setItem(REMEMBER_USERNAME_KEY, this.username);
        } else {
            window.localStorage.removeItem(REMEMBER_USERNAME_KEY);
        }

        try {
            const redirectUrl = await login({
                identifier: this.username,
                password: this.password,
                startUrl: this.startUrl
            });
            window.location.href = redirectUrl || `/`;
/*
            login({ identifier: this.username, password: this.password, startUrl: this.startUrl })
            .then((redirectUrl) => {
                if (redirectUrl) {
                    // Redirect the user to the portal page upon successful login
                    window.location.href = redirectUrl;
                }
            })
            .catch((error) => {
                this.loginError = error.body ? error.body.message : 'Invalid username or password.';
                this.isSubmitting = false;
            });*/
        } catch (error) {
            // error.body.message carries the AuraHandledException message
            // thrown by RentItLoginHelper.login (always the generic,
            // enumeration-safe message — never a specific system reason).
            this.loginError = error?.body?.message || GENERIC_LOGIN_ERROR;
            this.isSubmitting = false;
        }
    }
}
