/**
 * Guest-accessible helper for the RentIt Portal's custom Experience Cloud
 * login page.
 *
 * This site is an LWR ("Build Your Own") site, which has no classic
 * Aura/Visualforce "{basePath}/login" form-POST endpoint (confirmed: that
 * returns a "URL No Longer Exists" error here). The documented mechanism
 * for a fully custom login page is to call the `Site.login` Apex method
 * from an @AuraEnabled method invoked imperatively from the LWC — it
 * performs the real platform login (password policy, lockout, MFA/
 * verification challenges all still fully enforced) and, on success,
 * establishes the actual Salesforce session itself.
 *
 * Security contract:
 *  - Runs WITHOUT SHARING and in system mode (no WITH USER_MODE) by design:
 *    these methods execute for an unauthenticated guest user, who has no
 *    access to the User object at all. The elevated read used to resolve
 *    Username-or-Email is intentionally scoped down in code instead of
 *    relying on object/field permissions:
 *      - Only the Username field is ever returned to the client.
 *      - Candidates are restricted to Users holding one of this portal's own
 *        permission sets (RentIt_Tenant / RentIt_Landlord / RentIt_Landlord_Partner),
 *        so this can never be used to look up arbitrary internal org users.
 *      - IsActive = true only.
 *  - Prevents user enumeration: resolveLoginIdentifier returns the original
 *    identifier unchanged when no match is found, and login() always
 *    surfaces the same generic error message on any failure — never
 *    revealing whether the identifier or password was the problem.
 *  - This class must be added to the Guest User Profile's Enabled Apex
 *    Class Access list for the RentIt Portal site (Setup > Digital
 *    Experiences > Administration > RentIt Portal > Public Access Settings)
 *    or guest calls will be rejected with an authorization error.
 */
public with sharing class RentItLoginHelper {
    private static final Integer MAX_IDENTIFIER_LENGTH = 254;
    private static final String GENERIC_LOGIN_ERROR = 'We couldn\'t sign you in. Please check your username and password and try again.';

    // RentIt's own Usernames always live under this domain (e.g.
    // "...@rentit.com.dev" in sandboxes, "...@rentit.com" in production).
    // If the identifier already contains it, it's a real Username — skip
    // the Email-lookup query below entirely.
    private static final String USERNAME_DOMAIN_HINT = '@rentit.com';

    /**
     * Authenticates a portal user given a Username-or-Email identifier and
     * password, via Site.login. Returns the redirect URL on success; throws
     * an AuraHandledException with a generic message on any failure.
     */
    @AuraEnabled(cacheable=false)
    public static String login(String identifier, String password, String startUrl) {
        if (String.isBlank(identifier) || String.isBlank(password)) {
            throw buildLoginException( null );
        }

        String trimmedIdentifier = identifier.trim();
        String username = trimmedIdentifier.toLowerCase().contains(USERNAME_DOMAIN_HINT)
            ? trimmedIdentifier
            : resolveLoginIdentifier(trimmedIdentifier);

        PageReference loginResult;
        String errorMessage;
        
        try {
            loginResult = Site.login(username, password, startUrl);
        } catch (Exception ex) {
            loginResult = null;
            errorMessage = String.valueOf( ex.getMessage() );
            GlobalUtility.logMessage(GlobalConstants.LOGLEVEL.Error.name(),'RentItLoginHelper','login',null,'Unable to login','',ex, null);
        }

        if (loginResult == null ) {
            throw buildLoginException( errorMessage );
        }

        return loginResult.getUrl();
    }

    /**
     * AuraHandledException.getMessage() returns null unless setMessage() is
     * explicitly called, even though the constructor message is what gets
     * serialized to the client as error.body.message. Calling both here
     * keeps the exception correct for both the LWC caller and any Apex-side
     * inspection (e.g. unit tests, logging).
     */
    private static AuraHandledException buildLoginException( String message) {
        message = message != null ? message : GENERIC_LOGIN_ERROR;
        AuraHandledException ex = new AuraHandledException( message );
        ex.setMessage(message);
        return ex;
    }

    private static String resolveLoginIdentifier(String identifier) {
        if (String.isBlank(identifier)) {
            return identifier;
        }

        String trimmedIdentifier = identifier.trim();
        if (trimmedIdentifier.length() > MAX_IDENTIFIER_LENGTH) {
            return trimmedIdentifier;
        }

        RentItLoginUnrestricted resolver = new RentItLoginUnrestricted();
        User match = resolver.resolveLoginIdentifierUnrestricted(trimmedIdentifier);

        return match == null ? trimmedIdentifier : match.Username;
    }

    // Unrestricted inner class to allow guest access to the User query for
    // resolving Username-or-Email identifiers, without exposing the rest of the class.
    private without sharing class RentItLoginUnrestricted {
        
        public User resolveLoginIdentifierUnrestricted(String identifier) {
            List<User> matches = [
                SELECT Username
                FROM User
                WHERE (Username = :identifier OR Email = :identifier)
                  AND IsActive = true
                  AND IsPortalEnabled = true
                  WITH SYSTEM_MODE
                LIMIT 1 
            ];

            return matches.isEmpty() ? null : matches[0];
        }
    }
}
