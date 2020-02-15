/*** 
 * This batch job sets the DaysUntilCloseDateCopy__c number field on all opportunities.
 * To do this, it copies the number value calculated by the Days_Until_Close_Date__c formula field.
 */
global class Opportunity_CopyDaysUntilCloseDate implements Database.Batchable<SObject> {
    
    // Find all open opportunities.
    global Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator('SELECT Id, Days_Until_Close_Date__c, DaysUntilCloseDateCopy__c'
                                       + ' FROM Opportunity');
    }

    // Update all opportunities found.
    global void execute(Database.BatchableContext BC, List<Opportunity> scope) {
        for(Opportunity opp : scope) {
            opp.DaysUntilCloseDateCopy__c = opp.Days_Until_Close_Date__c;
        }      
        update scope;
    }

    // Send an email to report the outcome of the batch job.
    global void finish(Database.BatchableContext BC) {
        AsyncApexJob job = [SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems, CreatedBy.Email
                              FROM AsyncApexJob
                             WHERE Id = :BC.getJobId()];
        String message = 'Job Id: ' + job.Id + '\n'
                       + 'Status: ' + job.Status + '\n'
                       + 'Number of errors: ' + job.NumberOfErrors + '\n'
                       + 'Items processed: ' + job.JobItemsProcessed + '\n'
                       + 'Total items: ' + job.TotalJobItems + '\n'
                       + 'Creator email: ' + job.CreatedBy.Email;
        String[] addresses = new String[] {'rexathletics@gmail.com'},
                 subjects = new String[] {'Batch Process Completed'},
                 messages = new String[] {message};
        EmailManager em = new EmailManager();
        em.sendMail(addresses, subjects, messages);
    }
}
