/**
 * Without-sharing data helper for portal queries where Salesforce sharing rules
 * cannot cover the required object (Contract has no supported sharing path for
 * community users). Ownership is validated in user mode before any elevated
 * query runs, so tenants can only see their own data.
 */
public without sharing class RentItPortalDataHelper {

    public static Contract getContractForTenancy(Id tenancyId) {
        // Confirm the tenancy belongs to the running user before bypassing sharing
        Integer owned = [
            SELECT COUNT(id) FROM Tenancy__c
            WHERE Id = :tenancyId
              AND Tenant__c IN (SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId())
            WITH USER_MODE
        ];
        if (owned == 0) return null;

        List<Contract> contracts = [
            SELECT Id, ContractNumber, Status, StartDate, EndDate,
                   Rent_Amount__c, Rent_Frequency__c,
                   Deposit_Amount__c, Special_Conditions__c
            FROM   Contract
            WHERE  Tenancy__c = :tenancyId
            ORDER BY StartDate DESC
            LIMIT  1
        ];
        return contracts.isEmpty() ? null : contracts[0];
    }
}
