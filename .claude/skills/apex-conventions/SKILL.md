---
description: Apex and LWC coding conventions for this org. Use when writing or reviewing Apex classes, triggers, or Lightning Web Components.
---

## Apex Conventions
- Bulkify all trigger logic — no SOQL or DML inside loops
- Single trigger per object, handler class delegates logic; handlers live in `force-app/main/default/classes/`
- All classes use `with sharing` unless a comment justifies the exception
- **Community-exposed controllers**: must be `with sharing` — never `without sharing` for tenant-facing methods; annotate with `@AuraEnabled(cacheable=true)` for read-only wire calls
- Use Custom Metadata Types for config values — never hardcode Ids or record type names
- Batch classes (e.g., `InvoiceBatch`) implement `Database.Batchable<SObject>` and are scheduled via `InvoiceScheduler`

## Testing
- Minimum 90% coverage on all new classes
- Use `@TestSetup` for shared data; create a TestDataFactory pattern if one doesn't exist yet
- Assert positive path, error path, and bulk (200-record) scenarios
- For community controllers: run assertions as a User assigned the `RentIt_Tenant` permission set using `System.runAs()` to verify sharing boundaries are enforced

## LWC Conventions
- All LWCs in `force-app/main/default/lwc/`; community-facing components prefixed `rentit` (e.g., `rentitPaymentForm`, `rentitTenancySummary`)
- Prefer `@wire` adapters over imperative Apex — wire calls respect FLS and sharing automatically:
  - `@wire(getRecord, { recordId: '$recordId', fields: [...] })` for single record
  - `@wire(getRelatedListRecords, ...)` for child lists (Invoices under Tenancy, Payments under Invoice)
- Use `NavigationMixin` from `lightning/navigation` for all page navigation — never hardcode URLs
- Import current user: `import userId from '@salesforce/user/Id'`
- Use `lightning-record-form` or `lightning-record-edit-form` for CRUD — inherits FLS automatically
- Embed multi-step actions (payment submission, complaint) in `<lightning-flow>` screen flows
- Error handling: surface errors via `<lightning-messages>` or `<p class="slds-text-color_error">`; never fail silently
- `.js-meta.xml`: set `isExposed: true` and `targets` to `lightningCommunity__Page` / `lightningCommunity__Default` for community components
