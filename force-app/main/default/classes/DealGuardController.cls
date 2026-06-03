public with sharing class DealGuardController {
    private static final String STATUS_PENDING = 'Pending';
    private static final String STATUS_APPROVED = 'Approved';
    private static final String STATUS_REJECTED = 'Rejected';

    @AuraEnabled(cacheable=true)
    public static List<DealDto> getDeals() {
        return buildDtos([
            SELECT Id, Name, Account_Name__c, Sales_Rep_Name__c, Region__c, Customer_Tier__c,
                Deal_Stage__c, Deal_Amount__c, Delivery_Cost__c, Discount_Percent__c,
                Final_Price__c, Gross_Margin_Percent__c, Approval_Status__c,
                Required_Approver__c, Risk_Level__c, Discount_Reason__c, Approver_Comments__c,
                Last_Decision_By__c, Decision_Date__c, CreatedDate,
                Sales_Rep__c, Approver__c, Sales_Rep__r.Name, Approver__r.Name
            FROM Deal_Request__c
            ORDER BY CreatedDate DESC
            LIMIT 200
        ]);
    }

    @AuraEnabled
    public static Integer seedDemoData() {
        Integer existingCount = [SELECT COUNT() FROM Deal_Request__c];
        if (existingCount > 0) {
            return 0;
        }

        List<Deal_Request__c> records = new List<Deal_Request__c>{
            newDemoDeal('Apex Medicals', 'Riya Sharma', 'West', 'Strategic', 'Procurement', 124000, 79000, 18, 'Competitor offered lower renewal pricing.'),
            newDemoDeal('Nimbus Retail', 'Kabir Verma', 'North', 'Growth', 'Negotiation', 86000, 54000, 12, 'Bundle discount requested for multi-product deal.'),
            newDemoDeal('Orion Logistics', 'Neha Iyer', 'South', 'Standard', 'Legal Review', 152000, 116500, 28, 'One-time discount requested to close this quarter.'),
            newDemoDeal('Vertex Fintech', 'Aman Gupta', 'East', 'Strategic', 'Negotiation', 232000, 131000, 8, 'Partner referral incentive.'),
            newDemoDeal('Helio Manufacturing', 'Priya Nair', 'Central', 'Growth', 'Procurement', 98000, 69000, 33, 'Customer expects price match for three-year contract.')
        };

        insert records;
        insertHistoryFor(records, 'Submitted', 'Sales Rep', 'Seed demo request');
        return records.size();
    }

    @AuraEnabled
    public static DealDto createDeal(DealInput input) {
        if (input == null) {
            throw new AuraHandledException('Deal details are required.');
        }

        requireText(input.accountName, 'Account Name');
        requireText(input.salesRepName, 'Sales Rep Name');

        PolicyResult policy = calculatePolicy(input.dealAmount, input.deliveryCost, input.discountPercent, input.customerTier);
        String status = policy.requiredApprover == 'Auto Approved' ? STATUS_APPROVED : STATUS_PENDING;

        Deal_Request__c record = new Deal_Request__c(
            Account_Name__c = input.accountName.trim(),
            Sales_Rep_Name__c = input.salesRepName.trim(),
            Region__c = defaultText(input.region, 'West'),
            Customer_Tier__c = defaultText(input.customerTier, 'Standard'),
            Deal_Stage__c = defaultText(input.dealStage, 'Negotiation'),
            Deal_Amount__c = safeDecimal(input.dealAmount),
            Delivery_Cost__c = safeDecimal(input.deliveryCost),
            Discount_Percent__c = safeDecimal(input.discountPercent),
            Discount_Reason__c = defaultText(input.discountReason, 'Standard commercial request.'),
            Approval_Status__c = status,
            Required_Approver__c = policy.requiredApprover,
            Risk_Level__c = policy.riskLevel,
            Sales_Rep__c = UserInfo.getUserId()
        );

        insert record;

        Deal_Approval_History__c history = new Deal_Approval_History__c(
            Deal_Request__c = record.Id,
            Action__c = status == STATUS_APPROVED ? 'Auto Approved' : 'Submitted',
            Actor_Role__c = status == STATUS_APPROVED ? 'System' : 'Sales Rep',
            Comments__c = status == STATUS_APPROVED ? 'Within standard discount policy.' : 'Routed to ' + policy.requiredApprover,
            Action_Date__c = System.now()
        );
        insert history;

        return getDeal(record.Id);
    }

    @AuraEnabled
    public static DealDto updateDecision(Id dealId, String status, String note, String actorRole) {
        if (dealId == null) {
            throw new AuraHandledException('Deal request id is required.');
        }
        if (status != STATUS_APPROVED && status != STATUS_REJECTED) {
            throw new AuraHandledException('Decision must be Approved or Rejected.');
        }

        Deal_Request__c record = [
            SELECT Id, Deal_Amount__c, Delivery_Cost__c, Discount_Percent__c, Customer_Tier__c,
                Approval_Status__c, Required_Approver__c, Risk_Level__c
            FROM Deal_Request__c
            WHERE Id = :dealId
            LIMIT 1
            FOR UPDATE
        ];

        if (record.Approval_Status__c != STATUS_PENDING) {
            throw new AuraHandledException('Only pending requests can be approved or rejected.');
        }

        PolicyResult policy = calculatePolicy(
            record.Deal_Amount__c,
            record.Delivery_Cost__c,
            record.Discount_Percent__c,
            record.Customer_Tier__c
        );

        if (String.isBlank(actorRole) || !canRoleDecide(actorRole, policy.requiredApprover)) {
            throw new AuraHandledException(policy.requiredApprover + ' or higher must decide this request.');
        }

        record.Approval_Status__c = status;
        record.Required_Approver__c = policy.requiredApprover;
        record.Risk_Level__c = policy.riskLevel;
        record.Approver_Comments__c = note;
        record.Last_Decision_By__c = actorRole;
        record.Decision_Date__c = System.now();
        update record;

        insert new Deal_Approval_History__c(
            Deal_Request__c = record.Id,
            Action__c = status,
            Actor_Role__c = actorRole,
            Comments__c = note,
            Action_Date__c = System.now()
        );

        return getDeal(record.Id);
    }

    private static DealDto getDeal(Id dealId) {
        List<DealDto> deals = buildDtos([
            SELECT Id, Name, Account_Name__c, Sales_Rep_Name__c, Region__c, Customer_Tier__c,
                Deal_Stage__c, Deal_Amount__c, Delivery_Cost__c, Discount_Percent__c,
                Final_Price__c, Gross_Margin_Percent__c, Approval_Status__c,
                Required_Approver__c, Risk_Level__c, Discount_Reason__c, Approver_Comments__c,
                Last_Decision_By__c, Decision_Date__c, CreatedDate,
                Sales_Rep__c, Approver__c, Sales_Rep__r.Name, Approver__r.Name
            FROM Deal_Request__c
            WHERE Id = :dealId
            LIMIT 1
        ]);
        return deals.isEmpty() ? null : deals[0];
    }

    private static List<DealDto> buildDtos(List<Deal_Request__c> records) {
        Map<Id, List<String>> historyByDeal = new Map<Id, List<String>>();
        Set<Id> recordIds = new Map<Id, Deal_Request__c>(records).keySet();

        if (!recordIds.isEmpty()) {
            for (Deal_Approval_History__c history : [
                SELECT Deal_Request__c, Action__c, Actor_Role__c, Comments__c, Action_Date__c, CreatedDate
                FROM Deal_Approval_History__c
                WHERE Deal_Request__c IN :recordIds
                ORDER BY Action_Date__c DESC, CreatedDate DESC
            ]) {
                if (!historyByDeal.containsKey(history.Deal_Request__c)) {
                    historyByDeal.put(history.Deal_Request__c, new List<String>());
                }
                if (historyByDeal.get(history.Deal_Request__c).size() < 6) {
                    historyByDeal.get(history.Deal_Request__c).add(toActivityLine(history));
                }
            }
        }

        List<DealDto> dtos = new List<DealDto>();
        for (Deal_Request__c record : records) {
            PolicyResult policy = calculatePolicy(
                record.Deal_Amount__c,
                record.Delivery_Cost__c,
                record.Discount_Percent__c,
                record.Customer_Tier__c
            );

            DealDto dto = new DealDto();
            dto.id = record.Id;
            dto.name = record.Name;
            dto.accountName = record.Account_Name__c;
            dto.salesRepName = record.Sales_Rep_Name__c;
            dto.region = record.Region__c;
            dto.customerTier = record.Customer_Tier__c;
            dto.dealStage = record.Deal_Stage__c;
            dto.dealAmount = safeDecimal(record.Deal_Amount__c);
            dto.deliveryCost = safeDecimal(record.Delivery_Cost__c);
            dto.discountPercent = safeDecimal(record.Discount_Percent__c);
            dto.finalPrice = calculateFinalPrice(record.Deal_Amount__c, record.Discount_Percent__c);
            dto.discountValue = calculateDiscountValue(record.Deal_Amount__c, record.Discount_Percent__c);
            dto.marginPercent = calculateMarginPercent(record.Deal_Amount__c, record.Delivery_Cost__c, record.Discount_Percent__c);
            dto.approvalStatus = String.isBlank(record.Approval_Status__c) ? STATUS_PENDING : record.Approval_Status__c;
            dto.requiredApprover = String.isBlank(record.Required_Approver__c) ? policy.requiredApprover : record.Required_Approver__c;
            dto.riskLevel = String.isBlank(record.Risk_Level__c) ? policy.riskLevel : record.Risk_Level__c;
            dto.discountReason = record.Discount_Reason__c;
            dto.approverComments = record.Approver_Comments__c;
            dto.lastDecisionBy = record.Last_Decision_By__c;
            dto.decisionDate = record.Decision_Date__c == null ? null : String.valueOf(record.Decision_Date__c);
            dto.createdDate = record.CreatedDate == null ? null : String.valueOf(record.CreatedDate);
            dto.policySignal = policy.signal;
            dto.salesRepId = record.Sales_Rep__c;
            dto.approverId = record.Approver__c;
            dto.approverName = record.Approver__r != null ? record.Approver__r.Name : '';
            dto.activity = historyByDeal.containsKey(record.Id) ? historyByDeal.get(record.Id) : new List<String>{ 'Submitted by ' + record.Sales_Rep_Name__c };
            dtos.add(dto);
        }
        return dtos;
    }

    private static Deal_Request__c newDemoDeal(String accountName, String salesRep, String region, String tier, String stage, Decimal amount, Decimal cost, Decimal discount, String reason) {
        PolicyResult policy = calculatePolicy(amount, cost, discount, tier);
        return new Deal_Request__c(
            Account_Name__c = accountName,
            Sales_Rep_Name__c = salesRep,
            Region__c = region,
            Customer_Tier__c = tier,
            Deal_Stage__c = stage,
            Deal_Amount__c = amount,
            Delivery_Cost__c = cost,
            Discount_Percent__c = discount,
            Discount_Reason__c = reason,
            Approval_Status__c = policy.requiredApprover == 'Auto Approved' ? STATUS_APPROVED : STATUS_PENDING,
            Required_Approver__c = policy.requiredApprover,
            Risk_Level__c = policy.riskLevel
        );
    }

    private static void insertHistoryFor(List<Deal_Request__c> records, String action, String actorRole, String comments) {
        List<Deal_Approval_History__c> histories = new List<Deal_Approval_History__c>();
        for (Deal_Request__c record : records) {
            histories.add(new Deal_Approval_History__c(
                Deal_Request__c = record.Id,
                Action__c = record.Approval_Status__c == STATUS_APPROVED ? 'Auto Approved' : action,
                Actor_Role__c = record.Approval_Status__c == STATUS_APPROVED ? 'System' : actorRole,
                Comments__c = record.Approval_Status__c == STATUS_APPROVED ? 'Within standard discount policy.' : comments + ' routed to ' + record.Required_Approver__c,
                Action_Date__c = System.now()
            ));
        }
        insert histories;
    }

    public static PolicyResult calculatePolicy(Decimal amount, Decimal cost, Decimal discount, String tier) {
        Decimal safeAmount = safeDecimal(amount);
        Decimal safeDiscount = safeDecimal(discount);
        Decimal margin = calculateMarginPercent(amount, cost, discount);
        String safeTier = String.isBlank(tier) ? 'Standard' : tier;

        if (margin < 18 || safeDiscount >= 31) {
            return new PolicyResult('Finance Controller', 'High', margin < 18 ? 'Margin is below finance threshold.' : 'Discount exceeds 30 percent.');
        }

        if (safeDiscount >= 21 || safeAmount >= 150000 || (safeTier == 'Strategic' && safeDiscount > 15)) {
            return new PolicyResult('Regional Director', margin < 24 || safeDiscount >= 25 ? 'High' : 'Medium', safeTier == 'Strategic' && safeDiscount > 15 ? 'Strategic account needs director review.' : 'Large deal or high discount.');
        }

        if (safeDiscount >= 11) {
            return new PolicyResult('Sales Manager', margin < 26 ? 'Medium' : 'Low', 'Standard manager approval required.');
        }

        return new PolicyResult('Auto Approved', margin < 22 ? 'Medium' : 'Low', 'Within standard discount policy.');
    }

    private static Decimal calculateFinalPrice(Decimal amount, Decimal discount) {
        return (safeDecimal(amount) * (1 - (safeDecimal(discount) / 100))).setScale(2);
    }

    private static Decimal calculateDiscountValue(Decimal amount, Decimal discount) {
        return (safeDecimal(amount) * (safeDecimal(discount) / 100)).setScale(2);
    }

    private static Decimal calculateMarginPercent(Decimal amount, Decimal cost, Decimal discount) {
        Decimal finalPrice = calculateFinalPrice(amount, discount);
        if (finalPrice == 0) {
            return 0;
        }
        return (((finalPrice - safeDecimal(cost)) / finalPrice) * 100).setScale(1);
    }

    private static String toActivityLine(Deal_Approval_History__c history) {
        String line = history.Action__c;
        if (!String.isBlank(history.Actor_Role__c)) {
            line += ' by ' + history.Actor_Role__c;
        }
        if (!String.isBlank(history.Comments__c)) {
            line += ': ' + history.Comments__c;
        }
        return line;
    }

    private static void requireText(String value, String label) {
        if (String.isBlank(value)) {
            throw new AuraHandledException(label + ' is required.');
        }
    }

    private static Decimal safeDecimal(Decimal value) {
        return value == null ? 0 : value;
    }

    private static Boolean canRoleDecide(String currentRole, String requiredRole) {
        Map<String, Integer> hierarchy = new Map<String, Integer>{
            'Sales Manager' => 1,
            'Regional Director' => 2,
            'Finance Controller' => 3
        };
        Integer currentRank = hierarchy.get(currentRole);
        Integer requiredRank = hierarchy.get(requiredRole);
        if (currentRank == null || requiredRank == null) {
            return false;
        }
        return currentRank >= requiredRank;
    }

    private static String defaultText(String value, String fallback) {
        return String.isBlank(value) ? fallback : value.trim();
    }

    public class PolicyResult {
        public String requiredApprover;
        public String riskLevel;
        public String signal;

        PolicyResult(String requiredApprover, String riskLevel, String signal) {
            this.requiredApprover = requiredApprover;
            this.riskLevel = riskLevel;
            this.signal = signal;
        }
    }

    public class DealInput {
        @AuraEnabled public String accountName { get; set; }
        @AuraEnabled public String salesRepName { get; set; }
        @AuraEnabled public String region { get; set; }
        @AuraEnabled public String customerTier { get; set; }
        @AuraEnabled public String dealStage { get; set; }
        @AuraEnabled public Decimal dealAmount { get; set; }
        @AuraEnabled public Decimal deliveryCost { get; set; }
        @AuraEnabled public Decimal discountPercent { get; set; }
        @AuraEnabled public String discountReason { get; set; }
        @AuraEnabled public Id salesRepId { get; set; }
    }

    public class DealDto {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String accountName { get; set; }
        @AuraEnabled public String salesRepName { get; set; }
        @AuraEnabled public String region { get; set; }
        @AuraEnabled public String customerTier { get; set; }
        @AuraEnabled public String dealStage { get; set; }
        @AuraEnabled public Decimal dealAmount { get; set; }
        @AuraEnabled public Decimal deliveryCost { get; set; }
        @AuraEnabled public Decimal discountPercent { get; set; }
        @AuraEnabled public Decimal finalPrice { get; set; }
        @AuraEnabled public Decimal discountValue { get; set; }
        @AuraEnabled public Decimal marginPercent { get; set; }
        @AuraEnabled public String approvalStatus { get; set; }
        @AuraEnabled public String requiredApprover { get; set; }
        @AuraEnabled public String riskLevel { get; set; }
        @AuraEnabled public String discountReason { get; set; }
        @AuraEnabled public String approverComments { get; set; }
        @AuraEnabled public String lastDecisionBy { get; set; }
        @AuraEnabled public String decisionDate { get; set; }
        @AuraEnabled public String createdDate { get; set; }
        @AuraEnabled public String policySignal { get; set; }
        @AuraEnabled public Id salesRepId { get; set; }
        @AuraEnabled public Id approverId { get; set; }
        @AuraEnabled public String approverName { get; set; }
        @AuraEnabled public List<String> activity { get; set; }
    }
}
