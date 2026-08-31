---
description: RentIT object model and relationships. Use for any work involving Property, Room, Contract, Tenancy, Invoice, Payment, Credit, Notice, Complaint, or Feedback.
---

## Object Hierarchy
```
Account (Landlord / PersonAccount Tenant)
 └── Property__c (lookup: Account)
      └── Room__c  (lookup: Property__c; Status: Available / Occupied)

Contact (Tenant)
 └── Contract (std; lookups: Tenant Contact, Landlord Account, Property__c, Room__c)
      └── Tenancy__c (one active per Contract)
           ├── Invoice__c   (generated per Rent Frequency)
           ├── Payment__c   (tenant-submitted; linked to Invoice or Tenancy directly)
           └── Notice__c    (system-generated: Reminder / Overdue)

Case (Complaint / Maintenance_Request — record types)
 └── lookups: Contact (Tenant), Case.Tenancy__c, Case.Property__c, Case.Room__c
```

## Key Fields

### Tenancy__c
| Field | Type | Notes |
|---|---|---|
| `Tenant__c` | Lookup (Contact) | The tenant contact |
| `Tenant_Account__c` | Lookup (Account) | The tenant's account |
| `Property__c` | Lookup (Property__c) | Property being rented |
| `Room__c` | Lookup (Room__c) | Populated when `Rent_a_room__c = true` |
| `Status__c` | Picklist | Active / Expired / Terminated |
| `Available_Credits__c` | Currency | Running credit balance (auto-applied to next Invoice) |
| `Total_Credits__c` | Roll-up/Formula | Lifetime credits earned |
| `Total_Credits_Applied__c` | Roll-up/Formula | Total credits used against invoices |
| `Deposit_Amount__c` | Currency | Initial deposit paid |
| `Total_Arrears__c` | Formula | Sum of unpaid Invoice balances |
| `Total_Received__c` | Roll-up | Sum of approved payments |
| `Total_Scheduled__c` | Roll-up | Sum of scheduled payments |
| `Total_Unpaid__c` | Formula | Total outstanding |
| **`Community_User__c`** | Lookup (User) | **Links tenancy to the portal user — must be set after tenant registers; drives Sharing Set access** |

### Invoice__c
| Field | Notes |
|---|---|
| `Period_Start__c`, `Period_End__c` | Billing period dates |
| `Total_Amount__c` | Rent amount for the period |
| `GST_Amount__c` | GST component |
| `Balance_Due__c` | Amount still owed (after credits applied) |
| `Total_Paid__c` | Sum of approved payments against this invoice |
| `Status__c` | Draft / Issued / Paid / Overdue |

### Payment__c
| Field | Tenant Editable | Notes |
|---|---|---|
| `Amount__c` | Yes (on create) | Payment amount |
| `Payment_Date__c` | Yes | Date of payment |
| `Payment_Method__c` | Yes | BSB/Bank Transfer/etc. |
| `Payment_Reference__c` | Yes | Bank reference number |
| `Comment__c` | Yes | Free-text note |
| `Invoice__c` | No | Invoice being paid |
| `Tenancy__c` | No | Parent tenancy |
| `Status__c` | No | Pending / Approved / Rejected (landlord-controlled) |
| `Payment_Type__c` | No | Rent / Deposit / Credit |

### Notice__c
| Field | Notes |
|---|---|
| `Content__c` | Notice body text |
| `Expiry_Date__c` | Date notice expires |
| `Tenancy__c` | Parent tenancy (auto-set by Flow) |
| Type | Rent Reminder / Rent Overdue (auto-created — tenants cannot create) |

### Case (Complaint / Maintenance_Request)
| Field | Notes |
|---|---|
| `Case.Tenancy__c` | Custom lookup to Tenancy__c |
| `Case.Property__c` | Custom lookup to Property__c |
| `Case.Room__c` | Custom lookup to Room__c |
| Record types | `Complaint`, `Maintenance_Request` — both visible to `RentIt_Tenant` perm set |

## Key Business Rules
- Invoice amount = Contract Rent Amount; cadence = Contract Rent Frequency
- On Invoice issue: apply `Tenancy__c.Available_Credits__c` before setting Balance_Due
- Payment > Balance_Due → excess becomes Credit on Tenancy
- Notices are system-generated (Flow/Apex) — tenants cannot create or edit them
- `Community_User__c` is the **only** field connecting a Tenancy to its community user; Sharing Sets traverse this field

## Experience Cloud Connection
- **`Tenancy__c.Community_User__c`** is the connector field for Experience Cloud
- Sharing Sets on `Tenancy__c` (and related Invoice, Payment, Notice) traverse `Community_User__c → User`
- The field is readable by `RentIt_Landlord` but **not visible to tenants** (not in `RentIt_Tenant` perm set)
- Workflow: Landlord creates Tenancy → tenant self-registers → Landlord sets `Community_User__c` → tenant gains access
