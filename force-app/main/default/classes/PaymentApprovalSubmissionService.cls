/**
 * Submits tenant payments to the landlord approval process.
 */
public with sharing class PaymentApprovalSubmissionService {
    private static final String APPROVAL_PROCESS_NAME = 'Rent_Payment_Approval';

    /**
     * Identifies a payment and its landlord approver.
     */
    public class SubmissionRequest {
        @InvocableVariable(required=true)
        public Id paymentId;

        @InvocableVariable(required=true)
        public Id approverId;
    }

    /**
     * Submits each payment to the configured approval process in bulk.
     */
    @InvocableMethod(
        label='Submit Payment for Landlord Approval'
        description='Submits Payment records to the Rent Payment Approval process and assigns each payment to its landlord User.'
    )
    public static void submitPayments(List<SubmissionRequest> requests) {
        List<Approval.ProcessRequest> processRequests = new List<Approval.ProcessRequest>();

        for (SubmissionRequest request : requests) {
            if (request == null || request.paymentId == null || request.approverId == null) {
                throw new SubmissionException('Payment Id and landlord approver Id are required.');
            }

            Approval.ProcessSubmitRequest processRequest = new Approval.ProcessSubmitRequest();
            processRequest.setObjectId(request.paymentId);
            processRequest.setProcessDefinitionNameOrId(APPROVAL_PROCESS_NAME);
            processRequest.setComments('Payment submitted automatically for landlord approval.');
            processRequest.setNextApproverIds(new List<Id>{request.approverId});
            processRequests.add(processRequest);
        }

        if (!processRequests.isEmpty()) {
            Approval.process(processRequests);
        }
    }

    /**
     * Indicates that a submission request is incomplete.
     */
    public class SubmissionException extends Exception {
    }
}
