// Replace with the actual Invoice__c record Id you want to update.
Invoice__c[] invoiceToUpdate = new List<Invoice__c>();
for(Invoice__c invoice : [
    SELECT Id, Amount__c, Total_Paid__c, Status__c, Total_Amount__c
    FROM Invoice__c WHERE Status__c = 'Paid' AND Total_Paid__c = 0
]) {
    invoice.Total_Paid__c = invoice.Total_Amount__c;
    invoiceToUpdate.add(invoice);
}

if (!invoiceToUpdate.isEmpty()) {
    update invoiceToUpdate;
}
