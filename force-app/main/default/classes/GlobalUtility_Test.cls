/*-----------------------------------------------------------------------------------
Description:   Test class for Global Utility       
-----------------------------------------------------------------------------------*/
@isTest
private with sharing class GlobalUtility_Test {
    @isTest
    static void logMessage_Test() {
        Test.startTest();
        GlobalUtility.logMessage(GlobalConstants.LOGLEVEL.Error.name(),
                                     'ScheduledMonthlyNotificationToProvider',
                                     'global void execute(SchedulableContext sc)',
                                     '89479828',
                                     'Scheduled Job To Send Montly Notification To Providers with Data Template',
                                     '',
                                     NULL,
                                     NULL);
        Test.stopTest();
        List<ApplicationLog__c> logs = [Select Id From ApplicationLog__c];
        system.assertEquals(1, logs.size());
    }

    @isTest
    static void globalConstantsTest() {
        //Only Coverage purpose
        System.assertEquals('Error', GlobalConstants.LOGLEVEL.Error.name());
        System.assertEquals('Info', GlobalConstants.LOGLEVEL.Info.name());
        System.assertEquals('Warning', GlobalConstants.LOGLEVEL.Warning.name());
        System.assertEquals('Debug', GlobalConstants.LOGLEVEL.Debug.name());
    }
}