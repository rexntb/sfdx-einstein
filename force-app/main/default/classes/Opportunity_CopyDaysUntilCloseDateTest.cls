/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an org are executed whenever Apex code is deployed
 * to a production org to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production org. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the org size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest
private class Opportunity_CopyDaysUntilCloseDateTest {

    // Create opportunities with discounts 25% and higher and approve them
    @TestSetup
    private static void createAndApproveOpportunities() {
        System.debug('Setup method has started running.');
        List<Opportunity> opportunitiesList = new List<Opportunity>();
        // Insert 100 opportunities
        for (Integer i = 0; i < 100; i++) {
            Opportunity opp = new Opportunity();
            opp.Name = 'Test opportunity ' + i;
            opp.StageName = 'Qualification';
            opp.Amount = 250000;
            opp.Discount__c = 30;
            opp.CloseDate = Date.today().addMonths(3);
            opportunitiesList.add(opp);
        }
        insert opportunitiesList;

        // Submit opportunities for approval
        submitOpportunitiesforApproval(opportunitiesList);
    }

    // Submit the opportunities for approval
    private static void submitOpportunitiesforApproval(List<Opportunity> oppsToSubmit) {
        List<Approval.ProcessSubmitRequest> allReqs1 = new List<Approval.ProcessSubmitRequest>();
        for (Opportunity oppty : oppsToSubmit) {
            Approval.ProcessSubmitRequest req1 = new Approval.ProcessSubmitRequest();
            req1.setProcessDefinitionNameOrId('Discount_Approval_Process');
            req1.setComments('Discount approval needed.');
            req1.setNextApproverIds(new Id[] {UserInfo.getUserId()});
            req1.setObjectId(oppty.Id);
            allReqs1.add(req1);
        }
        Approval.ProcessResult[] submits = Approval.process(allReqs1);

        // Approve opportunities
        approveOpportunities();
    }

    // Approve the new opportunities
    private static void approveOpportunities() {
        Set<Id> oppIds = new Map<Id, Opportunity>([SELECT Id 
                                                     FROM Opportunity]).keySet();
        Set<Id> pIds = new Map<Id, ProcessInstance>([SELECT Id, Status, TargetObjectId 
                                                       FROM ProcessInstance 
                                                      WHERE Status = 'Pending' 
                                                        AND TargetObjectId 
                                                         IN :oppIds]).keySet();
        Set<Id> pInsWkItems = new Map<Id, ProcessInstanceWorkItem>([SELECT Id, ProcessInstanceId 
                                                                      FROM ProcessInstanceWorkItem 
                                                                     WHERE ProcessInstanceId 
                                                                        IN :pIds]).keySet();
        List<Approval.ProcessWorkitemRequest> allReqs2 = new List<Approval.ProcessWorkitemRequest>();
        for (Id pInsWkItem : pInsWkItems) {
            Approval.ProcessWorkitemRequest req2 = new Approval.ProcessWorkitemRequest();
            req2.setComments('Discount approval needed.');
            req2.setAction('Approve');
            req2.setNextApproverIds(new Id[] {UserInfo.getUserId()});
            req2.setWorkitemId(pInsWkItem);
            allReqs2.add(req2);
        }
        Approval.ProcessResult[] results = Approval.process(allReqs2);
    }

    // Run the batch job against the new opportunities
    @isTest
    private static void batchJobTest() {
        Test.startTest();
        Opportunity_CopyDaysUntilCloseDate job = new Opportunity_CopyDaysUntilCloseDate();
        Id jobId = Database.executeBatch(job);
        Test.stopTest();

        List<Opportunity> updatedOpps = [SELECT Id, Days_Until_Close_Date__c, DaysUntilCloseDateCopy__c, Discount_Approval_Status__c
                                           FROM Opportunity];
        for (Opportunity updatedOpp : updatedOpps) {
            System.assertEquals(updatedOpp.Days_Until_Close_Date__c, updatedOpp.DaysUntilCloseDateCopy__c);
            System.assertEquals('Approved', updatedOpp.Discount_Approval_Status__c);
        }                            
    }
}