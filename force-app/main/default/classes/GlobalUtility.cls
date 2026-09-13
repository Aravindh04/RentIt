/*-----------------------------------------------------------------------------------
Description:   A global utility class for common functions
Test Class:    GlobalUtility_Test
-----------------------------------------------------------------------------------*/
public without sharing class GlobalUtility {

    /*-----------------------------------------------------------------------------------
    Description:   Method to create a single application log record
                   logLevel - Debug, Error, Info, Warning
                   sourceClass - Originating trigger or utility class
                   sourceFunction - Method in class above that caused the message
                   referneceId - Process Identifier (e.g. Job Id)
                   referenceInfo - Process information
                   payLoad - Optional based on integration messages
                   ex - the standard exception object for errors
                   timeTaken - The time in milliseconds of the transaction
    Param:         As described in description.
    -----------------------------------------------------------------------------------*/
    public static void logMessage(String logLevel,
                                    String sourceClass,
                                    String sourceFunction,
                                    String referenceId,
                                    String referenceInfo,
                                    String payLoad,
                                    Exception ex,
                                    long timeTaken) {

        ApplicationLogWrapper msg = new ApplicationLogWrapper();
        
        msg.source = sourceClass;
        msg.sourceFunction = sourceFunction;
        msg.referenceId = referenceId;
        msg.referenceInfo = referenceInfo;
        msg.payload = payLoad;
        msg.debugLevel = logLevel;
        msg.ex = ex;
        msg.Timer = timeTaken;
        logMessages(new list <ApplicationLogWrapper> {msg});
    }    

    /*-----------------------------------------------------------------------------------
    Description:   Method to create application log records in salesforce
    Param:         list of ApplicationLogWrapper objets with logging information   
    -----------------------------------------------------------------------------------*/
    public static void logMessages(list <ApplicationLogWrapper> messages) {
        if(messages.size() == 0) return;
        
        list <ApplicationLog__c> logs = new list <ApplicationLog__c>();
        
        for(ApplicationLogWrapper message : messages) {
            ApplicationLog__c applicationLogRecord = new ApplicationLog__c();
        
            applicationLogRecord.Source__c = message.source;
            applicationLogRecord.Source_Function__c = message.sourceFunction;
            applicationLogRecord.Reference_Id__c = message.referenceId;
            applicationLogRecord.Reference_Info__c = message.referenceInfo;
            applicationLogRecord.Integration_Payload__c = message.payload;
        
            if(message.ex != null){
                applicationLogRecord.Stack_Trace__c = message.ex.getStackTraceString();
                applicationLogRecord.Message__c = message.ex.getMessage();
            }
            
            applicationLogRecord.Debug_Level__c = message.debugLevel;
            applicationLogRecord.Log_Code__c = message.logCode;
            applicationLogRecord.Timer__c = message.timer;
            logs.add(applicationLogRecord);
        }

        if(logs.size() > 0)
            insert logs;
    }
    
}