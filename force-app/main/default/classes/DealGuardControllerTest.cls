@IsTest
private class DealGuardControllerTest {
    @IsTest
    static void createsAndApprovesSalesManagerDeal() {
        DealGuardController.DealInput input = new DealGuardController.DealInput();
        input.accountName = 'Test Retail';
        input.salesRepName = 'Test Rep';
        input.region = 'North';
        input.customerTier = 'Growth';
        input.dealStage = 'Negotiation';
        input.dealAmount = 100000;
        input.deliveryCost = 60000;
        input.discountPercent = 12;
        input.discountReason = 'Competitive price match.';

        Test.startTest();
        DealGuardController.DealDto created = DealGuardController.createDeal(input);
        DealGuardController.DealDto approved = DealGuardController.updateDecision(
            created.id,
            'Approved',
            'Approved for strategic quarter close.',
            'Sales Manager'
        );
        Test.stopTest();

        System.assertEquals('Sales Manager', created.requiredApprover);
        System.assertEquals('Approved', approved.approvalStatus);
        System.assertEquals('Sales Manager', approved.lastDecisionBy);
        System.assertEquals(1, [SELECT COUNT() FROM Deal_Request__c]);
        List<Deal_Approval_History__c> histories = [
            SELECT Action__c, Actor_Role__c, Comments__c
            FROM Deal_Approval_History__c
            ORDER BY CreatedDate ASC
        ];
        System.assertEquals(4, histories.size(), 'Four approval history records should be created (two by Controller code, two by Flow automation).');

        // Verify the history of the deal creation/submission
        // 1. Flow submission history
        System.assertEquals('Submitted', histories[0].Action__c);
        System.assertEquals('Sales Rep', histories[0].Actor_Role__c);
        System.assertEquals('Deal submitted and routed for approval.', histories[0].Comments__c);

        // 2. Controller submission history
        System.assertEquals('Submitted', histories[1].Action__c);
        System.assertEquals('Sales Rep', histories[1].Actor_Role__c);
        System.assertEquals('Routed to Sales Manager', histories[1].Comments__c);

        // Verify the history of the deal approval
        // 3. Flow approval history
        System.assertEquals('Approved', histories[2].Action__c);
        System.assertEquals('Sales Manager', histories[2].Actor_Role__c);
        System.assertEquals('Approved for strategic quarter close.', histories[2].Comments__c);

        // 4. Controller approval history
        System.assertEquals('Approved', histories[3].Action__c);
        System.assertEquals('Sales Manager', histories[3].Actor_Role__c);
        System.assertEquals('Approved for strategic quarter close.', histories[3].Comments__c);

        System.assertNotEquals(null, created.salesRepId, 'Sales Rep lookup should be populated.');
    }

    @IsTest
    static void seedsDemoDataWhenOrgIsEmpty() {
        Test.startTest();
        Integer insertedCount = DealGuardController.seedDemoData();
        List<DealGuardController.DealDto> deals = DealGuardController.getDeals();
        Test.stopTest();

        System.assertEquals(5, insertedCount);
        System.assertEquals(5, deals.size());
        System.assert(deals[0].activity.size() > 0, 'Seeded records should have approval history.');
    }

    @IsTest
    static void rejectsWrongApproverRole() {
        DealGuardController.DealInput input = new DealGuardController.DealInput();
        input.accountName = 'Finance Review Co';
        input.salesRepName = 'Test Rep';
        input.region = 'Central';
        input.customerTier = 'Growth';
        input.dealStage = 'Procurement';
        input.dealAmount = 90000;
        input.deliveryCost = 62000;
        input.discountPercent = 33;
        input.discountReason = 'Large multi-year request.';

        DealGuardController.DealDto created = DealGuardController.createDeal(input);

        try {
            DealGuardController.updateDecision(created.id, 'Approved', 'Trying wrong role.', 'Sales Manager');
            System.assert(false, 'Expected wrong role to be rejected.');
        } catch (AuraHandledException expected) {
            System.assert(true, 'Wrong role rejected.');
        }
    }
}
