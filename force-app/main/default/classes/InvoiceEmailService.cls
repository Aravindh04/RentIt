/**
 * Sends the branded "Invoice Paid" receipt email to a tenant once their Invoice__c is fully paid,
 * attaching a PDF copy of the invoice receipt (rendered from the InvoiceReceiptPdf Visualforce page).
 *
 * Invoked from InvoiceTriggerService when an Invoice__c transitions to Status__c = 'Paid'. The actual
 * query/PDF-render/send work is deferred to a Queueable so it never runs inside a trigger's call stack
 * (PageReference.getContentAsPDF() is not supported from within a trigger context).
 */
public with sharing class InvoiceEmailService {

    private static final String NOTIFICATIONS_FOLDER = 'RentIt_Notifications';
    private static final String INVOICE_PAID_TEMPLATE = 'InvoicePaid';
    private static final String ATTACHMENT_FILE_NAME = 'Invoice-Receipt.pdf';

    /**
     * Number of "Invoice Paid" emails successfully handed to Messaging.sendEmail by the most recently
     * executed Queueable. Governor-limit counters (e.g. Limits.getEmailInvocations()) don't carry over
     * from an async Queueable execution back to the enqueuing test method, so tests assert on this
     * TestVisible counter instead to confirm the send was attempted.
     */
    @TestVisible
    private static Integer lastEmailsSentCount = 0;

    /**
     * Queues the "Invoice Paid" receipt email (with PDF attachment) for each Invoice__c Id supplied.
     * Safe to call with an empty or null set.
     */
    public static void sendInvoicePaidReceipts(Set<Id> invoiceIds) {
        if (invoiceIds == null || invoiceIds.isEmpty()) {
            return;
        }

        System.enqueueJob(new InvoicePaidReceiptQueueable(new List<Id>(invoiceIds)));
    }

    /** Bulk-safe Queueable that renders and sends the Invoice Paid receipt emails for a set of invoices. */
    public class InvoicePaidReceiptQueueable implements Queueable, Database.AllowsCallouts {
        private List<Id> invoiceIds;

        public InvoicePaidReceiptQueueable(List<Id> invoiceIds) {
            this.invoiceIds = invoiceIds;
        }

        public void execute(QueueableContext context) {
            if (invoiceIds == null || invoiceIds.isEmpty()) {
                return;
            }

            Id templateId = getInvoicePaidTemplateId();
            if (templateId == null) {
                return;
            }

            Map<Id, Invoice__c> invoicesById = new Map<Id, Invoice__c>([
                SELECT Id, Tenancy__r.Tenant__c, Tenancy__r.Tenant__r.Email
                FROM Invoice__c
                WHERE Id IN :invoiceIds
            ]);

            List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();

            for (Id invoiceId : invoiceIds) {
                Invoice__c invoiceRecord = invoicesById.get(invoiceId);
                Id tenantContactId = invoiceRecord?.Tenancy__r?.Tenant__c;
                String tenantEmail = invoiceRecord?.Tenancy__r?.Tenant__r?.Email;

                Boolean canSend = invoiceRecord != null && tenantContactId != null && String.isNotBlank(tenantEmail);
                if (!canSend) {
                    continue;
                }

                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setTemplateId(templateId);
                email.setTargetObjectId(tenantContactId);
                email.setWhatId(invoiceRecord.Id);
                email.setSaveAsActivity(false);

                Messaging.EmailFileAttachment pdfAttachment = buildInvoicePdfAttachment(invoiceRecord.Id);
                if (pdfAttachment != null) {
                    email.setFileAttachments(new List<Messaging.EmailFileAttachment>{ pdfAttachment });
                }

                emailsToSend.add(email);
            }

            if (!emailsToSend.isEmpty()) {
                Messaging.sendEmail(emailsToSend, false);
                lastEmailsSentCount = emailsToSend.size();
            }
        }

        private Id getInvoicePaidTemplateId() {
            List<EmailTemplate> templates = [
                SELECT Id
                FROM EmailTemplate
                WHERE DeveloperName = :INVOICE_PAID_TEMPLATE
                AND Folder.DeveloperName = :NOTIFICATIONS_FOLDER
                LIMIT 1
            ];
            return templates.isEmpty() ? null : templates[0].Id;
        }

        private Messaging.EmailFileAttachment buildInvoicePdfAttachment(Id invoiceId) {
            Blob pdfBlob;
            if (Test.isRunningTest()) {
                pdfBlob = Blob.valueOf('Test invoice receipt PDF content');
            } else {
                PageReference pdfPage = Page.InvoiceReceiptPdf;
                pdfPage.getParameters().put('id', invoiceId);
                pdfBlob = pdfPage.getContentAsPDF();
            }

            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
            attachment.setFileName(ATTACHMENT_FILE_NAME);
            attachment.setBody(pdfBlob);
            attachment.setContentType('application/pdf');
            return attachment;
        }
    }
}
