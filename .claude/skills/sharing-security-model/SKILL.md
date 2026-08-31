---
description: Sharing, FLS, and guest-user access rules for the RentIT community. Use for any sharing rule, permission set, or profile change.
---

## Permission Sets
| Permission Set | File | License | Purpose |
|---|---|---|---|
| `RentIt_Tenant` | `RentIt_Tenant.permissionset-meta.xml` | Customer Community Plus | All tenant portal access |
| `RentIt_Landlord` | `RentIt_Landlord.permissionset-meta.xml` | Partner Community / Internal | Full internal + portal management |

## Guest User
- **Zero object access** — login and self-registration pages only
- Blocked objects: Invoice, Payment, Contract, Tenancy, Notice, Property, Room, Case, Contact, Account
- Never add object permissions to the Guest User profile

## Tenant (`RentIt_Tenant` permission set)

### Object Permissions
| Object | Create | Read | Edit | Delete |
|---|---|---|---|---|
| Account | — | ✓ | — | — |
| Contact | — | ✓ | — | — |
| Invoice__c | — | ✓ | — | — |
| Notice__c | — | ✓ | — | — |
| Payment__c | ✓ | ✓ | ✓ | — |
| Property__c | — | ✓ | — | — |
| Room__c | — | ✓ | — | — |
| Tenancy__c | — | ✓ | — | — |
| Case | ✓ | ✓ | ✓ | — |

Case record types visible: `Complaint`, `Maintenance_Request`

### FLS — Tenant-Editable Fields
Only these Payment fields are editable by tenants:
- `Payment__c.Comment__c`
- `Payment__c.Payment_Reference__c`

All other Payment fields (Amount, Status, Invoice, Tenancy, Payment_Date, Payment_Method, Payment_Type) are **read-only or not visible** to tenants. Enforce this in LWC / Flow — never expose Status to tenant input.

### FLS — Tenant-Readable Key Fields
- Invoice: `Balance_Due__c`, `GST_Amount__c`, `Period_End__c`, `Period_Start__c`, `Total_Amount__c`, `Total_Paid__c`
- Notice: `Content__c`, `Expiry_Date__c`
- Room: `Description__c`, `Facilities__c`, `Room_Size__c`, `Weekly_Rent__c`
- Tenancy: `Available_Credits__c`, `Deposit_Amount__c`, `Tenant_Account__c`, `Total_Credits__c`
- Property: `Country__c`, `Description__c`, `Postcode__c`, `State__c`
- Account: `ABN__c`, `GST_Number__c`, `GST_Registered__c`
- Case: `Property__c`, `Room__c`, `Tenancy__c`

**`Tenancy__c.Community_User__c` is NOT readable by tenants** — it is internal-only.

## Sharing Sets (Tenant record access)
Sharing Sets traverse `Tenancy__c.Community_User__c → User` to give tenants access to their own records:

| Object | Access | Traversal Path |
|---|---|---|
| Tenancy__c | Read | `Community_User__c = $User` |
| Invoice__c | Read | `Tenancy__c.Community_User__c = $User` |
| Payment__c | Read/Create | `Tenancy__c.Community_User__c = $User` |
| Notice__c | Read | `Tenancy__c.Community_User__c = $User` |
| Contract | Read | `Tenant__c.User = $User` (via Contact) |
| Case | Read/Create | `Contact.User = $User` |

**`Community_User__c` must be populated** after provisioning — without it, the tenant sees zero records.

## Landlord (`RentIt_Landlord` permission set)
- Full CRUD + View/Modify All on: Invoice__c, Notice__c, Payment__c, Payment_Detail__c, Property__c, Room__c, Tenancy__c, Contract
- Can read/write `Tenancy__c.Community_User__c` — used to link tenants after registration
- Sharing Rule keyed on Account (Landlord): grants access to all records under their Properties

## Rules & Checklist
- Never expose other tenants' or landlords' records — each sharing mechanism must be tenant/landlord-scoped
- Run the `security-reviewer` agent after any object exposure, sharing rule, or permission set change
- Apex controllers for community pages must use `with sharing` — verify with `System.runAs(tenantUser)` in tests
- Notices are system-generated — tenant perm set has no Create/Edit on Notice__c
- After self-registration: Landlord sets `Tenancy__c.Community_User__c` (or automate via Flow/Trigger on User creation)
