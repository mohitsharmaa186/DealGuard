# DealGuard CRM

A live portfolio project for a fresher Salesforce Developer role. It demonstrates sales deal approval, discount control, pricing visibility, approval routing, and audit tracking.

## Run Locally

```bash
python -m http.server 4173
```

Open:

```text
http://localhost:4173
```

## What This Shows In An Interview

- Opportunity-style deal queue
- Discount calculator with margin impact
- Rule-based approval routing
- Manager, director, and finance approval decisions
- Validation-style policy signals
- Audit trail and dashboard metrics
- CSV export for reporting

## Salesforce Build Mapping

- Standard object: `Opportunity`
- Custom fields: `Discount_Percent__c`, `Delivery_Cost__c`, `Approval_Status__c`, `Discount_Reason__c`, `Required_Approver__c`, `Margin_Percent__c`
- Automation: record-triggered Flow for routing and status updates
- Approval process: Sales Manager, Regional Director, Finance Controller
- LWC: discount calculator and approval workbench
- Apex: pricing policy service and test classes
- Reports: pending approvals, rejected discounts, average discount by owner, revenue at risk

## Resume Line

Built a Salesforce-style Sales Deal Approval and Discount Management app to automate discount routing, calculate margin risk, capture approval decisions, and provide dashboards for sales leaders using a Flow/Apex/LWC-ready architecture.

## Deploy To Salesforce

Authenticate a free Developer Org:

```bash
sf org login web --alias dealgaurd --instance-url https://login.salesforce.com --set-default
```

Deploy metadata:

```bash
sf project deploy start --target-org dealgaurd --test-level RunLocalTests
```

Assign access:

```bash
sf org assign permset --name DealGuard_Admin --target-org dealgaurd
```

Seed demo data:

```bash
sf apex run --target-org dealgaurd --file scripts/seedDealGuard.apex
```
