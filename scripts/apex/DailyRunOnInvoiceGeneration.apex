String jobName = 'Daily 8 AM Job';
String cronExp = '0 0 8 * * ?'; // At 8:00 AM every day
InvoiceScheduler job = new InvoiceScheduler();
System.schedule(jobName, cronExp, job);
