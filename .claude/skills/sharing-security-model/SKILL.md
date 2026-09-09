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

---

## Permission Set Rules

### Field-Level Security — generally not required to be defined
Since the Salesforce Winter '23 release, Permission Sets and Profiles do not need explicit `<fieldPermissions>` entries for most fields — access is effectively governed by object-level CRUD plus what the portal's Apex controllers/LWCs and page layouts actually expose, not by declaring FLS up front. Treat `<fieldPermissions>` blocks as the exception, not the default:
- **Required fields** — Salesforce automatically grants Read and Edit to any field marked `required=true` on the object definition, for every user who has at minimum Read CRUD on the object. Never add these.
- **New custom fields in general** — don't add a permission set `<fieldPermissions>` entry unless there's a specific reason a user needs to see/edit that field through a UI surface that enforces FLS (e.g. standard list views, "Set Field-Level Security" page). Fields only ever read via targeted Apex SOQL (explicit field lists) or omitted from Lightning/community page layouts stay effectively hidden from tenants regardless of FLS state, so don't bother granting or denying — just don't add an entry.
- Example: `Notice__c.Notice_Comment__c` (internal-only landlord comment) intentionally has **no** `<fieldPermissions>` entry in either `RentIt_Landlord` or `RentIt_Tenant` — it's never surfaced in any portal component, so no FLS bookkeeping is needed to keep it hidden from tenants.

Before adding a field to a permission set, check the field's `-meta.xml`:
```xml
<required>true</required>  ← already accessible; skip it
```

**Known required fields — excluded from all permission sets:**

| Object | Required Fields (excluded) |
|---|---|
| `Payment__c` | `Amount__c`, `Payment_Date__c`, `Payment_Method__c`, `Payment_Type__c`, `Status__c` |
| `Invoice__c` | `Amount__c`, `Category__c`, `Due_Date__c`, `Invoice_Date__c`, `Status__c` |
| `Notice__c` | `Audience__c`, `Effective_Date__c`, `Notice_Type__c`, `Status__c`, `Notice_Iteration__c` |
| `Tenancy__c` | `Status__c`, `Tenant__c` |

Only add a permission set `<fieldPermissions>` entry for a non-required custom field when there's a concrete UI surface (list view, related list, page layout, Setup UI) that needs it and would otherwise block access — not as a blanket default.

---

## Tenant (`RentIt_Tenant` permission set)

### Object Permissions
| Object | Create | Read | Edit | Delete |
|---|---|---|---|---|
| Account | — | ✓ | — | — |
| Contact | — | ✓ | ✓ | — |
| Invoice__c | — | ✓ | ✓ | — |
| Notice__c | — | ✓ | — | — |
| Payment__c | ✓ | ✓ | ✓ | — |
| Property__c | — | ✓ | — | — |
| Room__c | — | ✓ | — | — |
| Tenancy__c | — | ✓ | ✓ | — |
| Case | ✓ | ✓ | ✓ | — |

Case record types visible: `Complaint`, `Maintenance_Request`

### Apex Class Access
`RentItPortalController` must be in `<classAccesses>` — without this the community user cannot call any `@AuraEnabled` method.

### FLS — Non-Required Fields to Grant
Only add non-required fields. Required fields (see table above) are automatically accessible.

**Tenant-readable (non-required) fields:**
- `Invoice__c`: `Balance_Due__c`, `GST_Amount__c`, `Period_End__c`, `Period_Start__c`, `Total_Amount__c`, `Total_Paid__c`
- `Notice__c`: `Content__c`, `Expiry_Date__c`
- `Room__c`: `Description__c`, `Facilities__c`, `Room_Size__c`, `Weekly_Rent__c`
- `Tenancy__c`: `Available_Credits__c`, `Property__c`, `Room__c`, `Total_Arrears__c`, `Total_Credits__c`, `Total_Received__c`, `Total_Unpaid__c`
- `Property__c`: `Address__c`, `Description__c`
- `Account`: `ABN__c`, `GST_Number__c`, `GST_Registered__c`
- `Case`: `Property__c`, `Room__c`, `Tenancy__c`

**Tenant-editable (non-required) Payment fields:**
- `Payment__c.Comment__c` — editable
- `Payment__c.Invoice__c` — editable (needed to link payment to invoice on submit)
- `Payment__c.Payment_Reference__c` — editable
- `Payment__c.Tenancy__c` — editable (needed to link payment to tenancy on submit)

---

## Tenant Data Access — Relationship Path

The tenant's Tenancy record is resolved via:
```
User.ContactId → Contact.Id = Tenancy__c.Tenant__c
```

Apex query pattern:
```apex
WHERE Tenant__c IN (SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId())
  AND Status__c = 'Active'
```

Do NOT use `Community_User__c = :UserInfo.getUserId()` — that field is supplementary and may not be populated for all tenants.

---

## Tenancy Sharing

### Tenant access — Declarative (Sharing Set)
File: `force-app/main/default/sharingSets/RentIt_Tenant_Sharing_Set.sharingSet-meta.xml`

| Object | Access | Traversal Path |
|---|---|---|
| `Tenancy__c` | Read | `Tenant__c` (Contact) → `User.ContactId` |
| `Notice__c` | Read | `Tenancy__c.Tenant__c` (Contact) → `User.ContactId` |

Applies to profile: `customer community plus user`. Evaluates automatically whenever `Tenant__c` changes — no Apex needed for tenant sharing.

`Invoice__c` and `Payment__c` are `ControlledByParent` children of Tenancy and inherit its access automatically.

### Landlord access
Landlords have `modifyAllRecords: true` on Tenancy__c via the `RentIt_Landlord` permission set — explicit sharing is not required. Apex-managed landlord sharing is deferred.

---

## Landlord (`RentIt_Landlord` permission set)
- Full CRUD + View/Modify All on: Invoice__c, Notice__c, Payment__c, Property__c, Room__c, Tenancy__c
- Sharing Rule keyed on Account (Landlord): grants access to all records under their Properties

---

## Rules & Checklist
- **Never add required fields to permission sets** — Salesforce grants them automatically to any user with object Read access
- **Default to no `<fieldPermissions>` entry** for new custom fields (post Winter '23) — only add one when a specific FLS-enforcing UI surface needs it; omission is the safe/hidden state for portal-sensitive fields like `Notice__c.Notice_Comment__c`
- Never expose other tenants' or landlords' records — each sharing mechanism must be tenant/landlord-scoped
- Run the `security-reviewer` agent after any object exposure, sharing rule, or permission set change
- Apex controllers for community pages use `with sharing`; tenant queries use `without sharing` inner class if OWD blocks access — the WHERE clause enforces isolation
- Notices are system-generated — tenant perm set has no Create/Edit on Notice__c
- After tenant provisioning: ensure `Tenancy__c.Tenant__c` (Contact) is set — this drives both Sharing Set access and the Apex query
