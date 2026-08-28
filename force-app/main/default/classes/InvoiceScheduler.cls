public class InvoiceScheduler implements Schedulable {

    public static final String DAILY_2AM = '0 0 2 * * ?';
    private static final String JOB_NAME = 'RentIt - Daily Invoice Generator';

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new InvoiceBatch(), 50);
    }

    public static void scheduleDaily() {
        System.schedule(JOB_NAME, DAILY_2AM, new InvoiceScheduler());
    }
}
