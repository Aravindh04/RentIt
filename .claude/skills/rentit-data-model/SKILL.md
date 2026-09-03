---
description: RentIT object model and relationships. Use for any work involving Property, Room, Contract, Tenancy, Invoice, Payment, Credit, Notice, Complaint, or Maintenance Request.
---

## Object Hierarchy

```
Account (Landlord)
 └── Property__c       (Landlord__c → Account)
      └── Room__c       (Property__c master-detail)

Tenancy__c             (Property__c lookup; Room__c lookup — optional)
 ├── Discount__c       (Tenancy__c master-detail; Contract__c lookup — optional)
 ├── Invoice__c        (Tenancy__c master-detail; Discount__c lookup — optional)
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
| `Status__c` | Picklist (required) | Pending, Active (default), Expired, Terminated |
| `Rent_a_room__c` | Checkbox | When true, Room__c is populated |
| `Available_Credits__c` | Formula Currency | `Total_Credits__c - Total_Credits_Applied__c` |
| `Total_Credits__c` | Summary SUM | Payments where Type = Rent Payment AND Status = Received |
| `Total_Credits_Applied__c` | Summary SUM | Payments where Type = Credit Applied |
| `Total_Arrears__c` | Summary SUM | Invoices where Status = Overdue |
| `Total_Received__c` | Summary SUM | Invoices where Status = Paid |
| `Total_Unpaid__c` | Summary SUM | Invoices where Status = Unpaid |
| `Total_Scheduled__c` | Summary SUM | Invoices where Status = Scheduled |

### Discount__c
Child of `Tenancy__c` (MasterDetail). Landlord-created; tenants have no object access.

| Field | Type | Notes |
|---|---|---|
| `Name` | Text | E.g. "10% Off — Sept 2026" |
| `Tenancy__c` | MasterDetail → Tenancy__c | Always required; sharingModel = ControlledByParent |
| `Contract__c` | Lookup → Contract | Optional — null = applies to any contract on the tenancy |
| `Discount_Type__c` | Picklist (required) | Percentage, Fixed Amount |
| `Discount_Value__c` | Number(18,2) (required) | For Percentage: 10 = 10%; for Fixed Amount: dollar value per full frequency period |
| `Start_Date__c` | Date (required) | First calendar day the discount is active |
| `End_Date__c` | Date | Last calendar day the discount is active; null = open-ended |
| `Description__c` | LongTextArea | Internal notes |

### Invoice__c
| Field | Type | Notes |
|---|---|---|
| `Name` | AutoNumber | INV-{00000} |
| `Tenancy__c` | MasterDetail → Tenancy__c | Cascade-delete |
| `Amount__c` | Currency (required) | **Original** rent excl. GST (sourced from Contract.Rent_Amount__c); never modified by discounts |
| `Discount_Amount__c` | Currency | Dollar amount of applied discount (pro-rated); null if no discount |
| `Discount__c` | Lookup → Discount__c | Primary discount that contributed; null if no discount; deleteConstraint=SetNull |
| `GST_Amount__c` | Currency | 10% GST; set by batch when landlord Account.GST_Registered__c = true |
| `Total_Amount__c` | Formula Currency | `(Amount__c - Discount_Amount__c) + IF(ISNULL(GST_Amount__c), 0, GST_Amount__c)` — the amount to pay |
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
| `InvoiceBatch` | Daily batch — queries Activated Contracts with an Active Tenancy; generates Invoice__c records 1 day ahead. Calls `DiscountCalculator` to set `Discount_Amount__c`. Auto-applies `Available_Credits__c` (marks invoice Paid + creates Credit Applied payment for `Amount - Discount`). |
| `InvoiceBackfillBatch` | One-time backfill — iterates Contract.StartDate → today; creates missing invoices; applies discounts and credits. |
| `InvoiceDiscountBackfillBatch` | Retroactively applies Discount__c records to existing invoices and their Credit Applied payments. Batches over Tenancy__c; queries overlapping invoices; calls `DiscountCalculator` per invoice; updates `Discount_Amount__c` and syncs Credit Applied payment amounts. |
| `DiscountCalculator` | Stateless service class. `apply(invoiceAmount, periodStart, periodEnd, contractId, discounts)` → `Result{discountAmount, primaryDiscountId}`. Pro-rates discount by calendar-day overlap; accumulates multiple discounts; clamps at invoice amount. Used by all batch classes. |
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
- `Invoice.Amount__c` is always the **original** rent; discounts are stored separately in `Discount_Amount__c`; `Total_Amount__c = (Amount - Discount) + GST` is the amount to pay
- Discount pro-ration: if a discount covers only N of M invoice days, `DiscountCalculator` applies the reduction proportionally (day-level granularity)
- Multiple `Discount__c` records for the same tenancy accumulate; `Invoice.Discount__c` lookup points to the first contributing discount
- Credit Applied payment amount = `Invoice.Amount__c - Invoice.Discount_Amount__c` (i.e. matches `Total_Amount__c` when GST = 0)
- `Available_Credits__c` is a formula: `Total_Credits__c − Total_Credits_Applied__c`; InvoiceBatch auto-applies it when generating invoices
- Payment > Balance_Due → excess flows back as a Credit Payment on the Tenancy
- Notices are system-created (Flows/Apex); tenants cannot create or edit them
- Room.Status is managed by Contract lifecycle Flows (Activate → Occupied; Expire/Void → Available)

---

## Experience Cloud Access

### Tenancy__c Sharing (Sharing Set)
`Tenancy__c.Property__c` is a **Lookup** (not MasterDetail), so Tenancy has its own OWD (Private). Tenant portal access is granted declaratively via the Sharing Set (`RentIt_Tenant_Sharing_Set`): `Tenant__c (Contact) → User.ContactId` → Read. Re-evaluates automatically when `Tenant__c` changes — no Apex trigger required.
- `Invoice__c` and `Payment__c` are `ControlledByParent` children of Tenancy and inherit its sharing automatically
- Landlords have `modifyAllRecords: true` on Tenancy__c via `RentIt_Landlord` — no extra sharing needed

### Other Objects
- `Notice__c` (Specific Tenant) — shared via Sharing Set: `Notice__c.Tenancy__c.Tenant__c → User.ContactId`
- `Notice__c` (All Tenants in Property) — criteria-based sharing rule (Status = Published + Audience = All Tenants) to the `RentIt_Community_Tenants` public group
- `Property__c` (Private OWD) — shared read-only to all tenants via a criteria-based sharing rule; `Room__c` inherits via ControlledByParent
- `Contract` — accessed via `RentItPortalDataHelper` (`without sharing`); **Activated Contracts are locked** (read-only once Status = Activated)

---

## Permission Sets Summary
| Permission Set | Objects | Notes |
|---|---|---|
| `RentIt_Landlord` | CRUD + Modify All / View All on all custom objects including Discount__c; Read+Create+Edit on Account, Case, Contact, Contract | Full portfolio management. All Discount__c fields editable. Invoice discount fields (Discount__c lookup, Discount_Amount__c) read-only (set by batch). |
| `RentIt_Tenant` | Read-only on Account, Contact, Contract, Invoice__c, Notice__c, Property__c, Room__c, Tenancy__c; Create+Edit on Case and Payment__c; no access to Discount__c object | Invoice discount fields readable (tenant sees saving). Contract access: ContractNumber, Status, StartDate, EndDate, Rent_Amount__c, Rent_Frequency__c, Deposit_Amount__c, Special_Conditions__c (all read-only). Property field: Address__c (compound). Editable Payment fields: Comment__c and Payment_Reference__c only |
