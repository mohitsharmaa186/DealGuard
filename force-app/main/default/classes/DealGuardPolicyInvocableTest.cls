@IsTest
private class DealGuardPolicyInvocableTest {

    @IsTest
    static void calculatesAutoApprovedPolicy() {
        DealGuardPolicyInvocable.PolicyInput input = new DealGuardPolicyInvocable.PolicyInput();
        input.dealAmount = 50000;
        input.deliveryCost = 25000;
        input.discountPercent = 5;
        input.customerTier = 'Standard';

        Test.startTest();
        List<DealGuardPolicyInvocable.PolicyOutput> outputs = DealGuardPolicyInvocable.calculatePolicies(
            new List<DealGuardPolicyInvocable.PolicyInput>{ input }
        );
        Test.stopTest();

        System.assertEquals(1, outputs.size());
        System.assertEquals('Auto Approved', outputs[0].requiredApprover);
    }

    @IsTest
    static void calculatesSalesManagerPolicy() {
        DealGuardPolicyInvocable.PolicyInput input = new DealGuardPolicyInvocable.PolicyInput();
        input.dealAmount = 80000;
        input.deliveryCost = 45000;
        input.discountPercent = 15;
        input.customerTier = 'Growth';

        Test.startTest();
        List<DealGuardPolicyInvocable.PolicyOutput> outputs = DealGuardPolicyInvocable.calculatePolicies(
            new List<DealGuardPolicyInvocable.PolicyInput>{ input }
        );
        Test.stopTest();

        System.assertEquals('Sales Manager', outputs[0].requiredApprover);
    }

    @IsTest
    static void calculatesRegionalDirectorPolicy() {
        DealGuardPolicyInvocable.PolicyInput input = new DealGuardPolicyInvocable.PolicyInput();
        input.dealAmount = 160000;
        input.deliveryCost = 90000;
        input.discountPercent = 22;
        input.customerTier = 'Standard';

        Test.startTest();
        List<DealGuardPolicyInvocable.PolicyOutput> outputs = DealGuardPolicyInvocable.calculatePolicies(
            new List<DealGuardPolicyInvocable.PolicyInput>{ input }
        );
        Test.stopTest();

        System.assertEquals('Regional Director', outputs[0].requiredApprover);
    }

    @IsTest
    static void calculatesFinanceControllerPolicy() {
        DealGuardPolicyInvocable.PolicyInput input = new DealGuardPolicyInvocable.PolicyInput();
        input.dealAmount = 100000;
        input.deliveryCost = 70000;
        input.discountPercent = 35;
        input.customerTier = 'Growth';

        Test.startTest();
        List<DealGuardPolicyInvocable.PolicyOutput> outputs = DealGuardPolicyInvocable.calculatePolicies(
            new List<DealGuardPolicyInvocable.PolicyInput>{ input }
        );
        Test.stopTest();

        System.assertEquals('Finance Controller', outputs[0].requiredApprover);
        System.assertEquals('High', outputs[0].riskLevel);
    }

    @IsTest
    static void handlesBulkInput() {
        List<DealGuardPolicyInvocable.PolicyInput> inputs = new List<DealGuardPolicyInvocable.PolicyInput>();
        for (Integer i = 0; i < 200; i++) {
            DealGuardPolicyInvocable.PolicyInput input = new DealGuardPolicyInvocable.PolicyInput();
            input.dealAmount = 50000;
            input.deliveryCost = 25000;
            input.discountPercent = 5;
            input.customerTier = 'Standard';
            inputs.add(input);
        }

        Test.startTest();
        List<DealGuardPolicyInvocable.PolicyOutput> outputs = DealGuardPolicyInvocable.calculatePolicies(inputs);
        Test.stopTest();

        System.assertEquals(200, outputs.size());
    }
}
