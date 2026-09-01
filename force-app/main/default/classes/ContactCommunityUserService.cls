public with sharing class ContactCommunityUserService {
    public class Request {
        @InvocableVariable(required=true)
        public Id contactId;
    }

    public class Result {
        @InvocableVariable
        public Id userId;

        @InvocableVariable
        public Boolean created;

        @InvocableVariable
        public String username;

        @InvocableVariable
        public String message;
    }

    private static final String COMMUNITY_PROFILE_NAME = 'Customer Community Plus User';
    private static final String USERNAME_SUFFIX = '@rentit.com.dev';

    @InvocableMethod(
        label='Create Contact Community User',
        description='Queues creation of a Customer Community Plus User for a Contact and triggers the standard welcome/password-set email.'
    )
    public static List<Result> createCommunityUsers(List<Request> requests) {
        List<Result> results = new List<Result>();
        if (requests == null || requests.isEmpty()) {
            return results;
        }

        Set<Id> contactIds = new Set<Id>();
        for (Request request : requests) {
            if (request != null && request.contactId != null) {
                contactIds.add(request.contactId);
            }
        }

        if (contactIds.isEmpty()) {
            return results;
        }

        System.enqueueJob(new ContactCommunityUserQueueable(contactIds));

        for (Request request : requests) {
            Result result = new Result();
            result.created = true;
            result.message = (request != null && request.contactId != null)
                ? 'User creation queued for Contact ' + request.contactId + '.'
                : 'User creation queued.';
            results.add(result);
        }

        return results;
    }

    public class ContactCommunityUserQueueable implements Queueable {
        private Set<Id> contactIds;

        public ContactCommunityUserQueueable(Set<Id> contactIds) {
            this.contactIds = contactIds;
        }

        public void execute(QueueableContext context) {
            Map<Id, Contact> contactsById = new Map<Id, Contact>([
                SELECT Id, FirstName, LastName, Email
                FROM Contact
                WHERE Id IN :contactIds
                WITH USER_MODE
            ]);

            if (contactsById.isEmpty()) {
                return;
            }

            Profile communityProfile = [
                SELECT Id, Name
                FROM Profile
                WHERE Name = :COMMUNITY_PROFILE_NAME
                LIMIT 1
            ];

            Map<String, Boolean> usernameTaken = new Map<String, Boolean>();
            for (User existingUser : [
                SELECT Username
                FROM User
                WHERE Username LIKE '%@rentit.com.dev'
                WITH USER_MODE
            ]) {
                usernameTaken.put(existingUser.Username.toLowerCase(), true);
            }

            List<User> usersToInsert = new List<User>();
            for (Contact contact : contactsById.values()) {
                if (contact == null || String.isBlank(contact.LastName) || String.isBlank(contact.Email)) {
                    continue;
                }

                String firstName = String.isBlank(contact.FirstName) ? '' : contact.FirstName.trim();
                String lastName = contact.LastName.trim();
                String username = firstName + '.' + lastName + USERNAME_SUFFIX;
                Integer suffix = 1;
                while (usernameTaken.containsKey(username.toLowerCase())) {
                    username = firstName + '.' + lastName + String.valueOf(suffix) + USERNAME_SUFFIX;
                    suffix++;
                }

                usernameTaken.put(username.toLowerCase(), true);
                usersToInsert.add(new User(
                    Alias = buildAlias(firstName, lastName),
                    Email = contact.Email,
                    EmailEncodingKey = 'UTF-8',
                    FirstName = firstName,
                    LastName = lastName,
                    LanguageLocaleKey = 'en_US',
                    LocaleSidKey = 'en_US',
                    TimeZoneSidKey = 'America/Los_Angeles',
                    ProfileId = communityProfile.Id,
                    ContactId = contact.Id,
                    Username = username,
                    IsActive = true,
                    CommunityNickname = buildNickname(firstName, lastName)
                ));
            }

            if (usersToInsert.isEmpty()) {
                return;
            }

            Database.SaveResult[] saveResults = Database.insert(usersToInsert, false);
            for (Database.SaveResult saveResult : saveResults) {
                if (saveResult.isSuccess()) {
                    System.resetPassword(saveResult.getId(), true);
                }
            }
        }

        private String buildAlias(String firstName, String lastName) {
            String aliasBase = String.isBlank(firstName) ? lastName : firstName.substring(0, 1) + lastName;
            String sanitized = aliasBase.replaceAll('[^a-zA-Z0-9]', '');
            return sanitized.length() > 8 ? sanitized.substring(0, 8) : sanitized;
        }

        private String buildNickname(String firstName, String lastName) {
            String baseName = String.isBlank(firstName) ? lastName : firstName + ' ' + lastName;
            String sanitized = baseName.replaceAll('[^a-zA-Z0-9 ]', '');
            sanitized = sanitized.trim();
            return sanitized.length() > 40 ? sanitized.substring(0, 40) : sanitized;
        }
    }
}
