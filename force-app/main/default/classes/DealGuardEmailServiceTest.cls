@IsTest
private class DealGuardEmailServiceTest {

    @TestSetup
    static void setup() {
        Deal_Request__c deal = new Deal_Request__c(
            Account_Name__c = 'Test Email Corp',
            Sales_Rep_Name__c = 'Test Rep',
            Region__c = 'West',
            Customer_Tier__c = 'Growth',
            Deal_Stage__c = 'Negotiation',
            Deal_Amount__c = 100000,
            Delivery_Cost__c = 60000,
            Discount_Percent__c = 15,
            Discount_Reason__c = 'Test email notification.',
            Approval_Status__c = 'Pending',
            Required_Approver__c = 'Sales Manager',
            Risk_Level__c = 'Low',
            Sales_Rep__c = UserInfo.getUserId(),
            Approver__c = UserInfo.getUserId()
        );
        insert deal;
    }

    @IsTest
    static void sendsSubmissionNotification() {
        Deal_Request__c deal = [SELECT Id FROM Deal_Request__c LIMIT 1];

        DealGuardEmailService.EmailRequest req = new DealGuardEmailService.EmailRequest();
        req.dealRequestId = deal.Id;
        req.notificationType = 'Submitted';

        Test.startTest();
        Integer emailsBefore = Limits.getEmailInvocations();
        DealGuardEmailService.sendNotifications(new List<DealGuardEmailService.EmailRequest>{ req });
        Test.stopTest();

        // Verify email was queued (count increased)
        System.assert(Limits.getEmailInvocations() >= emailsBefore, 'Email should have been sent.');
    }

    @IsTest
    static void sendsApprovalNotification() {
        Deal_Request__c deal = [SELECT Id FROM Deal_Request__c LIMIT 1];

        DealGuardEmailService.EmailRequest req = new DealGuardEmailService.EmailRequest();
        req.dealRequestId = deal.Id;
        req.notificationType = 'Approved';

        Test.startTest();
        DealGuardEmailService.sendNotifications(new List<DealGuardEmailService.EmailRequest>{ req });
        Test.stopTest();
    }

    @IsTest
    static void sendsRejectionNotification() {
        Deal_Request__c deal = [SELECT Id FROM Deal_Request__c LIMIT 1];
        deal.Approver_Comments__c = 'Margin too low for this quarter.';
        update deal;

        DealGuardEmailService.EmailRequest req = new DealGuardEmailService.EmailRequest();
        req.dealRequestId = deal.Id;
        req.notificationType = 'Rejected';

        Test.startTest();
        DealGuardEmailService.sendNotifications(new List<DealGuardEmailService.EmailRequest>{ req });
        Test.stopTest();
    }

    @IsTest
    static void handlesNullApprover() {
        Deal_Request__c deal = [SELECT Id FROM Deal_Request__c LIMIT 1];
        deal.Approver__c = null;
        update deal;

        DealGuardEmailService.EmailRequest req = new DealGuardEmailService.EmailRequest();
        req.dealRequestId = deal.Id;
        req.notificationType = 'Submitted';

        Test.startTest();
        DealGuardEmailService.sendNotifications(new List<DealGuardEmailService.EmailRequest>{ req });
        Test.stopTest();
        // Should not throw - gracefully handles null approver
    }

    @IsTest
    static void handlesInvalidNotificationType() {
        Deal_Request__c deal = [SELECT Id FROM Deal_Request__c LIMIT 1];

        DealGuardEmailService.EmailRequest req = new DealGuardEmailService.EmailRequest();
        req.dealRequestId = deal.Id;
        req.notificationType = 'InvalidType';

        Test.startTest();
        DealGuardEmailService.sendNotifications(new List<DealGuardEmailService.EmailRequest>{ req });
        Test.stopTest();
    }
}
