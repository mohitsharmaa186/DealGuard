public with sharing class DealGuardEmailService {

    @InvocableMethod(label='Send Deal Notification Email' description='Sends email notifications for deal lifecycle events using User lookup fields')
    public static void sendNotifications(List<EmailRequest> requests) {
        Set<Id> dealIds = new Set<Id>();
        for (EmailRequest req : requests) {
            if (req.dealRequestId != null) {
                dealIds.add(req.dealRequestId);
            }
        }
        if (dealIds.isEmpty()) return;

        Map<Id, Deal_Request__c> dealMap = new Map<Id, Deal_Request__c>([
            SELECT Id, Name, Account_Name__c, Sales_Rep_Name__c, Deal_Amount__c,
                   Discount_Percent__c, Risk_Level__c, Approval_Status__c,
                   Required_Approver__c, Approver_Comments__c, Last_Decision_By__c,
                   Sales_Rep__c, Approver__c
            FROM Deal_Request__c
            WHERE Id IN :dealIds
        ]);

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (EmailRequest req : requests) {
            Deal_Request__c deal = dealMap.get(req.dealRequestId);
            if (deal == null) continue;

            Messaging.SingleEmailMessage email = buildEmail(deal, req.notificationType);
            if (email != null) {
                emails.add(email);
            }
        }

        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails, false);
        }
    }

    private static Messaging.SingleEmailMessage buildEmail(Deal_Request__c deal, String notificationType) {
        Id targetUserId;
        String subject;
        String body;

        if (notificationType == 'Submitted') {
            if (deal.Approver__c == null) return null;
            targetUserId = deal.Approver__c;
            subject = 'DealGuard: New Deal Requires Approval - ' + deal.Name;
            body = buildSubmissionBody(deal);
        } else if (notificationType == 'Approved') {
            if (deal.Sales_Rep__c == null) return null;
            targetUserId = deal.Sales_Rep__c;
            subject = 'DealGuard: Deal Approved - ' + deal.Name;
            body = buildApprovalBody(deal);
        } else if (notificationType == 'Rejected') {
            if (deal.Sales_Rep__c == null) return null;
            targetUserId = deal.Sales_Rep__c;
            subject = 'DealGuard: Deal Rejected - ' + deal.Name;
            body = buildRejectionBody(deal);
        } else {
            return null;
        }

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setTargetObjectId(targetUserId);
        email.setSubject(subject);
        email.setHtmlBody(body);
        email.setSaveAsActivity(false);
        return email;
    }

    private static String buildSubmissionBody(Deal_Request__c deal) {
        return '<div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto">' +
            '<div style="background:#193c54;color:#fff;padding:20px;border-radius:8px 8px 0 0">' +
            '<h2 style="margin:0">DealGuard - New Approval Required</h2></div>' +
            '<div style="padding:20px;border:1px solid #d8e1e8;border-top:0;border-radius:0 0 8px 8px">' +
            '<p>A new deal request requires your approval:</p>' +
            '<table style="width:100%;border-collapse:collapse">' +
            row('Deal Number', deal.Name) +
            row('Account', deal.Account_Name__c) +
            row('Sales Rep', deal.Sales_Rep_Name__c) +
            row('Deal Amount', '$' + String.valueOf(deal.Deal_Amount__c)) +
            row('Discount', String.valueOf(deal.Discount_Percent__c) + '%') +
            row('Risk Level', deal.Risk_Level__c) +
            row('Required Approver', deal.Required_Approver__c) +
            '</table>' +
            '<p style="margin-top:16px;color:#657282">Please log in to DealGuard to review and take action.</p>' +
            '</div></div>';
    }

    private static String buildApprovalBody(Deal_Request__c deal) {
        return '<div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto">' +
            '<div style="background:#29724f;color:#fff;padding:20px;border-radius:8px 8px 0 0">' +
            '<h2 style="margin:0">DealGuard - Deal Approved &#10003;</h2></div>' +
            '<div style="padding:20px;border:1px solid #d8e1e8;border-top:0;border-radius:0 0 8px 8px">' +
            '<p>Your deal request has been <strong style="color:#29724f">approved</strong>:</p>' +
            '<table style="width:100%;border-collapse:collapse">' +
            row('Deal Number', deal.Name) +
            row('Account', deal.Account_Name__c) +
            row('Deal Amount', '$' + String.valueOf(deal.Deal_Amount__c)) +
            row('Discount', String.valueOf(deal.Discount_Percent__c) + '%') +
            row('Approved By', deal.Last_Decision_By__c) +
            '</table>' +
            '<p style="margin-top:16px;color:#657282">You may now proceed with the deal.</p>' +
            '</div></div>';
    }

    private static String buildRejectionBody(Deal_Request__c deal) {
        String comments = String.isBlank(deal.Approver_Comments__c) ? 'No comments provided.' : deal.Approver_Comments__c;
        return '<div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto">' +
            '<div style="background:#c74343;color:#fff;padding:20px;border-radius:8px 8px 0 0">' +
            '<h2 style="margin:0">DealGuard - Deal Rejected &#10007;</h2></div>' +
            '<div style="padding:20px;border:1px solid #d8e1e8;border-top:0;border-radius:0 0 8px 8px">' +
            '<p>Your deal request has been <strong style="color:#c74343">rejected</strong>:</p>' +
            '<table style="width:100%;border-collapse:collapse">' +
            row('Deal Number', deal.Name) +
            row('Account', deal.Account_Name__c) +
            row('Deal Amount', '$' + String.valueOf(deal.Deal_Amount__c)) +
            row('Discount', String.valueOf(deal.Discount_Percent__c) + '%') +
            row('Rejected By', deal.Last_Decision_By__c) +
            row('Comments', comments) +
            '</table>' +
            '<p style="margin-top:16px;color:#657282">Please revise and resubmit if appropriate.</p>' +
            '</div></div>';
    }

    private static String row(String label, String value) {
        return '<tr><td style="padding:8px 12px;border-bottom:1px solid #eef4f5;color:#657282;width:40%">' +
            label + '</td><td style="padding:8px 12px;border-bottom:1px solid #eef4f5;font-weight:bold">' +
            (String.isBlank(value) ? '-' : value) + '</td></tr>';
    }

    public class EmailRequest {
        @InvocableVariable(required=true label='Deal Request ID')
        public Id dealRequestId;
        @InvocableVariable(required=true label='Notification Type')
        public String notificationType;
    }
}
