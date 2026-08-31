---
description: Experience Cloud (community) build conventions for RentIT. Use when configuring the site, pages, components, or Experience Builder.
---

## Site Configuration
- Template: **LWR – Build Your Own** (or Customer Account Portal base)
- Site URL path prefix: `/rentit`
- Source directories (retrieve/deploy): `experiences/`, `sites/`, `networks/`, `navigationMenus/` under `force-app/main/default/`
- API version: `67.0` (Winter '26) — keep consistent with `sfdx-project.json`
- After configuring in Experience Builder, retrieve with:
  ```
  sf project retrieve start --metadata "ExperienceBundle:RentIt" --target-org <alias>
  ```

## User Personas & Licenses

| Persona | License | Permission Set | Provisioning |
|---|---|---|---|
| Tenant | Customer Community Plus | `RentIt_Tenant` | Self-registration via Contact email match |
| Landlord | Partner Community (or Internal) | `RentIt_Landlord` | Admin-provisioned |
| Guest | None | None | Login/register page only — zero object access |

- After a tenant registers, the Landlord must set `Tenancy__c.Community_User__c` to the new User — this drives the Sharing Set and grants record access
- Self-registration: match incoming email to `Contact.Email`; create User from `RentIt_Tenant` perm set

## Tenant Portal — Page Structure

| Page | Route | Key Components |
|---|---|---|
| Home | `/` | Welcome banner, active tenancy summary, upcoming invoice alert |
| My Tenancy | `/tenancy` | Tenancy details (property, room, status, credits), contract summary |
| Invoices | `/invoices` | Invoice list; fields: Period_Start__c, Period_End__c, Balance_Due__c, Total_Amount__c, Total_Paid__c, GST_Amount__c |
| Make a Payment | `/payments/new` | Payment form (Amount, Payment_Reference__c, Comment__c, Payment_Date, Payment_Method); submits for landlord approval |
| Payment History | `/payments` | Payments list by status (Pending/Approved/Rejected) |
| Raise a Complaint | `/cases/new` | Case form — record type: `Complaint`; fields: Subject, Description, Case.Property__c, Case.Room__c, Case.Tenancy__c |
| Maintenance Request | `/cases/maintenance` | Case form — record type: `Maintenance_Request` |
| Notices | `/notices` | Read-only list; fields: Name, Content__c, Expiry_Date__c |

## Landlord Portal — Page Structure

| Page | Route | Purpose |
|---|---|---|
| Dashboard | `/` | Portfolio summary |
| Tenants | `/tenants` | View/manage Tenancy records, set Community_User__c |
| Notices | `/notices` | System-generated notices per tenancy |
| Payments | `/payments` | Approve / reject submitted payments |

## LWC Component Conventions
- All LWCs in `force-app/main/default/lwc/`, prefixed `rentit` (e.g., `rentitTenancySummary`, `rentitPaymentForm`)
- Prefer `@wire` adapters over imperative Apex — wire respects FLS and sharing automatically
- Use `NavigationMixin` from `lightning/navigation` for all routing — no hardcoded `/rentit/s/...` paths
- Import logged-in user: `import userId from '@salesforce/user/Id'`
- Use `lightning-record-form` / `lightning-record-edit-form` for standard CRUD — inherits FLS
- Screen flows: embed via `<lightning-flow>` for multi-step actions (payment submission, complaint)
- Error display: `<lightning-messages>` or `<p class="slds-text-color_error">`

## Tenant-Editable Fields (FLS boundary)
Tenants may **only** edit these Payment fields — enforce in LWC/Flow, never expose other fields:
- `Payment__c.Comment__c`
- `Payment__c.Payment_Reference__c`

All Invoice, Notice, Tenancy, Property, Room fields are **read-only** for tenants.

## Navigation Menus
- Defined in `force-app/main/default/navigationMenus/`
- **Tenant menu**: Home, My Tenancy, Invoices, Make a Payment, Payment History, Raise a Complaint, Notices
- **Landlord menu**: Dashboard, Tenants, Notices, Payments
- Audience: use Audience criteria in Experience Builder to show/hide menus by perm set

## Sharing & Security Checks
- After any page or component exposes a new object, run the `sharing-security-model` skill to audit
- Guest users must never reach authenticated pages — enforce via Audience rules + Login Required page setting
- Never use `without sharing` in community-exposed Apex controllers
