public with sharing class DealGuardPolicyInvocable {

    @InvocableMethod(label='Calculate Deal Policy' description='Calculates risk level and required approver using DealGuard policy engine')
    public static List<PolicyOutput> calculatePolicies(List<PolicyInput> inputs) {
        // Build role-to-user mapping from custom metadata
        Map<String, String> roleToUserMap = new Map<String, String>();
        for (DealGuard_Role_Config__mdt config : DealGuard_Role_Config__mdt.getAll().values()) {
            if (String.isNotBlank(config.Assigned_User_Id__c)) {
                roleToUserMap.put(config.Role_Name__c, config.Assigned_User_Id__c);
            }
        }

        List<PolicyOutput> outputs = new List<PolicyOutput>();
        for (PolicyInput input : inputs) {
            DealGuardController.PolicyResult result = DealGuardController.calculatePolicy(
                input.dealAmount, input.deliveryCost, input.discountPercent, input.customerTier
            );

            PolicyOutput output = new PolicyOutput();
            output.riskLevel = result.riskLevel;
            output.requiredApprover = result.requiredApprover;
            output.policySignal = result.signal;
            String userIdStr = roleToUserMap.get(result.requiredApprover);
            if (String.isNotBlank(userIdStr)) {
                try {
                    output.approverUserId = Id.valueOf(userIdStr);
                } catch (Exception e) {
                    output.approverUserId = null;
                }
            }
            outputs.add(output);
        }
        return outputs;
    }

    public class PolicyInput {
        @InvocableVariable(required=true label='Deal Amount')
        public Decimal dealAmount;
        @InvocableVariable(required=true label='Delivery Cost')
        public Decimal deliveryCost;
        @InvocableVariable(required=true label='Discount Percent')
        public Decimal discountPercent;
        @InvocableVariable(label='Customer Tier')
        public String customerTier;
    }

    public class PolicyOutput {
        @InvocableVariable(label='Risk Level')
        public String riskLevel;
        @InvocableVariable(label='Required Approver Role')
        public String requiredApprover;
        @InvocableVariable(label='Policy Signal')
        public String policySignal;
        @InvocableVariable(label='Approver User ID')
        public Id approverUserId;
    }
}
