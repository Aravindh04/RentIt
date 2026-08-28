# RentIt — Data Model & Administration Guide

**API Version:** 62.0  
**Last Updated:** 2026-08-28  
**Author:** Aravindhan Vijayakumar

---

## Table of Contents
1. [Object Overview](#1-object-overview)
2. [Object Relationships (ERD)](#2-object-relationships-erd)
3. [Object Reference](#3-object-reference)
4. [Automation & Flows](#4-automation--flows)
5. [Approval Process — Rent Payment](#5-approval-process--rent-payment)
6. [Apex Batch — Rent Payment Generator](#6-apex-batch--rent-payment-generator)
7. [Email Templates](#7-email-templates)
8. [Page Layouts](#8-page-layouts)
9. [Permission Sets](#9-permission-sets)
10. [Key Application Capabilities](#10-key-application-capabilities)

---

## 1. Object Overview

| Object | Type | Purpose |
|---|---|---|
| `Account` | Standard | Landlord accounts (business) and tenant person accounts |
| `Contact` | Standard | Tenant contacts (record type: Tenant Contact) |
| `Property__c` | Custom | Rental properties owned by a landlord Account |
| `Room__c` | Custom | Individual lettable rooms within a Property |
| `Tenancy__c` | Custom | Central agreement linking a Room to a Tenant; parent of Rent Payments |
| `Contract` | Standard | Formal rental agreement (record type: Rental Agreement) between landlord and tenant |
| `Rent_Payment__c` | Custom | Per-period rent invoice; master-detail child of Tenancy__c |
| `Notice__c` | Custom | Landlord-to-tenant notices surfaced in the Experience Cloud portal |
| `Payment_Detail__c` | Custom | Preferred payment method details for a tenant Account |
| `Case` | Standard | Tenant maintenance requests and complaints |

---

## 2. Object Relationships (ERD)

```
Account (Landlord)
  └─[Lookup: Landlord__c]──────────────► Property__c
                                              │
                            ┌─────────────────┼──────────────────────┐
                            │                 │                       │
                  [MD: Property__c]   [Lookup: Property__c]  [Lookup: Property__c]
                            │                 │                       │
                        Tenancy__c         Notice__c               Case
                            │    (All Tenants)
               ┌────────────┴────────────────────────────────┐
               │                                             │
    [MD: Tenancy__c]                              [Lookup: Tenancy__c]
               │                                             │
         Rent_Payment__c                               Notice__c (Specific Tenant)
                                                       Case

Tenancy__c also links to:
  ├─[Lookup: Room__c]       → Room__c   (filtered to same Property)
  ├─[Lookup: Tenant__c]     → Contact   (RecordType: Tenant Contact)
  ├─[Lookup: Tenant_Account__c] → Account (Person Account)
  ├─[Lookup: Community_User__c] → User   (Experience Cloud login)
  └─[Lookup: Contract__c]   → Contract  (Rental Agreement)

Contract links to:
  ├─[Required: AccountId]   → Account   (Landlord)
  ├─[Lookup: Tenant_Contact__c] → Contact (Tenant)
  └─[Lookup: Tenancy__c]    → Tenancy__c

Account (Person Account / Tenant)
  └─[MD: Account__c] → Payment_Detail__c
```

**Master-Detail Hierarchy (3 levels):**
```
Property__c  →  Tenancy__c  →  Rent_Payment__c
```

---

## 3. Object Reference

### Property__c
| Field | Type | Notes |
|---|---|---|
| Name | AutoNumber | PROP-{00000000} |
| Landlord__c | Lookup (Account) | Owner of the property |
| Property_Type__c | Picklist | House, Apartment, Unit, etc. |
| Address__c, City__c, State__c, Postcode__c, Country__c | Text | Address fields |
| Description__c | LongTextArea | Property description |
| Total_Rooms__c | Rollup COUNT | All rooms |
| Available_Rooms__c | Rollup COUNT | Rooms with Status = Available |
| Occupied_Rooms__c | Rollup COUNT | Rooms with Status = Occupied |

### Room__c
| Field | Type | Notes |
|---|---|---|
| Name | Text | Room number / name |
| Property__c | MasterDetail | Parent property |
| Room_Type__c | Picklist | Single, Double, Studio, etc. |
| Status__c | Picklist | Available, Occupied, Under Maintenance, Reserved |
| Weekly_Rent__c | Currency | Advertised rate (actual rent is on Tenancy) |
| Floor__c, Room_Size__c | Number | Physical details |
| Facilities__c | MultiSelectPicklist | Air Con, Wi-Fi, Parking, etc. |

### Tenancy__c
| Field | Type | Notes |
|---|---|---|
| Name | AutoNumber | TEN-{0000} |
| Property__c | MasterDetail | Sharing ControlledByParent |
| Room__c | Lookup (Room__c) | Filtered to same Property |
| Tenant__c | Lookup (Contact) | Filtered to RecordType = Tenant Contact |
| Tenant_Account__c | Lookup (Account) | Auto-populated from Tenant__r.AccountId |
| Community_User__c | Lookup (User) | Experience Cloud login |
| Contract__c | Lookup (Contract) | Linked Rental Agreement |
| Rent_Amount__c | Currency | Agreed rent amount |
| Rent_Frequency__c | Picklist | Weekly, Fortnightly, Monthly |
| Rent_Start_Date__c | Date | Tenancy commencement |
| Rent_End_Date__c | Date | Blank = periodic/rolling |
| Deposit_Amount__c | Currency | Security bond |
| Status__c | Picklist | Pending, Active, Expired, Terminated |
| Next_Due_Date__c | Formula (Date) | Next rent due date |
| **Total_Received__c** | Rollup SUM | Sum of Received Rent_Payment__c amounts |
| **Total_Arrears__c** | Rollup SUM | Sum of Overdue Rent_Payment__c amounts |
| **Total_Unpaid__c** | Rollup SUM | Sum of Unpaid Rent_Payment__c amounts |
| **Total_Scheduled__c** | Rollup SUM | Sum of Scheduled (upcoming) amounts |

### Contract (Standard — Record Type: Rental Agreement)
| Field | Type | Notes |
|---|---|---|
| Name | Auto | Contract number |
| AccountId | Lookup (Account) | Landlord Account (required) |
| Tenant_Contact__c | Lookup (Contact) | Tenant party |
| CustomerSignedId / Date / Title | Standard | Tenant signing details |
| CompanySignedId / Date | Standard | Landlord signing details |
| StartDate | Date | Contract commencement |
| EndDate | Date | Auto-calculated from ContractTerm OR manual |
| ContractTerm | Number | Months |
| Status | Picklist | Draft, In Approval Process, Activated, Terminated |
| Tenancy__c | Lookup (Tenancy__c) | Linked Tenancy record |
| Rent_Amount__c | Currency | Agreed rent (overrides Tenancy if set) |
| Rent_Frequency__c | Picklist | Weekly, Fortnightly, Monthly |
| Deposit_Amount__c | Currency | Security bond agreed |
| Void_Reason__c | Picklist | Breach of Contract, Non-Payment, etc. |
| Special_Conditions__c | LongTextArea | Additional contract terms |
| Description | LongTextArea | General description |

### Rent_Payment__c
| Field | Type | Notes |
|---|---|---|
| Name | AutoNumber | INV-{0000} |
| Tenancy__c | **MasterDetail** | Parent tenancy (sharing ControlledByParent) |
| Status__c | Picklist | Scheduled → Unpaid → Overdue / Pending Approval → Received / Void |
| Amount__c | Currency | Base rent for this period |
| GST_Amount__c | Currency | 10% GST if landlord is GST-registered |
| Total_Amount__c | Formula | Amount__c + GST_Amount__c |
| Invoice_Date__c | Date | Date invoice was generated |
| Due_Date__c | Date | Payment due date |
| Period_Start__c | Date | Start of the rent period |
| Period_End__c | Date | End of the rent period |
| Payment_Date__c | Date | Date payment was actually received |
| Payment_Reference__c | Text | Bank reference / receipt / transaction ID |
| **Comment__c** | LongTextArea | Tenant payment notes / proof description |

**Status Lifecycle:**
```
Batch creates → [Scheduled]
  → Due date arrives → [Unpaid]      (daily flow: Scheduled→Unpaid)
  → Past due        → [Overdue]      (manual or future flow)
  → Tenant pays     → [Paid]         (tenant sets manually)
  → Submit approval → [Pending Approval] (approval process initial action)
  → Landlord OK     → [Received]     (approval process final approval)
  → Landlord rejects→ [Unpaid]       (approval process final rejection)
  → Cancelled       → [Void]
```

### Notice__c
| Field | Type | Notes |
|---|---|---|
| Name | Text | Notice title |
| Notice_Type__c | Picklist | General Information, Urgent, Rent Reminder, Rent Arrears, Scheduled Maintenance, Rent Increase, Lease Renewal, Eviction Notice, Inspection Notice, Entry Notice, Breach of Contract, Contract Termination |
| Audience__c | Picklist | All Tenants in Property / Specific Tenant |
| Status__c | Picklist | Draft → Published → Archived |
| Property__c | Lookup | Required when Audience = All Tenants |
| Tenancy__c | Lookup | Required when Audience = Specific Tenant |
| Effective_Date__c | Date | When notice becomes visible |
| Expiry_Date__c | Date | Optional — when notice expires |
| Content__c | HTML | Rich text body for community portal |
| Email_Sent__c | Checkbox | Set to true when automated email was sent |
| Email_Sent_Date__c | DateTime | Timestamp when email was dispatched |

---

## 4. Automation & Flows

### Record-Triggered Flows

| Flow | Trigger | Purpose |
|---|---|---|
| Contract Activated – Activate Tenancy | Contract Status → Activated | Sets Tenancy Status = Active; Room Status = Occupied |
| Contract Voided – Terminate Tenancy | Contract Void_Reason__c set | Sets Tenancy = Terminated; Room = Available; sends termination email; creates Contract Termination Notice |
| Rent Payment Overdue – Create Arrears Notice | Rent_Payment__c Status → Overdue | Creates Rent Arrears Notice; sends overdue email to tenant |
| Notice Published – Send Email | Notice__c Status → Published | Sends email to tenant(s) based on Audience |

### Scheduled Flows (daily)

| Flow | Schedule | Purpose |
|---|---|---|
| Contract Expired – Expire Tenancy | Daily 1:00 AM | For each Activated Contract where EndDate ≤ Today: Tenancy = Expired, Room = Available |
| Rent Payment – Scheduled to Unpaid | Daily 1:30 AM | Transitions Rent Payments from Scheduled → Unpaid when Due Date arrives |
| Rent Payment Due Tomorrow – Send Reminder | Daily 8:00 AM | For each Scheduled/Unpaid payment due tomorrow: sends reminder email + creates Rent Reminder Notice |

### Copy Mailing to Billing Address
Record-triggered before-save flow on Account. When `Same_as_mailing_address__c = true`, copies PersonMailingAddress to BillingAddress for Person Account records.

---

## 5. Approval Process — Rent Payment

**Process:** `Rent Payment Approval`  
**Entry Criteria:** `Rent_Payment__c.Status__c = Paid`  
**Approver:** Record Owner (property manager / landlord)

| Stage | Action |
|---|---|
| **Initial Submission** | Status → Pending Approval; Email sent to landlord (PaymentPendingApproval template) |
| **Approved** | Status → Received; Email sent to tenant (PaymentApproved template) |
| **Rejected** | Status → Unpaid; Email sent to tenant (PaymentRejected template) |
| **Recalled** | Available to tenant if they need to resubmit |

**Tenant workflow:**
1. Make the actual payment (bank transfer, PayID, etc.)
2. Open the Rent Payment record in the portal
3. Set Status = Paid
4. Add Payment Reference and Comment (describe the payment)
5. Attach screenshot via Salesforce Files (optional but recommended)
6. Click Submit for Approval
7. Landlord reviews and approves/rejects

---

## 6. Apex Batch — Rent Payment Generator

**Class:** `RentPaymentBatch` (implements `Database.Batchable`)  
**Scheduler:** `RentPaymentScheduler` (implements `Schedulable`)  
**Default schedule:** Daily at 2:00 AM

**Logic:**
- Queries all `Active` Tenancies
- For each, derives rent amount and frequency from the linked Contract (if Activated) or from Tenancy fields
- Calculates the next due date(s) within a 30-day window
- Skips periods where a non-Void Rent Payment already exists (prevents duplicates for advance payers)
- Creates `Rent_Payment__c` records with `Status = Scheduled`

**Activation (one-time, Execute Anonymous):**
```apex
RentPaymentScheduler.scheduleDaily();
```

**Batch size:** 50 records per chunk.

---

## 7. Email Templates

All templates live in the **RentIt Notifications** public email folder (`RentIt_Notifications`).

| Template | Sent To | Trigger |
|---|---|---|
| `RentReminder` — Rent Payment Due Tomorrow | Tenant | Daily reminder flow (1 day before due) |
| `RentArrears` — Rent Payment Overdue | Tenant | Overdue flow (status → Overdue) |
| `PaymentPendingApproval` — Awaiting Approval | Landlord (owner) | Approval process initial submission |
| `PaymentApproved` — Payment Confirmed | Tenant | Approval process final approval |
| `PaymentRejected` — Payment Needs Attention | Tenant | Approval process final rejection |

All templates are HTML with merge fields referencing `Rent_Payment__c` and related records. The voided-contract termination email uses inline `emailSimple` action text with Tenancy/Contract merge fields.

---

## 8. Page Layouts

| Object | Layout | Key Sections |
|---|---|---|
| Contract | Rental Agreement Layout | Contract Info, Parties, Tenancy, Contract Terms, Signature, Termination, Additional Terms |
| Tenancy | Tenancy Layout | Information, Rent Terms, **Financial Summary** (rollup fields), System Info |
| Rent Payment | Rent Payment Layout | Invoice Details, Payment Period, **Payment Proof** (Comment__c), System Info |
| Notice | Notice Layout | Notice Information, Recipients, Notice Content, **Email Tracking**, System Info |
| Property | Property Layout | Information, Space Details (rollup counts) |
| Room | Room Layout | Information, Room information |

---

## 9. Permission Sets

### RentIt – Landlord
Assigned to: internal users (property managers, landlords)

**Object Permissions (CRUD):** Account, Contact, Property__c, Room__c, Tenancy__c, Rent_Payment__c, Notice__c, Contract, Case

**Key Custom Field Permissions:**
- All Contract custom fields (Tenancy__c, Rent_Amount__c, Rent_Frequency__c, Deposit_Amount__c, Special_Conditions__c, Void_Reason__c, Tenant_Contact__c)
- All Tenancy__c financial rollups (Total_Received__c, Total_Arrears__c, Total_Unpaid__c, Total_Scheduled__c) — read-only
- Rent_Payment__c.Comment__c
- Notice__c email tracking fields (Email_Sent__c, Email_Sent_Date__c) — read-only

**Record Type Visibility:** Contract.Rental_Agreement, Case.Complaint, Case.Maintenance_Request, PersonAccount.PersonAccount

**Tab Visibility:** Property, Room, Tenancy, Rent Payment, Notice, Account

---

## 10. Key Application Capabilities

| Capability | How It Works |
|---|---|
| **Automated rent invoice generation** | `RentPaymentBatch` runs daily, creates Scheduled invoices 30 days ahead based on Contract frequency |
| **Advance payment support** | Batch skips periods with existing non-Void payments; tenant can pay against a Scheduled record before it's due |
| **Financial visibility** | Tenancy shows Total Received, Arrears, Unpaid, and Scheduled amounts via rollup summary fields |
| **Rent reminder (1 day prior)** | Scheduled flow runs 8 AM daily; sends email and creates Rent Reminder Notice for payments due tomorrow |
| **Arrears notices** | When a payment transitions to Overdue, a Rent Arrears Notice is auto-published and email sent to tenant |
| **Payment approval workflow** | Tenant sets payment to Paid → submits for approval → landlord approves/rejects with full email trail |
| **Contract lifecycle automation** | Contract Activated → Tenancy Active + Room Occupied; Contract Expired → Tenancy Expired + Room Available |
| **Contract termination** | Setting Void_Reason__c → Tenancy Terminated + Room Available + termination email + Notice record |
| **Notice delivery** | Any Published Notice can trigger an email to specific tenant or all tenants in a property |
| **Multi-channel communication** | All key events (rent due, overdue, payment submitted, approved, rejected, terminated) generate both email and an in-portal Notice record |
| **Compliance audit trail** | Rent_Payment__c has field history tracking on Status; approval history is preserved on each record |
| **GST support** | When landlord Account has GST_Registered__c = true, GST_Amount__c (10%) is calculated on each invoice |
