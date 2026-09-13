public without sharing class NotificationService {

    private

    /**
     * Sends a custom notification to a portal user when their payment is approved.
     * @param paymentId The ID of the approved Payment record.
     * @param portalUserId The Salesforce User ID of the portal user.
     */
    public static void sendPaymentApprovedNotification(Set<Id> paymentId, Set<Id> portalUserId) {
        
        // 1. Fetch the Custom Notification Type ID by its Developer Name
        CustomNotificationType notificationType = [
            SELECT Id, DeveloperName 
            FROM CustomNotificationType 
            WHERE DeveloperName = 'RentIt_Alerts' 
            LIMIT 1
        ];
        
        if (notificationType == null) {
            GlobalLogger.logError('NotificationService.sendPaymentApprovedNotification', 'Custom Notification Type not found.', null);
            return;
        }

        // 2. Instantiate a new Custom Notification object
        Messaging.CustomNotification notification = new Messaging.CustomNotification();

        // 3. Configure notification content and settings
        notification.setNotificationTypeId(notificationType.Id);
        notification.setTitle('Payment Approved! 🎉');
        notification.setBody('Good news! Your payment has been successfully processed and approved.');
        
        // Target ID redirects the portal user to the payment record when clicked
        notification.setTargetId(paymentId);

        // 4. Create the recipient user ID set (Requires a Set of Strings)
        Set<String> recipientIds = new Set<String>{ (String)portalUserId };

        // 5. Send the notification inside a try-catch block to handle transmission failures
        try {
            notification.send(recipientIds);
            
        } catch (Exception e) {
            GlobalLogger.logError('NotificationService.sendPaymentApprovedNotification', 'Failed to send notification for Payment ID: ' + paymentId + ' to User ID: ' + portalUserId, e);
        }
    }


}
