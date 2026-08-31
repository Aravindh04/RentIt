---
description: Automation conventions for invoice generation, notices, credit application, and community screen flows. Use when building or modifying Flows.
---

## Naming Convention
`RentIT_[Object]_[Trigger]_[Purpose]`

Examples:
- `RentIT_Invoice_Scheduled_GenerateFromContract`
- `RentIT_Payment_AfterSave_ApplyToInvoice`
- `RentIT_Tenancy_Screen_SubmitPayment` (community screen flows)
- `RentIT_Case_Screen_RaiseComplaint`

## Automation Flows (Backend)

| Flow | Type | Trigger | Purpose |
|---|---|---|---|
| `Contract_Activated_Activate_Tenancy` | Record-Triggered | Contract Activated | Sets Tenancy Status = Active |
| `Contract_Expired_Expire_Tenancy` | Record-Triggered | Contract Expired | Sets Tenancy Status = Expired |
| `Contract_Voided_Terminate_Tenancy` | Record-Triggered | Contract Voided | Sets Tenancy Status = Terminated |
| `Payment_Received_Set_Invoice_Paid` | Record-Triggered | Payment Status = Approved | Marks Invoice as Paid |
| `Rent_Payment_Due_Tomorrow_Reminder` | Scheduled | Invoice due date − 1 day | Sends RentReminder email |
| `Rent_Payment_Overdue_Create_Notice` | Scheduled | Invoice due date + N days, still unpaid | Creates Notice record |
| `Rent_Payment_Scheduled_To_Unpaid` | Scheduled | Invoice Status = Scheduled past due | Sets Status = Unpaid |

- **Invoice generation**: `InvoiceBatch` (Apex) called by `InvoiceScheduler` — not a Flow
- **Credit application**: Before-save Record-Triggered Flow on Invoice — applies `Tenancy__c.Available_Credits__c` to Balance_Due
- All scheduled/record-triggered flows must be bulk-safe: Get Records with filters; no loops containing DML

## Community Screen Flows
Screen flows embedded in LWC via `<lightning-flow>` for tenant portal actions.

### Submit Payment (`RentIT_Payment_Screen_SubmitPayment`)
- Input variables: `invoiceId` (from URL state), pre-populated `tenancyId` via `{!$User.Id}` lookup
- Tenant-editable fields only: `Amount__c`, `Payment_Date__c`, `Payment_Method__c`, `Payment_Reference__c`, `Comment__c`
- Sets `Status__c = 'Pending'` on create (never let tenant set Approved/Rejected)
- Final screen: confirmation with payment reference

### Raise a Complaint (`RentIT_Case_Screen_RaiseComplaint`)
- Record type: `Case.Complaint`
- Auto-populate `Case.Tenancy__c`, `Case.Property__c`, `Case.Room__c` from logged-in tenant's tenancy
- Input: Subject, Description
- Final screen: case number confirmation

### Maintenance Request (`RentIT_Case_Screen_MaintenanceRequest`)
- Record type: `Case.Maintenance_Request`
- Same auto-populate pattern as Complaint
- Input: Subject, Description, urgency picklist

### Rules for All Screen Flows
- Always end with a Confirmation screen
- Flows run as the community user — respects sharing (no `without sharing` bypass)
- Use `{!$User.Id}` to auto-link records to the logged-in tenant
- Never expose internal picklist values (Draft, Issued, Approved) to community users; use filtered record choices or hardcode the correct value as a Flow variable
- Validate required fields with a Decision element before the Create Record element

## Email Notifications
Templates in `force-app/main/default/email/RentIt_Notifications/`:
- `PaymentApproved` — sent to tenant when payment approved
- `PaymentPendingApproval` — sent to landlord when tenant submits payment
- `PaymentRejected` — sent to tenant when payment rejected
- `RentArrears` — sent to tenant when overdue notice created
- `RentReminder` — sent to tenant day before rent due

Reference by template name in the **Send Email** Flow element; target `Contact.Email` from the Tenancy's Tenant lookup.
