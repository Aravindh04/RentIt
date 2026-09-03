public with sharing class ContractAttachmentSharingService {
    private static final String MIGRATION_MARKER_PREFIX = 'Migrated from Attachment: ';
    private static final String FILE_SHARE_TYPE = 'V';
    private static final String FILE_VISIBILITY = 'AllUsers';

    private ContractAttachmentSharingService() {
    }

    public static void shareContractAttachments(List<Contract> contracts) {
        if (contracts == null || contracts.isEmpty()) {
            return;
        }

        Map<Id, Id> contactIdByContractId = getContactIdByContractId(contracts);
        if (contactIdByContractId.isEmpty()) {
            return;
        }

        Map<Id, Set<Id>> userIdsByContactId = getPortalUserIdsByContactId(
            new Set<Id>(contactIdByContractId.values())
        );
        if (userIdsByContactId.isEmpty()) {
            return;
        }

        List<Attachment> attachments = ContractAttachmentSharingSelector.selectAttachmentsByContractIds(
            contactIdByContractId.keySet()
        );
        createFilesFromAttachments(attachments);
        shareFilesWithPortalUsers(contactIdByContractId, userIdsByContactId);
    }

    private static Map<Id, Id> getContactIdByContractId(List<Contract> contracts) {
        Map<Id, Id> contactIdByContractId = new Map<Id, Id>();
        for (Contract contractRecord : contracts) {
            if (contractRecord.CustomerSignedId != null) {
                contactIdByContractId.put(contractRecord.Id, contractRecord.CustomerSignedId);
            }
        }
        return contactIdByContractId;
    }

    private static void createFilesFromAttachments(List<Attachment> attachments) {
        if (attachments.isEmpty()) {
            return;
        }

        Set<String> migrationMarkers = new Set<String>();
        for (Attachment attachment : attachments) {
            migrationMarkers.add(buildMigrationMarker(attachment.Id));
        }

        Set<String> migratedMarkers = new Set<String>();
        for (ContentVersion contentVersion : ContractAttachmentSharingSelector.selectVersionsByDescriptions(
            migrationMarkers
        )) {
            migratedMarkers.add(contentVersion.Description);
        }

        List<Attachment> attachmentsToMigrate = new List<Attachment>();
        List<ContentVersion> contentVersions = new List<ContentVersion>();
        for (Attachment attachment : attachments) {
            String migrationMarker = buildMigrationMarker(attachment.Id);
            if (!migratedMarkers.contains(migrationMarker)) {
                attachmentsToMigrate.add(attachment);
                contentVersions.add(new ContentVersion(
                    Title = attachment.Name,
                    PathOnClient = attachment.Name,
                    VersionData = attachment.Body,
                    Description = migrationMarker,
                    ContentLocation = 'S',
                    FirstPublishLocationId = attachment.ParentId
                ));
            }
        }
        if (contentVersions.isEmpty()) {
            return;
        }

        Database.SaveResult[] results = Database.insert(contentVersions, false, AccessLevel.USER_MODE);
        for (Integer index = 0; index < results.size(); index++) {
            Database.SaveResult result = results[index];
            if (!result.isSuccess()) {
                logErrors(result, 'Could not create File for Attachment ' + attachmentsToMigrate[index].Id + ': ');
            }
        }
    }

    private static Map<Id, Set<Id>> getPortalUserIdsByContactId(Set<Id> contactIds) {
        Map<Id, Set<Id>> userIdsByContactId = new Map<Id, Set<Id>>();
        for (User portalUser : ContractAttachmentSharingSelector.selectPortalUsersByContactIds(contactIds)) {
            if (!userIdsByContactId.containsKey(portalUser.ContactId)) {
                userIdsByContactId.put(portalUser.ContactId, new Set<Id>());
            }
            userIdsByContactId.get(portalUser.ContactId).add(portalUser.Id);
        }
        return userIdsByContactId;
    }

    private static void shareFilesWithPortalUsers(
        Map<Id, Id> contactIdByContractId,
        Map<Id, Set<Id>> userIdsByContactId
    ) {
        Set<Id> entityIds = new Set<Id>(contactIdByContractId.keySet());
        entityIds.addAll(contactIdByContractId.values());
        for (Set<Id> userIds : userIdsByContactId.values()) {
            entityIds.addAll(userIds);
        }

        Set<String> existingUserLinkKeys = new Set<String>();
        Map<Id, Set<Id>> documentIdsByContractId = new Map<Id, Set<Id>>();
        Set<Id> portalUserIds = new Set<Id>();
        for (Set<Id> userIds : userIdsByContactId.values()) {
            portalUserIds.addAll(userIds);
        }

        for (ContentDocumentLink fileLink : ContractAttachmentSharingSelector.selectLinksByEntityIds(entityIds)) {
            if (contactIdByContractId.containsKey(fileLink.LinkedEntityId)) {
                if (!documentIdsByContractId.containsKey(fileLink.LinkedEntityId)) {
                    documentIdsByContractId.put(fileLink.LinkedEntityId, new Set<Id>());
                }
                documentIdsByContractId.get(fileLink.LinkedEntityId).add(fileLink.ContentDocumentId);
            } else if (portalUserIds.contains(fileLink.LinkedEntityId)) {
                existingUserLinkKeys.add(buildLinkKey(fileLink.ContentDocumentId, fileLink.LinkedEntityId));
            }
        }

        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        for (Id contractId : documentIdsByContractId.keySet()) {
            Id contactId = contactIdByContractId.get(contractId);
            for (Id contentDocumentId : documentIdsByContractId.get(contractId)) {
                for (Id portalUserId : userIdsByContactId.get(contactId)) {
                    addLinkIfMissing(links, existingUserLinkKeys, contentDocumentId, portalUserId);
                }
            }
        }

        insertLinks(links);
    }

    private static void addLinkIfMissing(
        List<ContentDocumentLink> links,
        Set<String> existingUserLinkKeys,
        Id contentDocumentId,
        Id userId
    ) {
        String linkKey = buildLinkKey(contentDocumentId, userId);
        if (!existingUserLinkKeys.contains(linkKey)) {
            links.add(new ContentDocumentLink(
                ContentDocumentId = contentDocumentId,
                LinkedEntityId = userId,
                ShareType = FILE_SHARE_TYPE,
                Visibility = FILE_VISIBILITY
            ));
            existingUserLinkKeys.add(linkKey);
        }
    }

    private static void insertLinks(List<ContentDocumentLink> links) {
        if (links.isEmpty()) {
            return;
        }

        for (Database.SaveResult result : Database.insert(links, false, AccessLevel.USER_MODE)) {
            if (!result.isSuccess()) {
                logErrors(result, 'Could not share File with portal User: ');
            }

            if (result.isSuccess()) {
                System.debug(LoggingLevel.INFO, 'Successfully shared File with portal User: ' + result.getId());
            }
        }
    }

    private static String buildMigrationMarker(Id attachmentId) {
        return MIGRATION_MARKER_PREFIX + attachmentId;
    }

    private static String buildLinkKey(Id contentDocumentId, Id contactId) {
        return String.valueOf(contentDocumentId) + ':' + String.valueOf(contactId);
    }

    private static void logErrors(Database.SaveResult result, String messagePrefix) {
        for (Database.Error error : result.getErrors()) {
            System.debug(LoggingLevel.ERROR, messagePrefix + error.getMessage());
        }
    }
}
