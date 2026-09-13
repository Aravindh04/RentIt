public without sharing class ApplicationLogWrapper {
    public string source {get;set;}
    public string sourceFunction {get;set;}
    public string referenceId {get;set;}
    public string referenceInfo{get;set;}
    public string logMessage {get;set;}
    public string payload {get;set;}
    public Exception ex {get;set;}
    public string debugLevel {get;set;}
    public string logCode {get;set;}
    public long timer {get;set;}
}