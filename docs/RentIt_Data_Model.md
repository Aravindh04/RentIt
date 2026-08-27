# RentIt — Data Model & Administration Guide

**API Version:** 67.0 (Winter '26)  
**Last Updated:** 2026-08-27  
**Author:** Aravindhan Vijayakumar

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture Decisions](#2-architecture-decisions)
3. [Data Model — Object Relationships (ERD)](#3-data-model--object-relationships-erd)
4. [Custom Objects](#4-custom-objects)
   - [Property__c](#41-propertyc)
   - [Room__c](#42-roomc)
   - [Tenancy__c](#43-tenancyc)
   - [Notice__c](#44-noticec)
   - [Rent_Payment__c](#45-rent_paymentc)
5. [Standard Objects Used](#5-standard-objects-used)
6. [Case Record Types](#6-case-record-types)
7. [Roll-Up Summary Fields](#7-roll-up-summary-fields)
8. [Formula Fields](#8-formula-fields)
9. [Permission Sets](#9-permission-sets)
10. [Experience Cloud (Community) Setup](#10-experience-cloud-community-setup)
11. [Scratch Org Deployment](#11-scratch-org-deployment)
12. [Admin Guide — Day-to-Day Operations](#12-admin-guide--day-to-day-operations)
13. [Tenant User Guide — Community Portal](#13-tenant-user-guide--community-portal)
14. [Security Model](#14-security-model)
15. [Future Enhancements](#15-future-enhancements)

---

## 1. Overview

**RentIt** is a Salesforce-based property and tenant management application built on the Lightning Platform. It enables landlords and property managers to:

- Create and manage **rental properties** with detailed address and description information
- Define **rooms** within each property, including size, facilities, and room-specific photos (via Salesforce Files)
- Create **tenancy agreements** linking a specific room to a tenant (Contact), capturing rent amount, frequency, start date, deposit, and contract reference
- Publish **notices** to all tenants in a property or to individual tenants
- Track **complaints** and **maintenance requests** submitted by tenants via the community portal

Tenants log in through an **Experience Cloud (Community)** site using Customer Community or Customer Community Plus licences. Their user account is linked to a Contact record (standard Salesforce pattern), and their Tenancy record links directly to their community User via the `Community_User__c` field.

---

## 2. Architecture Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Property → Room relationship | Master-Detail | Enables roll-up summaries (Total/Available/Occupied Rooms) on Property; rooms cannot exist without a property |
| Room → Tenancy relationship | Master-Detail | Enables roll-up summary (Number of Active Tenants) on Room; tenancies cannot exist without a room |
| Tenant identity | Contact + Community User | Standard Salesforce pattern — Contact is the person record, User is the login account |
| Community_User__c on Tenancy | Lookup(User) | Allows SOQL filtering in community LWCs: `WHERE Community_User__c = :UserInfo.getUserId()` |
| Profiles → Permission Sets | Permission Sets only | Future-proof, composable, and follows Salesforce best-practice post-profiles-retirement roadmap |
| Complaints & Problems | Standard Case object | Leverages standard case management, assignment rules, email notifications, and OmniChannel routing |
| Contracts | Standard Contract + Files | Standard Contract object for formal agreement metadata; PDF/documents attached via Salesforce Files on Tenancy |
| Object-level security (OWD) | Private (Property, Notice); ControlledByParent (Room, Tenancy) | Landlord sees all via Modify All on permission set; tenants see only their records via sharing rules |
| Landlord entity | Account (Business or Person Account) | Supports landlords registered as businesses with ABN and GST numbers. Properties link to Account instead of Contact, allowing both business and personal ownership. |
| Rent invoicing | Rent_Payment__c (Lookup to Tenancy__c) | One invoice record per billing cycle. Cannot use Master-Detail because the 3-level limit (Property → Room → Tenancy) is already reached. Status lifecycle: Unpaid → Paid / Overdue / Void. |

---

## 3. Data Model — Object Relationships (ERD)

```
          ┌──────────────────────────────┐       ┌────────────────────────┐
          │           Account             │       │        Contact         │
          │  (Business or Person Account) │       │  (Standard — Tenant)   │
          │  ABN__c                       │       │  Standard Object        │
          │  GST_Registered__c            │       └────────────┬───────────┘
          └──────────────┬───────────────┘                    │ Lookup (Tenant__c)
                         │ Lookup (Landlord__c)               │
                         │                   ┌─── Lookup (Tenant_Account__c) ──────┐
                         │                   │                                      │
          ┌──────────────▼───────────────┐   │  ┌───────────────────────────────────▼──┐
          │         Property__c           │   │  │            Tenancy__c                 │
          │  OWD: Private                 │   │  │  OWD: ControlledByParent              │
          │  ─────────────────────        │   │  │  ─────────────────────────────────    │
          │  Name (Property Name)         │◄Roll  │  Name (Auto: TEN-0001)               │
          │  Property_Type__c             │ -up│  │  Room__c (MD → Room__c)              │
          │  Street__c / City__c          │Rooms  │  Tenant__c (Lookup → Contact)        │
          │  State__c / Postcode__c       │   └──│  Tenant_Account__c (Lookup → Account)│
          │  Country__c / Description__c  │      │  Community_User__c (Lookup → User)   │
          │  Landlord__c (→ Account)      │      │  Rent_Amount__c / Rent_Frequency__c  │
          │  Total_Rooms__c (RU)          │      │  Rent_Start_Date__c / Rent_End_Date__c│
          │  Available_Rooms__c (RU)      │      │  Deposit_Amount__c                   │
          │  Occupied_Rooms__c (RU)       │      │  Next_Due_Date__c (FML)              │
          └───────────────┬───────────────┘      │  Status__c / Contract__c             │
                          │                       └──────────────────────┬──────────────┘
          MD (1 Prop → Many Rooms)                                       │ Lookup
                          │                                               │ (1 Tenancy →
          ┌───────────────▼───────────────┐                              │  Many Invoices)
          │           Room__c              │        ┌─────────────────────▼────────────────┐
          │  OWD: ControlledByParent       │        │          Rent_Payment__c               │
          │  ─────────────────────         │        │  OWD: Private                         │
          │  Name (Room No./Name)          │        │  ─────────────────────────────────    │
          │  Property__c (MD)              │◄─ MD ──│  Name (Auto: INV-0001)                │
          │  Room_Size__c / Room_Type__c   │(1 Room │  Tenancy__c (Lookup, required)        │
          │  Facilities__c (MSP)           │→ Many  │  Invoice_Date__c / Due_Date__c        │
          │  Weekly_Rent__c / Status__c    │Tenancy)│  Period_Start__c / Period_End__c      │
          │  Description__c / Floor__c     │        │  Amount__c (ex GST)                   │
          │  Number_of_Tenants__c (RU)     │        │  GST_Amount__c                        │
          │  [Files / Pictures]            │        │  Total_Amount__c (FML)                │
          └────────────────────────────────┘        │  Status__c (Unpaid/Paid/Overdue/Void) │
                                                     │  Payment_Date__c                      │
          ┌────────────────────────┐                 │  Payment_Reference__c                │
          │        Notice__c        │                 └──────────────────────────────────────┘
          │  OWD: Private           │
          │  ──────────────────     │    ┌────────────────────────┐
          │  Name (Notice Title)   │    │          Case           │
          │  Notice_Type__c        │    │  (Standard Object)      │
          │  Content__c (HTML)     │    │  ─────────────────────  │
          │  Effective_Date__c     │    │  RecordType:            │
          │  Expiry_Date__c        │    │   - Complaint           │
          │  Property__c (Lookup)  │    │   - Maintenance Request │
          │  Tenancy__c (Lookup)   │    │  Room__c (Lookup)       │
          │  Status__c / Audience__c│    │  Tenancy__c (Lookup)    │
          └────────────────────────┘    │  Property__c (Lookup)   │
                                        └────────────────────────┘
          ┌────────────────────────┐
          │        Contract         │◄──── Lookup from Tenancy__c.Contract__c
          │  (Standard Object)      │
          └────────────────────────┘

MD = Master-Detail  |  RU = Roll-Up Summary  |  FML = Formula  |  MSP = Multi-Select Picklist
```

---

## 4. Custom Objects

### 4.1 Property__c

**Label:** Property | **Plural:** Properties  
**Sharing Model (OWD):** Private  
**Activities:** Enabled | **History Tracking:** Enabled

The top-level object representing a physical rental property (house, apartment, unit, etc.).

| Field API Name | Label | Type | Description |
|---|---|---|---|
| Name | Property Name | Text (standard) | Human-readable name (e.g., "42 Oak Street Unit") |
| Property_Type__c | Property Type | Picklist | House, Apartment, Unit, Townhouse, Villa, Studio, Granny Flat |
| Street__c | Street | Text(255) | Street address (required) |
| City__c | City / Suburb | Text(100) | City or suburb (required) |
| State__c | State / Territory | Text(100) | State or territory |
| Postcode__c | Postcode | Text(20) | Postal/ZIP code |
| Country__c | Country | Text(100) | Country |
| Description__c | Property Description | Long Text Area | General property description, house rules, and amenities |
| Landlord__c | Landlord Account | Lookup(Account) | The Account (Business or Person Account) for the property owner/manager. Stores ABN and GST registration for invoice generation. |
| Total_Rooms__c | Total Rooms | Roll-Up (COUNT Room__c) | Auto-calculated: total number of rooms defined |
| Available_Rooms__c | Available Rooms | Roll-Up (COUNT Room__c WHERE Status = Available) | Auto-calculated: rooms currently available |
| Occupied_Rooms__c | Occupied Rooms | Roll-Up (COUNT Room__c WHERE Status = Occupied) | Auto-calculated: rooms currently tenanted |

**Files/Pictures:** Room photos are attached to the **Room__c** record via Salesforce Files (ContentDocument). Navigate to a Room record and use the Files related list to upload images.

---

### 4.2 Room__c

**Label:** Room | **Plural:** Rooms  
**Sharing Model (OWD):** Controlled by Parent (Property__c)  
**Activities:** Enabled | **History Tracking:** Enabled

Represents an individual rentable room within a property.

| Field API Name | Label | Type | Description |
|---|---|---|---|
| Name | Room Number / Name | Text (standard) | e.g., "Room 1", "Master Bedroom", "Studio A" |
| Property__c | Property | Master-Detail(Property__c) | Parent property (required, cascade-deletes on parent delete) |
| Room_Size__c | Room Size (m²) | Number(10,2) | Floor area in square metres |
| Room_Type__c | Room Type | Picklist | Single, Double, Twin, Master Bedroom, Ensuite, Studio, Shared Room |
| Facilities__c | Facilities | Multi-Select Picklist | Wi-Fi, Air Conditioning, Heating, Furnished, Parking, En-suite Bathroom, Shared Bathroom, Kitchen Access, Laundry Access, Television, Balcony/Patio, Garden Access, Storage, Gym Access, Swimming Pool, Bills Included |
| Weekly_Rent__c | Advertised Weekly Rent | Currency | The advertised rent rate (actual agreed rent lives on Tenancy__c) |
| Status__c | Status | Picklist | Available *(default)*, Occupied, Under Maintenance, Reserved |
| Description__c | Room Description | Long Text Area | Specific room notes for tenants or internal reference |
| Floor__c | Floor Level | Number(3,0) | 0 = ground floor, 1 = first floor, etc. |
| Number_of_Tenants__c | Number of Active Tenants | Roll-Up Summary | Auto-calculated: count of Tenancy__c records with Status = Active |

**Attaching Room Pictures:** Go to the Room record → Files related list → Upload. Pictures are stored as Salesforce Files (ContentVersion) linked to the room. In the community portal, display them using the `lightning-file-download` or a custom LWC that queries `ContentDocumentLink`.

---

### 4.3 Tenancy__c

**Label:** Tenancy | **Plural:** Tenancies  
**Sharing Model (OWD):** Controlled by Parent (Room__c)  
**Auto-Number:** TEN-{0000} (e.g., TEN-0001)  
**Activities:** Enabled | **History Tracking:** Enabled

The central linking object. Connects a **Room** to a **Tenant (Contact)** and holds all agreement details.

| Field API Name | Label | Type | Description |
|---|---|---|---|
| Name | Tenancy Number | Auto-Number | System-generated: TEN-0001, TEN-0002, … |
| Room__c | Room | Master-Detail(Room__c) | The room being rented (required) |
| Tenant__c | Tenant (Contact) | Lookup(Contact) | The Contact record for the tenant (required) |
| Community_User__c | Community User | Lookup(User) | The tenant's Experience Cloud User account. Populate this when enabling the tenant as a community user. Used by community LWCs to filter records: `WHERE Community_User__c = :UserInfo.getUserId()` |
| Tenant_Account__c | Tenant Account | Lookup(Account) | The Account linked to the tenant. Mirrors `Tenant__r.AccountId`. Auto-populated by Flow on Tenancy creation. Supports Business Accounts and Person Accounts. |
| Rent_Amount__c | Rent Amount | Currency | The agreed rent per payment period (required) |
| Rent_Frequency__c | Rent Frequency | Picklist | Weekly *(default)*, Fortnightly, Monthly |
| Rent_Start_Date__c | Rent Start Date | Date | Date tenancy begins (required) |
| Rent_End_Date__c | Rent End Date | Date | Date tenancy ends; blank = periodic/rolling tenancy |
| Deposit_Amount__c | Deposit Amount | Currency | Security bond/deposit paid at commencement |
| Next_Due_Date__c | Next Due Date | Formula (Date) | Calculated next rent due date — see [Formula Fields](#8-formula-fields) |
| Status__c | Tenancy Status | Picklist | Pending, Active *(default)*, Expired, Terminated |
| Contract__c | Contract | Lookup(Contract) | Link to the standard Salesforce Contract object for formal agreement metadata. Alternatively, attach a PDF directly via Salesforce Files on this record. |

---

### 4.4 Notice__c

**Label:** Notice | **Plural:** Notices  
**Sharing Model (OWD):** Private  
**Activities:** Disabled | **History Tracking:** Disabled

Notices created by the landlord and published to tenants via the community portal.

| Field API Name | Label | Type | Description |
|---|---|---|---|
| Name | Notice Title | Text (standard) | Descriptive title of the notice |
| Notice_Type__c | Notice Type | Picklist | General Information *(default)*, Urgent, Scheduled Maintenance, Rent Increase, Lease Renewal, Eviction Notice, Inspection Notice |
| Content__c | Notice Content | HTML (Rich Text) | Full body text with formatting, shown in community portal |
| Effective_Date__c | Effective Date | Date | Date from which the notice is visible to tenants (required) |
| Expiry_Date__c | Expiry Date | Date | Date after which notice is hidden from the portal; blank = permanent |
| Property__c | Property | Lookup(Property__c) | Target property for "All Tenants in Property" audience |
| Tenancy__c | Tenancy | Lookup(Tenancy__c) | Target individual tenancy for "Specific Tenant" audience |
| Status__c | Status | Picklist | Draft *(default)*, Published, Archived |
| Audience__c | Audience | Picklist | All Tenants in Property *(default)*, Specific Tenant |

**Publishing Logic:** Only notices with `Status__c = Published` and `Effective_Date__c <= TODAY()` and (`Expiry_Date__c = NULL` OR `Expiry_Date__c >= TODAY()`) should be shown in the community portal. Implement this filter in the community LWC SOQL query.

---

### 4.5 Rent_Payment__c

**Label:** Rent Payment | **Plural:** Rent Payments  
**Sharing Model (OWD):** Private  
**Auto-Number:** INV-{0000} (e.g., INV-0001)  
**Activities:** Disabled | **History Tracking:** Enabled (Status field)

One record is created per rent billing cycle for a Tenancy. The landlord (or a scheduled Flow) generates invoices; the status progresses from Unpaid to Paid when payment is confirmed.

> **Why Lookup (not Master-Detail) to Tenancy__c?**  
> Salesforce supports a maximum of 2 levels of Master-Detail hierarchy. Property__c → Room__c → Tenancy__c already uses both levels. A fourth level is not supported, so Rent_Payment__c uses a Lookup relationship instead.

| Field API Name | Label | Type | Description |
|---|---|---|---|
| Name | Invoice Number | Auto-Number | System-generated: INV-0001, INV-0002, … |
| Tenancy__c | Tenancy | Lookup(Tenancy__c) | The tenancy this invoice belongs to (required) |
| Invoice_Date__c | Invoice Date | Date | Date the invoice was generated (required) |
| Due_Date__c | Due Date | Date | Payment due date, copied from Tenancy Next_Due_Date at generation time (required) |
| Period_Start__c | Period Start | Date | Start of the billing period this invoice covers |
| Period_End__c | Period End | Date | End of the billing period this invoice covers |
| Amount__c | Amount (ex GST) | Currency | Base rent amount for the period, excluding GST (required) |
| GST_Amount__c | GST Amount | Currency | 10% GST component; populated by Flow only when the landlord Account has `GST_Registered__c = true` |
| Total_Amount__c | Total Amount (inc GST) | Formula (Currency) | `Amount__c + IF(ISNULL(GST_Amount__c), 0, GST_Amount__c)` |
| Status__c | Status | Picklist | **Unpaid** *(default)*, Paid, Overdue, Void |
| Payment_Date__c | Payment Date | Date | Date the payment was received; set when Status = Paid |
| Payment_Reference__c | Payment Reference | Text(255) | Bank transfer reference, receipt number, or transaction ID |

**Status Lifecycle:**
```
Unpaid → Paid       (payment confirmed by landlord or payment gateway)
Unpaid → Overdue    (scheduled Flow: Due_Date__c < TODAY() and Status = Unpaid)
Any    → Void       (invoice cancelled — e.g., tenancy terminated before period)
```

---

## 5. Standard Objects Used

| Object | Role in RentIt | Notes |
|---|---|---|
| **Account** | Landlord/business entity and tenant account | Supports both Business Accounts (with ABN and GST for rental businesses) and Person Accounts. `Property__c.Landlord__c` links to the owner's Account. `Tenancy__c.Tenant_Account__c` links to the tenant's Account. |
| **Contact** | Tenant person record | Linked to `Tenancy__c.Tenant__c`. Community users are linked to Contact via the standard `ContactId` field on User. |
| **User** | Community login account for tenants | Customer Community or Customer Community Plus licence. Linked to Tenancy__c via `Community_User__c`. Linked to Contact via standard `ContactId` on User. |
| **Case** | Tenant complaints and maintenance requests | Two record types: Complaint and Maintenance_Request. Custom fields: Room__c, Tenancy__c, Property__c. Tenant creates cases via the community portal; landlord manages via the internal app. |
| **Contract** | Tenancy agreement formal metadata | Optional. Linked from Tenancy__c.Contract__c. Use Salesforce Files on Tenancy__c for PDF contract documents. |
| **ContentDocument / ContentVersion** | Room photos and contract PDFs | Attached via standard Salesforce Files (related list) on Room__c and Tenancy__c records. |

---

## 6. Case Record Types

| Record Type | Developer Name | Purpose |
|---|---|---|
| Complaint | `Complaint` | Tenant lodges a formal complaint — noise, neighbour, landlord conduct, breach of conditions |
| Maintenance Request | `Maintenance_Request` | Tenant reports a repair or maintenance need — plumbing, electrical, structural, appliance |

Both record types are visible to both `RentIt_Landlord` and `RentIt_Tenant` permission sets. The tenant creates cases via the community portal; the landlord sees and manages all cases in the internal RentIt app.

---

## 7. Roll-Up Summary Fields

Roll-up summaries automatically recalculate when child records are created, updated, or deleted.

| Parent Object | Field | Child Object | Aggregation | Filter |
|---|---|---|---|---|
| Property__c | Total_Rooms__c | Room__c | COUNT | None (all rooms) |
| Property__c | Available_Rooms__c | Room__c | COUNT | Status__c = Available |
| Property__c | Occupied_Rooms__c | Room__c | COUNT | Status__c = Occupied |
| Room__c | Number_of_Tenants__c | Tenancy__c | COUNT | Status__c = Active |

**Important:** These roll-ups only work because:
- Room__c has a **Master-Detail** relationship to Property__c
- Tenancy__c has a **Master-Detail** relationship to Room__c

This creates a valid 3-level hierarchy: Property → Room → Tenancy.

---

## 8. Formula Fields

### Tenancy__c.Next_Due_Date__c (Date Formula)

Calculates the next rent payment due date from today, based on the tenancy start date and payment frequency.

```
IF(
  ISBLANK(Rent_Start_Date__c),
  NULL,
  IF(
    ISPICKVAL(Rent_Frequency__c, "Weekly"),
    Rent_Start_Date__c + (CEILING(MAX(TODAY() - Rent_Start_Date__c, 0) / 7) * 7),
    IF(
      ISPICKVAL(Rent_Frequency__c, "Fortnightly"),
      Rent_Start_Date__c + (CEILING(MAX(TODAY() - Rent_Start_Date__c, 0) / 14) * 14),
      Rent_Start_Date__c + (CEILING(MAX(TODAY() - Rent_Start_Date__c, 0) / 30) * 30)
    )
  )
)
```

**How it works:**
- Subtracts the start date from today to find elapsed days
- `MAX(..., 0)` prevents negative numbers for future start dates
- `CEILING(elapsed / period) * period` rounds up to the next full period
- Adding that number of days to the start date gives the next due date

**Limitation:** The monthly calculation uses 30 days (approximate). For exact calendar-month calculations, replace with an Apex trigger that writes to a standard Date field.

### Rent_Payment__c.Total_Amount__c (Currency Formula)

Calculates the total invoice amount including GST.

```
Amount__c + IF(ISNULL(GST_Amount__c), 0, GST_Amount__c)
```

**How it works:** Adds the base rent to the GST component. `ISNULL` guard prevents a formula error when `GST_Amount__c` is blank (non-GST-registered landlords). `formulaTreatBlanksAs = BlankAsZero` ensures the result is always numeric.

---

## 9. Permission Sets

### RentIt_Landlord

**Assign to:** Internal Salesforce users who manage properties (landlords, property managers, admins).

| Object | Create | Read | Edit | Delete | View All | Modify All |
|---|---|---|---|---|---|---|
| Property__c | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Room__c | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Tenancy__c | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Notice__c | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Case | ✓ | ✓ | ✓ | ✓ | ✓ | — |
| Contract | ✓ | ✓ | ✓ | ✓ | — | — |
| Contact | ✓ | ✓ | ✓ | — | — | — |
| Account | ✓ | ✓ | ✓ | — | — | — |
| Rent_Payment__c | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

**Why no Profiles?** Salesforce is moving toward Permission-Set-only security. This permission set is designed to be layered on top of the Minimum Access (formerly Chatter Free) or Standard User base profile, giving only the access explicitly needed.

---

### RentIt_Tenant (Community)

**Assign to:** Customer Community or Customer Community Plus users (tenants logging in via the community portal).

| Object | Create | Read | Edit | Delete |
|---|---|---|---|---|
| Property__c | — | ✓ (own) | — | — |
| Room__c | — | ✓ (own) | — | — |
| Tenancy__c | — | ✓ (own) | — | — |
| Notice__c | — | ✓ (own) | — | — |
| Case | ✓ | ✓ (own) | ✓ (own) | — |
| Account | — | ✓ (own) | — | — |
| Rent_Payment__c | — | ✓ (own) | — | — |

**"Own" record access** is enforced via:
1. **OWD = Private** (Property, Notice) and **OWD = Controlled By Parent** (Room, Tenancy)
2. **Sharing rules** that share a tenant's Property/Room/Tenancy/Notice with their community User record
3. **SOQL filtering** in community LWCs using `WHERE Community_User__c = :UserInfo.getUserId()` on Tenancy__c

---

## 10. Experience Cloud (Community) Setup

### Step 1: Enable Communities

The scratch org definition already includes the `Communities` and `ExperienceBundle` features. For an existing org:
1. Setup → Digital Experiences → Settings → Enable Digital Experiences
2. Set your domain name

### Step 2: Create the Experience Cloud Site

1. Setup → Digital Experiences → All Sites → New
2. Choose template: **Customer Account Portal** or **Build Your Own (LWR)**
3. Name the site: **RentIt Portal**

### Step 3: Configure the Guest & Member Profiles

- **Member Profile / Permission Set:** Assign `RentIt_Tenant` permission set to all community member users
- **Guest Profile:** Do NOT grant access to any custom objects (notices and tenancy details require login)

### Step 4: Enable Tenants as Community Users

For each tenant Contact:
1. On the Contact record → Manage External User → Enable Customer User
2. Set Profile to: Customer Community Plus (or Customer Community)
3. Set Username and send welcome email
4. Go to the created Tenancy__c record → populate `Community_User__c` with the newly created User ID

### Step 5: Sharing Rules

Create these Sharing Rules to give tenants access to their own records:

| Object | Rule Type | Criteria | Share With | Access |
|---|---|---|---|---|
| Property__c | Criteria-based | — | (Use Apex Managed Sharing on Tenancy creation) | Read |
| Notice__c | Criteria-based | Status = Published | All Community Internal Users | Read |

For Tenancy and Room records (OWD = Controlled by Parent), sharing the parent Property__c record automatically grants access to child Rooms and Tenancies. Use Apex Managed Sharing triggered when a Tenancy is created/activated to share the related Property__c with the Community_User__c.

### Step 6: Community Pages to Build

| Page | Object | Purpose |
|---|---|---|
| My Tenancy | Tenancy__c | Show tenant their current agreement details, rent amount, due date |
| My Invoices | Rent_Payment__c | List rent invoices for the tenant's tenancy — status, amounts, due dates |
| Notices | Notice__c | List published notices for their property/tenancy |
| Lodge a Complaint | Case (Complaint RT) | Form to create a new Complaint case |
| Report a Problem | Case (Maintenance_Request RT) | Form to create a new Maintenance Request case |
| My Cases | Case | List of the tenant's submitted cases and their status |

---

## 11. Scratch Org Deployment

### Prerequisites

- Salesforce CLI installed (`sf --version`)
- Authenticated Dev Hub (`sf auth web login --set-default-dev-hub`)

### Create Scratch Org and Deploy

```bash
# Create scratch org (30-day expiry)
sf org create scratch --definition-file config/project-scratch-def.json --alias rentit-dev --duration-days 30 --set-default

# Deploy all metadata
sf project deploy start --target-org rentit-dev

# Open the org
sf org open --target-org rentit-dev
```

### Post-Deployment Steps

```bash
# Assign the Landlord permission set to yourself for testing
sf org assign permset --name RentIt_Landlord --target-org rentit-dev

# Open the RentIt app
sf org open --path /lightning/app/RentIt --target-org rentit-dev
```

### Create Test Data

After deploying, manually create:
1. An **Account** record (your landlord business or person account) — set ABN and check GST Registered if applicable
2. A **Property__c** record — set Landlord Account to the Account created above
3. Two or three **Room__c** records under the property
4. A **Contact** record (a test tenant)
5. A **Tenancy__c** record linking the test room to the test tenant Contact
6. A **Rent_Payment__c** record linked to the Tenancy — Status = Unpaid, set Due Date and Amount
7. A **Notice__c** record (Status = Published) linked to the property

---

## 12. Admin Guide — Day-to-Day Operations

### Creating a New Property

1. Open the **RentIt** Lightning app
2. Go to the **Properties** tab → New
3. Fill in: Property Name, Type, full address, Description
4. Set **Landlord Account** (lookup to an Account — the owner's business or person account; create the Account first if it does not exist)
5. Save. The Total/Available/Occupied Rooms counters will auto-update as you add rooms.

### Adding Rooms to a Property

1. Open the Property record
2. In the **Rooms** related list → New
3. Fill in: Room Number/Name, Room Type, Size (m²), Floor, Facilities (multi-select), Advertised Weekly Rent, Status = Available
4. Add a description for tenants
5. Save. Then navigate to the Room record → **Files** → Upload to attach room photos.

### Creating a Tenancy

1. Open a Room record (Status should be Available)
2. In the **Tenancies** related list → New
3. Fill in:
   - **Tenant (Contact):** Search for the tenant's Contact record (create Contact first if needed)
   - **Rent Amount:** The agreed amount
   - **Rent Frequency:** Weekly / Fortnightly / Monthly
   - **Rent Start Date:** The move-in date
   - **Rent End Date:** Leave blank for rolling/periodic tenancy
   - **Deposit Amount:** Security bond amount
   - **Status:** Active (or Pending if awaiting move-in)
   - **Contract:** Optionally link a Contract record, or attach the PDF via Files
4. Save. The Room's **Number of Active Tenants** counter will increment.
5. **Update Room Status:** Manually set Room Status to **Occupied** (consider automating this with a Flow triggered on Tenancy creation/activation).

### Enabling a Tenant as a Community User

1. Open the tenant's **Contact** record
2. Click **Manage External User** → **Enable Customer User**
3. Choose licence: Customer Community Plus
4. Set username (typically their email address)
5. Send the welcome email
6. Open the linked **Tenancy__c** record
7. In **Community User** field → search and select the newly created User
8. This links the tenant's login to their tenancy — community LWCs use this to display their data.

### Publishing a Notice

1. Go to the **Notices** tab → New
2. Fill in: Title, Notice Type, Content (rich text)
3. Set **Effective Date** (when it becomes visible)
4. Set **Expiry Date** (when it stops showing, or leave blank)
5. Set **Audience:**
   - *All Tenants in Property* → also set **Property** field
   - *Specific Tenant* → also set **Tenancy** field
6. Set **Status = Draft** to save without publishing
7. Set **Status = Published** when ready to make visible to tenants

### Managing Cases (Complaints & Maintenance Requests)

1. Go to the **Cases** tab in the RentIt app
2. Filter by **Record Type = Complaint** or **Maintenance Request**
3. Open a case to view tenant's description, linked Room, Tenancy, and Property
4. Update **Status** (New → In Progress → Resolved → Closed)
5. Use the **Activity** section to log calls, send emails, or add comments

### Managing Rent Payment Invoices

Invoices are generated per billing cycle (by Flow or manually) and linked to a Tenancy.

**To generate an invoice manually:**
1. Open the Tenancy record
2. In the **Rent Payments** related list → New
3. Fill in:
   - **Tenancy:** already linked
   - **Invoice Date:** today's date
   - **Due Date:** the rent due date (from `Next_Due_Date__c`)
   - **Period Start / End:** the billing period dates
   - **Amount (ex GST):** copy from `Rent_Amount__c` on the Tenancy
   - **GST Amount:** 10% of the amount if the landlord's Account has `GST_Registered__c = true`; otherwise leave blank
   - **Status:** Unpaid
4. Save — `Total_Amount__c` calculates automatically

**To mark an invoice as paid:**
1. Open the Rent Payment record
2. Set **Status = Paid**
3. Enter the **Payment Date** (when funds were received)
4. Enter the **Payment Reference** (bank reference or receipt number)
5. Save

**Overdue invoices:** Run a scheduled Flow nightly to find invoices where `Due_Date__c < TODAY()` and `Status__c = Unpaid`, then update Status to **Overdue** and optionally send a reminder email to the tenant.

---

## 13. Tenant User Guide — Community Portal

### Logging In

1. Open the RentIt community portal URL (provided by your landlord)
2. Enter your email address and password
3. Click **Log In**
4. If you forgot your password, click **Forgot Password** to reset via email

### Viewing Your Tenancy Details

1. After logging in, navigate to **My Tenancy**
2. You will see:
   - Your room details (type, size, facilities)
   - Property address
   - Rent amount and frequency
   - Rent start and end dates
   - Deposit paid
   - **Next Rent Due Date** (calculated automatically)
   - Link to download your tenancy agreement (if attached)

### Viewing Your Invoices

1. Navigate to **My Invoices** in the portal menu
2. A list of all rent invoices for your tenancy is shown, most recent first
3. Each invoice shows:
   - **Invoice Number** (e.g., INV-0001)
   - **Period** (billing start and end dates)
   - **Amount** and **Total (inc GST)** if applicable
   - **Due Date**
   - **Status** — Unpaid (outstanding), Paid (confirmed), Overdue (past due), Void (cancelled)
4. Click an invoice to see full details including payment reference
5. Contact your landlord if an invoice status is incorrect

### Viewing Notices

1. Navigate to **Notices** in the portal menu
2. All current notices from your landlord are listed, newest first
3. Click a notice to read the full content
4. Notice types (Urgent, Maintenance, etc.) are colour-coded for easy identification

### Lodging a Complaint

1. Navigate to **Lodge a Complaint**
2. Fill in:
   - **Subject:** Brief description of the complaint
   - **Description:** Full details of the issue (who, what, when, where)
   - **Room:** Select your room from the dropdown
3. Click **Submit**
4. You will receive a case reference number (e.g., Case #00001234)
5. Track the status of your complaint under **My Cases**

### Reporting a Problem / Maintenance Request

1. Navigate to **Report a Problem**
2. Fill in:
   - **Subject:** Brief description of the problem (e.g., "Leaking tap in bathroom")
   - **Description:** Full details — what is broken, how long it has been an issue, urgency level
   - **Room:** Select your room
3. Click **Submit**
4. Track progress under **My Cases**

### Viewing Your Case History

1. Navigate to **My Cases**
2. All your submitted complaints and maintenance requests are listed
3. Click any case to see status updates and any comments from your landlord

---

## 14. Security Model

### Object-Level Security

| Object | OWD | Landlord Access | Tenant Access |
|---|---|---|---|
| Property__c | Private | View All + Modify All (via PS) | Read own (via sharing rule) |
| Room__c | Controlled by Parent | Inherited from Property | Inherited from Property |
| Tenancy__c | Controlled by Parent | View All + Modify All (via PS) | Read own (inherited; filtered in LWC) |
| Notice__c | Private | View All + Modify All (via PS) | Read published (via sharing rule) |
| Case | Private | View All (via PS) | Own records only |
| Account | Private (default) | CRUD on managed accounts | Read own account |
| Rent_Payment__c | Private | View All + Modify All (via PS) | Read own invoices (sharing rule) |

### Field-Level Security

- **Landlord PS:** Read + Edit on all relevant fields
- **Tenant PS:** Read-only on tenancy/property/notice fields; no access to Landlord__c, Community_User__c (other tenants' IDs), or other tenants' Deposit/Rent details (enforced by record-level sharing, not FLS — all tenants with access to a record see the same fields)

### Community User Identity

The `Community_User__c` Lookup(User) on Tenancy__c is the key field that ties a logged-in community session to a tenancy record. All community LWC SOQL queries should include:

```apex
WHERE Community_User__c = :UserInfo.getUserId()
```

This ensures tenants only ever see their own data, even if record-level sharing is misconfigured.

### Important: No Permission Set = No Access

Users without `RentIt_Landlord` or `RentIt_Tenant` permission set assigned have **zero access** to all custom objects (OWD = Private). This is intentional — access must be explicitly granted.

---

## 15. Future Enhancements

| Enhancement | Priority | Notes |
|---|---|---|
| **Flow: Auto-set Room Status** | High | When Tenancy Status changes to Active → set Room Status to Occupied. When Terminated/Expired → set to Available. |
| **Flow: Email notification on Notice publish** | High | When Notice Status changes to Published → send email to all linked tenants |
| **Flow: Rent due date reminder** | Medium | Scheduled Flow running daily — find Tenancies where Next_Due_Date = TODAY + 3 days → send reminder email |
| **Apex Managed Sharing** | High | Trigger on Tenancy creation/activation to share parent Property with the linked Community_User, giving portal access |
| **Inspection Scheduling** | Medium | New object Inspection__c with date, type, and outcome, linked to Property and Room |
| **Payment Gateway Integration** | Medium | Integrate with a payment gateway (Stripe, PayPal) to allow tenants to pay directly from the community portal and auto-update `Rent_Payment__c.Status__c` to Paid |
| **Community LWC Components** | High | Build LWCs: My Tenancy dashboard, My Invoices list, Notices list, Case creation forms |
| **Document Generation** | Medium | Use Salesforce's OmniStudio or a package (Conga/DocGen) to auto-generate tenancy agreement PDFs |
| **Mobile App** | Low | Experience Cloud is mobile-responsive; consider a branded mobile app for tenants |
| **Report & Dashboard** | Medium | Occupancy rate dashboard, rent roll report, overdue rent report for landlords |
