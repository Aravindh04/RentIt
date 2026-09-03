List<ContentDocument> unlinkedDocs = new List<ContentDocument>();

// Fetch documents (ensure user running this has 'Query All Files' permission if checking org-wide)
for (ContentDocument doc : [SELECT Id, Title, OwnerId FROM ContentDocument]) {
    List<ContentDocumentLink> links = [
        SELECT LinkedEntityId 
        FROM ContentDocumentLink 
        WHERE ContentDocumentId = :doc.Id
    ];
    
    Boolean linkedToRecordOnlyUser = true;
    
    if (links.isEmpty()) {
        linkedToRecordOnlyUser = false; // Or true depending on if 0 links counts as unlinked
    } else {
        for (ContentDocumentLink link : links) {
            String entityId = String.valueOf(link.LinkedEntityId);
            // Check if the linked entity is NOT a User (User IDs start with '005')
            if (!entityId.startsWith('005')) {
                linkedToRecordOnlyUser = false;
                break;
            }
        }
    }
    
    if (linkedToRecordOnlyUser) {
        unlinkedDocs.add(doc);
        System.debug('Unlinked/User-only Doc: ' + doc.Id + ' - ' + doc.Title);
    }
}

System.debug('Total count: ' + unlinkedDocs.size());
