Id documentId = '069fj00000FgN9FAAV'; // Your file
Id userId = '005fj00000MmgBZAAZ';    // The Portal

ContentDocumentLink cdl = new ContentDocumentLink();
cdl.ContentDocumentId = documentId; // Your file's ContentDocumentId
cdl.LinkedEntityId = userId;    // The Portal User's ID or related record ID
cdl.ShareType = 'V';                       // 'V' for Viewer access
cdl.Visibility = 'AllUsers';               // Required to expose to portal/external users
insert cdl;
