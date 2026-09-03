String contractNumber = 'REPLACE_WITH_CONTRACT_NUMBER';

if (String.isBlank(contractNumber) || contractNumber == 'REPLACE_WITH_CONTRACT_NUMBER') {
    throw new IllegalArgumentException('Set contractNumber before running this script.');
}

List<Contract> contracts = ContractAttachmentSharingSelector.selectByContractNumber(contractNumber);

if (contracts.isEmpty()) {
    throw new IllegalArgumentException('No Contract was found for Contract Number: ' + contractNumber);
}

Contract contractRecord = contracts[0];
if (contractRecord.CustomerSignedId == null) {
    throw new IllegalArgumentException(
        'The Contract has no Customer Signed contact: ' + contractRecord.ContractNumber
    );
}

ContractAttachmentSharingService.shareContractAttachments(contracts);