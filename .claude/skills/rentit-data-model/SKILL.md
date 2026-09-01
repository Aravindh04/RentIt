---
description: RentIT object model and relationships. Use for any work involving Property, Room, Contract, Tenancy, Invoice, Payment, Credit, Notice, Complaint, or Maintenance Request.
---

## Object Hierarchy

```
Account (Landlord)
 └── Property__c       (Landlord__c → Account)
      └── Room__c       (Property__c master-detail)

Tenancy__c             (Property__c lookup; Room__c lookup — optional)
 ├── Invoice__c        (Tenancy__c master-detail)
 │    └── Payment__c   (Tenancy__c master-detail; Invoice__c lookup — optional)
 └── Notice__c         (Tenancy__c lookup — optional)

Account (Tenant — PersonAccount)
 └── Payment_Detail__c (Account__c master-detail)

Contact (record type: Tenant Contact)
 └── Tenancy__c.Tenant__c (lookup)

Contract (standard)
 └── Tenancy__c  (Contract.Tenancy__c lookup — ONLY connection; no direct Property or Room lookup)

Case (record types: Complaint, Maintenance_Request)
 └── lookups: Tenancy__c, Property__c, Room__c
```

> **Contract → Property/Room**: Contract has NO direct lookup to Property__c or Room__c.
> Navigate via `Contract.Tenancy__c → Tenancy__c.Property__c` and `Tenancy__c.Room__c`.

---

## Objects & Key Fields

### Property__c
| Field | Type | Notes |
|---|---|---|
| `Name` | Text | Property Number (auto-name) |
| `Landlord__c` | Lookup → Account | deleteConstraint = SetNull |
| `Address__c` | Address (compound) | Includes Street, City, State, Postcode, Country sub-fields |
| `Property_Type__c` | Picklist (required) | House, Apartment, Unit, Townhouse, Villa, Studio, Granny Flat |
| `Description__c` | LongTextArea | |
| `Total_Rooms__c` | Summary COUNT | All Room__c child records |
| `Available_Rooms__c` | Summary COUNT | Rooms where Status = Available |
| `Occupied_Rooms__c` | Summary COUNT | Rooms where Status = Occupied |

### Room__c
| Field | Type | Notes |
|---|---|---|
| `Name` | Text | Room Number / Name |
| `Property__c` | MasterDetail → Property__c | Cascade-delete |
| `Room_Type__c` | Picklist (required) | Single, Double, Twin, Master Bedroom, Ensuite, Studio, Shared Room |
| `Status__c` | Picklist (required) | Available (default), Occupied, Under Maintenance, Reserved |
| `Floor__c` | Number | Floor level; 0 = ground |
| `Room_Size__c` | Number | Square metres |
| `Weekly_Rent__c` | Currency | Advertised rate (actual rent is on Tenancy via Contract) |
| `Facilities__c` | MultiselectPicklist | AC, Balcony, Bills Included, En-suite, Furnished, Garden, Gym, Heating, Kitchen, Laundry, Parking, Shared Bathroom, Storage, Pool, TV, Wi-Fi |
| `Description__c` | LongTextArea | |

### Tenancy__c
| Field | Type | Notes |
|---|---|---|
| `Name` | AutoNumber | TEN-{0000} |
| `Property__c` | Lookup → Property__c | deleteConstraint=SetNull; not master-detail (changed from MD) |
| `Room__c` | Lookup → Room__c | deleteConstraint=SetNull; lookup filter restricts to rooms in same Property; populated when `Rent_a_room__c = true` |
| `Tenant__c` | Lookup → Contact (required) | Lookup filter: RecordType.DeveloperName = Tenant_Contact |
| `Tenant_Account__c` | Lookup → Account | Denormalized mirror of Tenant__r.AccountId; auto-set by Flow |
| `Status__c` | Picklist (required) | Pending, Active (default), Expired, Terminated |
| `Rent_a_room__c` | Checkbox | When true, Room__c is populated |
| `Deposit_Amount__c` | Currency | Security bond |
| `Available_Credits__c` | Formula Currency | `Total_Credits__c - Total_Credits_Applied__c` |
| `Total_Credits__c` | Summary SUM | Payments where Type = Rent Payment AND Status = Received |
| `Total_Credits_Applied__c` | Summary SUM | Payments where Type = Credit Applied |
| `Total_Arrears__c` | Summary SUM | Invoices where Status = Overdue |
| `Total_Received__c` | Summary SUM | Invoices where Status = Paid |
| `Total_Unpaid__c` | Summary SUM | Invoices where Status = Unpaid |
| `Total_Scheduled__c` | Summary SUM | Invoices where Status = Scheduled |

### Invoice__c
| Field | Type | Notes |
|---|---|---|
| `Name` | AutoNumber | INV-{00000} |
| `Tenancy__c` | MasterDetail → Tenancy__c | Cascade-delete |
| `Amount__c` | Currency (required) | Rent excl. GST (sourced from Contract.Rent_Amount__c) |
| `GST_Amount__c` | Currency | 10% GST; set by batch when landlord Account.GST_Registered__c = true |
| `Total_Amount__c` | Formula Currency | `Amount__c + GST_Amount__c` |
| `Total_Paid__c` | Currency | Aggregate of Received payments; updated by PaymentTriggerHandler |
| `Balance_Due__c` | Formula Currency | `Total_Amount__c - Total_Paid__c` |
| `Status__c` | Picklist (required) | Scheduled, Unpaid (default), Overdue, Paid, Void |
| `Category__c` | Picklist (required) | Rent (default), Utilities |
| `Invoice_Date__c` | Date (required) | Date the batch created the invoice |
| `Due_Date__c` | Date (required) | Payment due date |
| `Period_Start__c` | Date | Start of billing period |
| `Period_End__c` | Date | End of billing period |

### Payment__c
| Field | Type | Tenant Editable | Notes |
|---|---|---|---|
| `Tenancy__c` | MasterDetail → Tenancy__c | No | Primary parent |
| `Invoice__c` | Lookup → Invoice__c | No | Optional; credit payments have no invoice |
| `Amount__c` | Currency (required) | Yes (on create) | |
| `Payment_Date__c` | Date (required) | Yes | Defaults to TODAY() |
| `Payment_Method__c` | Picklist (required) | Yes | Global value set: Cash, Pay ID (default), Bank Transfer, Credit |
| `Payment_Reference__c` | Text(255) | Yes | Bank transaction ID or receipt |
| `Comment__c` | LongTextArea | Yes | Free-text note |
| `Payment_Type__c` | Picklist (required) | No | Invoice Payment (default), Credit Payment, Rent Payment, Credit Applied |
| `Status__c` | Picklist (required) | No | Paid (default), Pending Approval, Received, Rejected |

### Payment_Detail__c
Stores saved payment method details for a tenant's Person Account. Not linked to individual payments.

| Field | Type | Notes |
|---|---|---|
| `Account__c` | MasterDetail → Account | Links to tenant Person Account |
| `Payment_Method__c` | Picklist | Global value set: Cash, Pay ID, Bank Transfer, Credit |
| `Payment_Information__c` | Text(255) | BSB/account number or PayID value |

### Notice__c
| Field | Type | Notes |
|---|---|---|
| `Name` | Text | Notice Title |
| `Property__c` | Lookup → Property__c | deleteConstraint=SetNull; required when Audience = All Tenants |
| `Tenancy__c` | Lookup → Tenancy__c | deleteConstraint=SetNull; used when Audience = Specific Tenant |
| `Audience__c` | Picklist (required) | All Tenants in Property (default), Specific Tenant |
| `Notice_Type__c` | Picklist (required) | General Information (default), Urgent, Scheduled Maintenance, Rent Increase, Lease Renewal, Eviction Notice, Inspection Notice, Entry Notice, Rent Reminder, Rent Arrears, Breach of Contract, Contract Termination |
| `Status__c` | Picklist (required) | Draft (default), Published, Archived |
| `Content__c` | Html (rich-text) | Body visible in portal |
| `Effective_Date__c` | Date (required) | Date notice becomes visible |
| `Expiry_Date__c` | Date | Leave blank for permanent notices |
| `Email_Sent__c` | Checkbox | Set true by Flow after email dispatch |
| `Email_Sent_Date__c` | DateTime | Timestamp of email send |

### Contract (standard — custom fields only)
| Field | Type | Notes |
|---|---|---|
| `Tenancy__c` | Lookup → Tenancy__c | **Only** custom relationship field; deleteConstraint=SetNull |
| `Tenant_Contact__c` | Lookup → Contact | Lookup filter: RecordType.DeveloperName = Tenant_Contact |
| `Rent_Amount__c` | Currency | Agreed rent per period; used by InvoiceBatch |
| `Rent_Frequency__c` | Picklist | Weekly (default), Fortnightly, Monthly; drives invoice cadence |
| `Deposit_Amount__c` | Currency | Security bond amount |
| `Special_Conditions__c` | LongTextArea | |
| `Void_Reason__c` | Picklist | Breach of Contract, Non-Payment of Rent, Property Damage, Abandonment, Illegal Activity, Mutual Agreement, Other |

Standard fields in use: `AccountId` (Landlord Account), `StartDate`, `EndDate`, `Status` (Draft → Activated → Expired/Terminated).
Record type: `Rental_Agreement`.

### Case (standard — custom fields only)
| Field | Type | Notes |
|---|---|---|
| `Tenancy__c` | Lookup → Tenancy__c | deleteConstraint=SetNull |
| `Property__c` | Lookup → Property__c | deleteConstraint=SetNull |
| `Room__c` | Lookup → Room__c | deleteConstraint=SetNull |

Record types: `Complaint`, `Maintenance_Request` — both visible to `RentIt_Tenant` permission set.

### Account (standard — custom fields only)
| Field | Type | Notes |
|---|---|---|
| `ABN__c` | Text(11) | Australian Business Number (landlords) |
| `GST_Number__c` | Text(20) | GST registration number |
| `GST_Registered__c` | Checkbox | When true, InvoiceBatch adds 10% GST to invoices |
| `Same_as_mailing_address__c` | Checkbox | Triggers Copy_Mailing_to_Billing_Address Flow |
| `Status__c` | Picklist | Active, Inactive, Pending (tenant Person Account lifecycle) |
| `Total_Payments_Received__c` | Currency | Sum of all Received payments; updated by PaymentTriggerHandler |

---

## Automation

### Apex
| Class | Role |
|---|---|
| `InvoiceBatch` | Daily batch — queries Activated Contracts with an Active Tenancy; generates Invoice__c records 1 day ahead. Auto-applies `Available_Credits__c` (marks invoice Paid + creates Credit Payment record). |
| `InvoiceBackfillBatch` | One-time backfill — iterates Contract.StartDate → today; creates missing invoices as Overdue; applies credits (Credit Applied Payment records). |
| `InvoiceScheduler` | Schedules InvoiceBatch daily at 2 AM (`0 0 2 * * ?`). |
| `PaymentTriggerHandler` | Before insert/update: populates Payment.Tenancy__c from Invoice.Tenancy__c when missing. After all DML: recalculates Invoice.Total_Paid__c and Account.Total_Payments_Received__c. |

### Flows
| Flow | Trigger | What It Does |
|---|---|---|
| `Contract_Activated_Activate_Tenancy` | Record After Save (Status → Activated) on Contract | Sets Tenancy.Status = Active; sets Room.Status = Occupied |
| `Contract_Expired_Expire_Tenancy` | Scheduled daily on Contract | When EndDate ≤ today: sets Tenancy = Expired, Room = Available, Contract = Expired |
| `Contract_Voided_Terminate_Tenancy` | Record After Save (Void_Reason__c newly set) on Contract | Sets Tenancy = Terminated, Room = Available; sends termination email; creates Contract Termination Notice record |
| `Copy_Mailing_to_Billing_Address` | Record Before Save on Account | When PersonAccount + Same_as_mailing_address__c = true: copies Mailing → Billing address |
| `Notice_Published_Send_Email` | Record After Save (Status → Published) on Notice__c | Sends email to Specific Tenant or loops all tenants in Property; sets Email_Sent__c = true |
| `Payment_Received_Set_Invoice_Paid` | Record After Save (Status → Received) on Payment__c | Sets linked Invoice.Status = Paid |
| `Rent_Invoice_Unpaid_Task_And_Email` | Record After Save (Status newly → Unpaid) on Invoice__c | Sends "Invoice Now Unpaid" email to tenant; creates follow-up Task on Tenancy (Priority Normal, due +7 days) |
| `Rent_Payment_Due_Tomorrow_Reminder` | Scheduled daily 8 AM on Invoice__c | For Scheduled/Unpaid invoices due tomorrow: sends reminder email + creates Rent Reminder Notice |
| `Rent_Payment_Overdue_Create_Notice` | Record After Save (Status newly → Overdue) on Invoice__c | Creates Rent Arrears Notice on Tenancy; sends arrears email to tenant; creates urgent follow-up Task (Priority High, due +3 days) |
| `Rent_Payment_Scheduled_To_Unpaid` | Scheduled daily on Invoice__c | Transitions Scheduled → Unpaid when Due_Date ≤ today |

### Approval Process
Payment__c has a landlord approval process:
- Entry: Status = Paid (tenant submits)
- Initial action: Status → Pending Approval
- Approve: Status → Received + email; Reject: Status → Rejected + email

---

## Key Business Rules
- Invoice amount and frequency come from `Contract.Rent_Amount__c` and `Contract.Rent_Frequency__c` — not stored on Tenancy
- `Available_Credits__c` is a formula: `Total_Credits__c − Total_Credits_Applied__c`; InvoiceBatch auto-applies it when generating invoices
- Payment > Balance_Due → excess flows back as a Credit Payment on the Tenancy
- Notices are system-created (Flows/Apex); tenants cannot create or edit them
- Room.Status is managed by Contract lifecycle Flows (Activate → Occupied; Expire/Void → Available)

---

## Experience Cloud Access
- Sharing Sets use `Tenancy__c.Tenant__c` (Contact lookup) matched against `User.ContactId` — the standard Customer Community Plus pattern
- Tenancy__c has its own OWD (no longer ControlledByParent — Property__c relationship is now a Lookup); shared with tenants via the Sharing Set
- Invoice__c and Payment__c are ControlledByParent children of Tenancy__c and inherit its sharing
- Notice__c (Specific Tenant) is shared via the indirect path `Notice__c.Tenancy__c.Tenant__c → User.ContactId`
- Contract is accessed via `RentItPortalDataHelper` (`without sharing` class) — Contract does not support community Sharing Sets or manual share records
- **Contract sharing with portal/external users**: the only supported mechanism is sharing the **Account** on the Contract; if the landlord Account is shared with the tenant user, the Contract becomes accessible
- **Activated Contracts are locked**: once `Status = Activated`, the Contract record is read-only in Salesforce and cannot be edited via UI or standard DML
- "All Tenants in Property" notices are shared via a criteria-based sharing rule (Published + Audience = All Tenants) to the `RentIt_Community_Tenants` public group
- Property__c (Private OWD) is shared read-only to all tenants via a criteria-based sharing rule; Room__c inherits via ControlledByParent

---

## Permission Sets Summary
| Permission Set | Objects | Notes |
|---|---|---|
| `RentIt_Landlord` | CRUD + Modify All / View All on all custom objects; Read+Create+Edit on Account, Case, Contact, Contract | Full portfolio management |
| `RentIt_Tenant` | Read-only on Account, Contact, Contract, Invoice__c, Notice__c, Property__c, Room__c, Tenancy__c; Create+Edit on Case and Payment__c | Contract access: ContractNumber, Status, StartDate, EndDate, Rent_Amount__c, Rent_Frequency__c, Deposit_Amount__c, Special_Conditions__c (all read-only). Property field: Address__c (compound). Editable Payment fields: Comment__c and Payment_Reference__c only |
