# RentIt — Data Model & Administration Guide

**API Version:** 62.0  
**Last Updated:** 2026-09-01  
**Author:** Aravindhan Vijayakumar

---

## Table of Contents
1. [Object Overview](#1-object-overview)
2. [Object Relationships (ERD)](#2-object-relationships-erd)
3. [Object Reference](#3-object-reference)
4. [Automation & Flows](#4-automation--flows)
5. [Approval Process — Rent Payment](#5-approval-process--rent-payment)
6. [Apex Batch — Invoice Generator](#6-apex-batch--invoice-generator)
7. [Email Templates](#7-email-templates)
8. [Page Layouts](#8-page-layouts)
9. [Permission Sets](#9-permission-sets)
10. [Key Application Capabilities](#10-key-application-capabilities)

---

## 1. Object Overview

| Object | Type | Purpose |
|---|---|---|
| `Account` | Standard | Landlord Person Accounts |
| `Contact` | Standard | Tenant contacts (record type: Tenant Contact) |
| `Property__c` | Custom | Rental properties owned by a landlord Account |
| `Room__c` | Custom | Individual lettable rooms within a Property |
| `Tenancy__c` | Custom | Central occupancy record linking a Property/Room to a Tenant; parent of Invoices and Payments |
| `Contract` | Standard | Formal rental agreement (record type: Rental Agreement) linked to a Tenancy |
| `Invoice__c` | Custom | Per-period rent invoice; master-detail child of Tenancy__c |
| `Payment__c` | Custom | Tenant-submitted payment record against an Invoice; master-detail child of Tenancy__c |
| `Notice__c` | Custom | Landlord-to-tenant notices surfaced in the Experience Cloud portal |
| `Payment_Detail__c` | Custom | Preferred payment method details stored against a tenant Account |
| `Case` | Standard | Tenant complaints and maintenance requests (record types: Complaint, Maintenance_Request) |

---

## 2. Object Relationships (ERD)

```
Account (Landlord)
  └─[Lookup: Landlord__c]──────────────► Property__c
                                              │
                            ┌─────────────────┼─────────────────────┐
                            │                 │                      │
              [Lookup: Property__c]   [Lookup: Property__c]  [Lookup: Property__c]
                            │                 │                      │
                        Tenancy__c         Notice__c              Case
                            │            (Audience: All Tenants)
         ┌──────────────────┼───────────────────────┐
         │                  │                       │
[MD: Tenancy__c]   [MD: Tenancy__c]       [Lookup: Tenancy__c]
         │                  │                       │
    Invoice__c          Payment__c            Notice__c (Specific Tenant)
         │                                    Case
[Lookup: Invoice__c]
         │
    Payment__c (optional — credit payments have no Invoice)

Tenancy__c also links to:
  ├─[Lookup: Room__c]            → Room__c   (filtered to same Property; optional)
  ├─[Lookup: Tenant__c]          → Contact   (RecordType: Tenant Contact; also drives portal access — see Sharing Set)
  └─[Lookup: Tenant_Account__c]  → Account   (Person Account; auto-set by Flow)


Contract (standard) links to:
  └─[Lookup: Tenancy__c]         → Tenancy__c (the ONLY custom-object relationship on Contract that related the Account (Landlord) and Contact   (Tenant))

Account (Person Account / Tenant)
  └─[MD: Account__c] → Payment_Detail__c
```

> **Important:** Contract has **no direct lookup to Property__c or Room__c**. Navigate via
> `Contract.Tenancy__c → Tenancy__c.Property__c` and `Tenancy__c.Room__c`.

**Master-Detail Hierarchy:**
```
Tenancy__c  →  Invoice__c
            →  Payment__c
```
> `Tenancy__c.Property__c` is a **Lookup** (not Master-Detail). Tenancy has its own OWD and sharing model.

---

## 3. Object Reference

### Property__c
| Field | Type | Notes |
|---|---|---|
| `Name` | Text | Property Number (standard name field) |
| `Landlord__c` | Lookup → Account | Owner of the property; deleteConstraint = SetNull |
| `Property_Type__c` | Picklist (required) | House, Apartment, Unit, Townhouse, Villa, Studio, Granny Flat |
| `Address__c` | Address (compound) | Includes Street, City, State, Postcode, Country sub-fields |
| `Description__c` | LongTextArea | Property description |
| `Total_Rooms__c` | Rollup COUNT | All Room__c child records |
| `Available_Rooms__c` | Rollup COUNT | Rooms where Status = Available |
| `Occupied_Rooms__c` | Rollup COUNT | Rooms where Status = Occupied |

### Room__c
| Field | Type | Notes |
|---|---|---|
| `Name` | Text | Room number / name |
| `Property__c` | MasterDetail → Property__c | Cascade-deletes rooms when Property is deleted |
| `Room_Type__c` | Picklist (required) | Single, Double, Twin, Master Bedroom, Ensuite, Studio, Shared Room |
| `Status__c` | Picklist (required) | Available (default), Occupied, Under Maintenance, Reserved |
| `Floor__c` | Number | Floor level; 0 = ground floor |
| `Room_Size__c` | Number | Square metres |
| `Weekly_Rent__c` | Currency | Advertised rate — actual rent is stored on Contract |
| `Facilities__c` | MultiselectPicklist | AC, Balcony, Bills Included, En-suite, Furnished, Garden, Gym, Heating, Kitchen, Laundry, Parking, Shared Bathroom, Storage, Pool, TV, Wi-Fi |
| `Description__c` | LongTextArea | |

Room `Status__c` is managed by Contract lifecycle Flows: Activated → Occupied; Expired/Voided → Available.

### Tenancy__c
| Field | Type | Notes |
|---|---|---|
| `Name` | AutoNumber | TEN-{0000} |
| `Property__c` | Lookup → Property__c | deleteConstraint = SetNull; changed from Master-Detail — Tenancy now has its own OWD |
| `Room__c` | Lookup → Room__c | Optional; filtered to rooms in same Property; populated when `Rent_a_room__c = true` |
| `Tenant__c` | Lookup → Contact (required) | Filtered to RecordType.DeveloperName = Tenant_Contact |
| `Tenant_Account__c` | Lookup → Account | Denormalized mirror of Tenant__r.AccountId; auto-set by Flow |
| `Status__c` | Picklist (required) | Pending, Active (default), Expired, Terminated |
| `Rent_a_room__c` | Checkbox | When true, Room__c should be populated |
| `Deposit_Amount__c` | Currency | Security bond |
| `Available_Credits__c` | Formula Currency | `Total_Credits__c − Total_Credits_Applied__c` |
| `Total_Credits__c` | Rollup SUM | Payments where Type = Rent Payment AND Status = Received |
| `Total_Credits_Applied__c` | Rollup SUM | Payments where Type = Credit Applied |
| `Total_Arrears__c` | Rollup SUM | Invoices where Status = Overdue |
| `Total_Received__c` | Rollup SUM | Invoices where Status = Paid |
| `Total_Unpaid__c` | Rollup SUM | Invoices where Status = Unpaid |
| `Total_Scheduled__c` | Rollup SUM | Invoices where Status = Scheduled |

> Rent amount, frequency, start date, and end date live on **Contract** — not on Tenancy.

### Contract (Standard — Record Type: Rental Agreement)
| Field | Type | Notes |
| `Tenancy__c` | Lookup → Tenancy__c | Links a Contract with Account (Landlord) and Contact (Tenant) | **Only** custom-object relationship on Contract; deleteConstraint = SetNull |
| `StartDate` | Date | Contract commencement |
| `EndDate` | Date | Contract end date |
| `ContractTerm` | Number | Term in months |
| `Status` | Picklist | Draft → Activated → Expired / Terminated |
| `Rent_Amount__c` | Currency | Agreed rent per period; used by InvoiceBatch to generate Invoice__c amounts |
| `Rent_Frequency__c` | Picklist | Weekly (default), Fortnightly, Monthly; determines invoice cadence |
| `Deposit_Amount__c` | Currency | Security bond agreed |
| `Void_Reason__c` | Picklist | Breach of Contract, Non-Payment of Rent, Property Damage, Abandonment, Illegal Activity, Mutual Agreement, Other |
| `Special_Conditions__c` | LongTextArea | Additional contract terms |

> Contract has **no lookup to Property__c or Room__c**. Those are reached via `Contract.Tenancy__c`.

> **Contract sharing with portal/external users**: The only supported mechanism is sharing the **Account** on the Contract with the external user. Sharing Sets and manual share records are not available for Contract.

> **Activated Contract is locked**: Once `Status = Activated`, the Contract record becomes read-only in Salesforce. It cannot be edited via UI or standard DML.

### Invoice__c
| Field | Type | Notes |
|---|---|---|
| `Name` | AutoNumber | INV-{00000} |
| `Tenancy__c` | MasterDetail → Tenancy__c | Primary parent; cascade-delete |
| `Amount__c` | Currency (required) | Base rent excl. GST; sourced from Contract.Rent_Amount__c by InvoiceBatch |
| `GST_Amount__c` | Currency | 10% GST; populated by InvoiceBatch when landlord Account.GST_Registered__c = true |
| `Total_Amount__c` | Formula Currency | `Amount__c + GST_Amount__c` |
| `Total_Paid__c` | Currency | Aggregate of Received payments; updated by PaymentTriggerHandler after each payment DML |
| `Balance_Due__c` | Formula Currency | `Total_Amount__c − Total_Paid__c` |
| `Status__c` | Picklist (required) | Scheduled, Unpaid (default), Overdue, Paid, Void |
| `Category__c` | Picklist (required) | Rent (default), Utilities |
| `Invoice_Date__c` | Date (required) | Date the batch generated this invoice |
| `Due_Date__c` | Date (required) | Payment due date |
| `Period_Start__c` | Date | Start of the billing period |
| `Period_End__c` | Date | End of the billing period |

**Invoice Status Lifecycle:**
```
InvoiceBatch creates → [Scheduled]
  → Due_Date__c arrives → [Unpaid]   (daily scheduled flow)
  → Past due           → [Overdue]   (manual or future automation)
  → Payment Received   → [Paid]      (Payment_Received_Set_Invoice_Paid flow)
  → Cancelled          → [Void]
```

### Payment__c
| Field | Type | Tenant Editable | Notes |
|---|---|---|---|
| `Tenancy__c` | MasterDetail → Tenancy__c | No | Primary parent |
| `Invoice__c` | Lookup → Invoice__c | No | Optional — credit payments have no linked invoice |
| `Amount__c` | Currency (required) | Yes (on create) | Payment amount |
| `Payment_Date__c` | Date (required) | Yes | Defaults to TODAY() |
| `Payment_Method__c` | Picklist (required) | Yes | Global value set: Cash, Pay ID (default), Bank Transfer, Credit |
| `Payment_Reference__c` | Text(255) | Yes | Bank transaction ID or receipt number |
| `Comment__c` | LongTextArea | Yes | Tenant notes; attach proof via Salesforce Files |
| `Payment_Type__c` | Picklist (required) | No | Invoice Payment (default), Credit Payment, Rent Payment, Credit Applied |
| `Status__c` | Picklist (required) | No | Paid (default), Pending Approval, Received, Rejected |

**Payment Status Lifecycle:**
```
Tenant submits → [Paid]
  → Approval process initial action → [Pending Approval]
  → Landlord approves              → [Received]
  → Landlord rejects               → [Rejected]
```

When `Status = Received` and `Payment_Type = Invoice Payment`: the linked `Invoice__c.Status` is set to **Paid** by the `Payment_Received_Set_Invoice_Paid` flow.

### Payment_Detail__c
Stores a tenant's saved payment method details. Not linked to individual Payment records.

| Field | Type | Notes |
|---|---|---|
| `Account__c` | MasterDetail → Account | Parent tenant Person Account |
| `Payment_Method__c` | Picklist | Global value set: Cash, Pay ID, Bank Transfer, Credit |
| `Payment_Information__c` | Text(255) | BSB/account number or PayID value |

### Notice__c
| Field | Type | Notes |
|---|---|---|
| `Name` | Text | Notice title |
| `Notice_Type__c` | Picklist (required) | General Information (default), Urgent, Scheduled Maintenance, Rent Increase, Lease Renewal, Eviction Notice, Inspection Notice, Entry Notice, Rent Reminder, Rent Arrears, Breach of Contract, Contract Termination |
| `Audience__c` | Picklist (required) | All Tenants in Property (default), Specific Tenant |
| `Status__c` | Picklist (required) | Draft (default), Published, Archived |
| `Property__c` | Lookup → Property__c | Required when Audience = All Tenants |
| `Tenancy__c` | Lookup → Tenancy__c | Required when Audience = Specific Tenant |
| `Effective_Date__c` | Date (required) | When notice becomes visible in the portal |
| `Expiry_Date__c` | Date | Optional — leave blank for permanent notices |
| `Content__c` | HTML (rich-text) | Notice body displayed in the community portal |
| `Email_Sent__c` | Checkbox | Set true by Flow after email dispatch |
| `Email_Sent_Date__c` | DateTime | Timestamp of email send |

### Case (Standard — Custom Fields)
| Field | Type | Notes |
|---|---|---|
| `Tenancy__c` | Lookup → Tenancy__c | deleteConstraint = SetNull |
| `Property__c` | Lookup → Property__c | deleteConstraint = SetNull |
| `Room__c` | Lookup → Room__c | deleteConstraint = SetNull |

Record types: `Complaint`, `Maintenance_Request` — both accessible to tenants via the `RentIt_Tenant` permission set.

### Account (Standard — Custom Fields)
| Field | Type | Notes |
|---|---|---|
| `ABN__c` | Text(11) | Australian Business Number (landlords) |
| `GST_Number__c` | Text(20) | GST registration number |
| `GST_Registered__c` | Checkbox | When true, InvoiceBatch adds 10% GST to each Invoice |
| `Same_as_mailing_address__c` | Checkbox | Triggers Copy_Mailing_to_Billing_Address Flow |
| `Status__c` | Picklist | Active, Inactive, Pending — tenant Person Account lifecycle |
| `Total_Payments_Received__c` | Currency | Sum of all Received payments across all tenancies; updated by PaymentTriggerHandler |

---

## 4. Automation & Flows

### Record-Triggered Flows

| Flow | Trigger Object | Trigger Condition | Purpose |
|---|---|---|---|
| Contract Activated – Activate Tenancy | Contract | Status → Activated | Sets Tenancy.Status = Active; Room.Status = Occupied |
| Contract Voided – Terminate Tenancy | Contract | Void_Reason__c newly set | Sets Tenancy = Terminated; Room = Available; sends termination email; creates Contract Termination Notice record |
| Notice Published – Send Email | Notice__c | Status → Published | Sends email to Specific Tenant or loops all tenants in Property; sets Email_Sent__c = true and Email_Sent_Date__c |
| Payment Received – Set Invoice Paid | Payment__c | Status → Received | Sets linked Invoice__c.Status = Paid |
| Rent Invoice Unpaid – Task and Email | Invoice__c | Status newly → Unpaid | Sends "Invoice Now Unpaid" reminder email to tenant; creates a follow-up Task on Tenancy (Priority Normal, ActivityDate = today + 7 days) |
| Rent Payment Overdue – Create Arrears Notice | Invoice__c | Status newly → Overdue | Creates a Rent Arrears Notice on the Tenancy; sends overdue email to tenant; creates an urgent follow-up Task on Tenancy (Priority High, ActivityDate = today + 3 days) |
| Copy Mailing to Billing Address | Account | Before Save | When PersonAccount + Same_as_mailing_address__c = true + Mailing populated: copies Mailing → Billing address |

### Scheduled Flows (daily)

| Flow | Schedule | Purpose |
|---|---|---|
| Contract Expired – Expire Tenancy | Daily | For each Activated Contract where EndDate ≤ Today: Tenancy = Expired, Room = Available, Contract = Expired |
| Rent Payment – Scheduled to Unpaid | Daily | Transitions Invoice__c from Scheduled → Unpaid when Due_Date__c ≤ Today |
| Rent Payment Due Tomorrow – Send Reminder | Daily 8:00 AM | For each Scheduled/Unpaid Invoice due tomorrow: sends reminder email + creates Rent Reminder Notice |

---

## 5. Approval Process — Rent Payment

**Object:** `Payment__c`  
**Entry Criteria:** `Payment__c.Status__c = Paid` (tenant sets this when submitting)  
**Approver:** Landlord (record owner / assigned user)

| Stage | Action |
|---|---|
| **Initial Submission** | Status → Pending Approval; email sent to landlord |
| **Approved** | Status → Received; email sent to tenant; linked Invoice Status set to Paid by Flow |
| **Rejected** | Status → Rejected; email sent to tenant |
| **Recalled** | Tenant can recall if they need to correct and resubmit |

**Tenant workflow:**
1. Make the actual payment (bank transfer, PayID, etc.)
2. Open the Payment record in the portal
3. Set Status = Paid
4. Add Payment Reference and Comment (describe the payment)
5. Attach screenshot via Salesforce Files (optional but recommended)
6. Submit for Approval
7. Landlord reviews and approves or rejects

---

## 6. Apex Batch — Invoice Generator

**Class:** `InvoiceBatch` (implements `Database.Batchable`)  
**Scheduler:** `InvoiceScheduler` (implements `Schedulable`)  
**Default schedule:** Daily at 2:00 AM (`0 0 2 * * ?`)  
**Job name:** `RentIt - Daily Invoice Generator`

**Logic:**
- Queries all Activated Contracts where the linked `Tenancy__c.Status__c = Active`
- Looks 1 day ahead (`LOOKAHEAD_DAYS = 1`) to find the next upcoming period
- Skips periods where an Invoice with matching `Period_Start__c` already exists (prevents duplicates)
- Creates `Invoice__c` records with `Status = Scheduled`
- If `Tenancy__c.Available_Credits__c >= Invoice Amount`: marks invoice as **Paid** immediately and creates a matching `Payment__c` record (`Payment_Type__c = Credit Payment`, `Status = Received`)

**Backfill class:** `InvoiceBackfillBatch` — iterates from Contract.StartDate to today, creating any missing invoices as Overdue and applying existing credits against them (creates Credit Applied Payment records). Used for onboarding existing tenancies.

**Activation (one-time, Execute Anonymous):**
```apex
System.schedule('RentIt - Daily Invoice Generator', '0 0 2 * * ?', new InvoiceScheduler());
```

---

## 7. Email Templates

All templates are in the **RentIt Notifications** email folder.

| Template | Sent To | Trigger |
|---|---|---|
| Rent Reminder — Due Tomorrow | Tenant | Daily scheduled flow (1 day before Due_Date__c) |
| Rent Payment Reminder — Invoice Now Unpaid | Tenant | Rent Invoice Unpaid – Task and Email flow (Status → Unpaid) |
| Rent Arrears — Invoice Overdue | Tenant | Invoice Overdue flow (Status → Overdue) |
| Payment Pending Approval | Landlord | Approval process initial submission |
| Payment Approved | Tenant | Approval process — final approval |
| Payment Rejected | Tenant | Approval process — final rejection |
| Contract Termination | Tenant | Contract Voided – Terminate Tenancy flow |

---

## 8. Page Layouts

| Object | Layout | Key Sections |
|---|---|---|
| Contract | Rental Agreement Layout | Contract Info, Parties (Landlord + Tenant), Tenancy, Contract Terms, Termination, Additional Terms |
| Tenancy | Tenancy Layout | Information, Financial Summary (rollup fields), System Info |
| Invoice__c | Invoice Layout | Invoice Details, Payment Period (Period_Start/End), Financials (Amount, GST, Balance Due), System Info |
| Payment__c | Payment Layout | Payment Info, Proof (Comment__c, Payment_Reference__c), System Info |
| Notice__c | Notice Layout | Notice Information, Recipients, Content, Email Tracking, System Info |
| Property__c | Property Layout | Information, Room Summary (rollup counts) |
| Room__c | Room Layout | Information, Room Details |

---

## 9. Permission Sets

### RentIt_Landlord
Assigned to: internal users (property managers, landlords)

**Object Permissions:** CRUD + Modify All / View All on Invoice__c, Notice__c, Payment__c, Payment_Detail__c, Property__c, Room__c, Tenancy__c. Read + Create + Edit on Account, Case, Contact, Contract.

**Notable field access:**
- All Contract custom fields (Tenancy__c, Rent_Amount__c, Rent_Frequency__c, Deposit_Amount__c, Special_Conditions__c, Void_Reason__c) — `Tenant_Contact__c` is dormant/unused
- All Tenancy__c financial rollups (Total_Received__c, Total_Arrears__c, Total_Unpaid__c, Total_Scheduled__c, Total_Credits__c) — read-only
- Notice__c email tracking fields (Email_Sent__c, Email_Sent_Date__c) — read-only

**Record Type Visibility:** Contract.Rental_Agreement, Case.Complaint, Case.Maintenance_Request, PersonAccount

### RentIt_Tenant (Community)
Assigned to: Experience Cloud community users

**Object Permissions:** Read-only on Account, Contact, Contract, Invoice__c, Notice__c, Property__c, Room__c, Tenancy__c. Create + Edit on Case and Payment__c. No delete on any object.

**Contract field access (all read-only):** ContractNumber, Status, StartDate, EndDate, Tenancy__c, Rent_Amount__c, Rent_Frequency__c, Deposit_Amount__c, Special_Conditions__c.

**Editable fields on Payment__c:** Comment__c and Payment_Reference__c only (all other fields are read-only after creation).

**Property field access:** Address__c (compound — grants access to all sub-fields: Street, City, State, PostalCode, Country).

**No access to:** ABN/GST fields on Account; Tenancy rollups beyond Available_Credits__c and Deposit_Amount__c; Notice tracking fields; Contract.Void_Reason__c.

**Record Type Visibility:** Case.Complaint, Case.Maintenance_Request

---

## 10. Key Application Capabilities

| Capability | How It Works |
|---|---|
| **Automated rent invoice generation** | `InvoiceBatch` runs daily, creates Scheduled invoices 1 day ahead based on Contract Rent_Frequency__c |
| **Credit auto-application** | If Available_Credits__c ≥ invoice amount, InvoiceBatch marks the invoice Paid and creates a Credit Payment record automatically |
| **Advance payment support** | Batch checks for existing Invoice at Period_Start__c before creating; existing invoices are never duplicated |
| **Financial visibility** | Tenancy shows Total Received, Arrears, Unpaid, and Scheduled via rollup summary fields on Invoice__c; Available Credits via formula |
| **Rent reminder (1 day prior)** | Scheduled flow at 8 AM sends email and creates Rent Reminder Notice for Invoices due tomorrow |
| **Unpaid invoice notification** | When an Invoice transitions to Unpaid, an email is sent to the tenant and a follow-up Task (due in 7 days, Priority Normal) is created on the Tenancy |
| **Arrears notices and tasks** | When an Invoice transitions to Overdue, a Rent Arrears Notice is auto-published, an email is sent to the tenant, and an urgent follow-up Task (due in 3 days, Priority High) is created on the Tenancy |
| **Payment approval workflow** | Tenant sets Payment to Paid → submits for approval → landlord approves/rejects; Invoice marked Paid on approval |
| **Contract lifecycle automation** | Contract Activated → Tenancy Active + Room Occupied; Contract Expired → Tenancy Expired + Room Available |
| **Contract termination** | Setting Void_Reason__c → Tenancy Terminated + Room Available + termination email + Notice record |
| **Notice delivery** | Published Notices trigger email to Specific Tenant or all tenants in a Property |
| **Multi-channel communication** | All key events (rent due, overdue, payment submitted, approved, rejected, terminated) generate both email and an in-portal Notice record |
| **GST support** | When landlord Account has GST_Registered__c = true, InvoiceBatch calculates GST_Amount__c (10%) on each Invoice |
| **Experience Cloud access control** | Sharing Sets match `Tenancy__c.Tenant__c` (Contact) to `User.ContactId`. Tenancy__c has its own OWD (Property__c is now a Lookup, not Master-Detail). Invoice__c and Payment__c are ControlledByParent children of Tenancy__c and inherit sharing. Specific-Tenant notices share via `Notice__c.Tenancy__c.Tenant__c`. Contract does not support community Sharing Sets or manual share records — the only native mechanism is sharing the Contract's **Account** with the external user. Portal access is handled via `RentItPortalDataHelper` (`without sharing`) with tenancy-ownership validation. Activated Contracts are locked (read-only) in Salesforce. All-Tenants notices share via a criteria-based sharing rule to the `RentIt_Community_Tenants` public group. |
