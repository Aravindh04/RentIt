# RentIt Portal — Tenant Feedback Log

> All feedbacks are from portal (Experience Cloud LWR) tenant users.
> Status: ✅ Done · 🚧 In Progress · ⏳ Pending

---

## ✅ Feedback 1 — Lodge a Complaint / Make a Request
**Request:** The tenant should be able to lodge a complaint and make a maintenance request.
**Resolution:** `rentitSupportHub` component built with two sub-tabs — **Complaint** (maps to Case, Type = Complaint) and **Maintenance** (maps to Case, Type = Maintenance Request). Tenant can submit and view their open cases.

---

## ✅ Feedback 2 — Payment Against Invoice or Generic Rent Credit
**Request:** Payments can be against invoices or generic rent payments logged as credits.
**Resolution:** `rentitPaymentForm` allows the tenant to select an invoice (optional) or leave it blank for a generic credit payment. Both flows submit a `Payment__c` record linked to the tenancy.

---

## ✅ Feedback 3 — Submit Payment for Approval
**Request:** User should be able to submit rent/invoice payments for approval. Update permissions and portal.
**Resolution:** `submitPayment` Apex method creates a `Payment__c` with `Status = Pending`. Landlord approves/rejects via admin portal. Permission set grants `Payment__c` create access to tenants.

---

## ✅ Feedback 4 — Task Created for Overdue/Unpaid Payments + Email Notifications
**Request:** A Task must be created for overdue and unpaid payments. User notified by email using 2 different templates.
**Resolution:** Two Flows created — one for overdue invoice tasks and one for unpaid payment tasks. Two Email Templates created and linked to the respective Flows.

---

## ✅ Feedback 5 — Logout Not Working Correctly
**Request:** Portal logout takes user to the standard employee login screen without actually logging them out.
**Resolution:** `handleLogout()` in `rentitHeader.js` now navigates to `/secur/logout.jsp?retUrl=<community-login-url>`, forcing a proper logout and redirect to the community login page.

---

## ✅ Feedback 6 — Auto-assign Community Profile + Permission Set on User Creation
**Request:** When a portal/external user is created and linked to an active Tenancy, they must be added to `RentIt_Community_Tenants` and assigned the `RentIt_Tenant` permission set.
**Resolution:** A Flow triggers on User creation (ExternalIdentity profile). It assigns the community public group and the `RentIt_Tenant` permission set automatically.

---

## ✅ Feedback 7 — Merge Maintenance and Complaint into One Tab
**Request:** Maintenance and Complaint are similar. Merge them into one tab with sub-tabs or dropdowns.
**Resolution:** `rentitSupportHub` acts as the merged "Support" tab. Inside, two sub-tabs — **Complaint** and **Maintenance** — are presented as pill-style toggle buttons. No separate tabs in the header.

---

## ✅ Feedback 8 — Combine Make Payment and Payment History Under One Tab
**Request:** Make Payment and Payment History should be combined under one tab with sub-tabs or expandable sections.
**Resolution:** `rentitPaymentHub` serves as the unified "Payments" tab. It contains **Make Payment** and **Payment History** as sub-tab sections rendered inline.

---

## ✅ Feedback 9 — Categorise Invoices by Type and Status
**Request:** Invoices are dumped in one area. Categorise using invoice type and status like Payment History.
**Resolution:** `rentitInvoiceList` has two filter rows — a **Status** pill bar (All / Scheduled / Unpaid / Overdue / Paid) and a **Type** pill bar (All / Rent / Utilities). Filters are applied together client-side.

---

## ✅ Feedback 10 — Highlight Active Tab in Header
**Request:** The active tab in the header should be highlighted when clicked.
**Resolution:** `rentitHeader.js` uses `CurrentPageReference` to detect the active URL segment. Active nav item gets a bottom border (`border-bottom: 2px solid #fff`) with no background — Airtel-style underline, no rounded box.

---

## ✅ Feedback 11 — Facilities Shown as Pills
**Request:** The facilities in My Tenancy should be displayed as pills or a nice design.
**Resolution:** `rentitTenancySummary` splits the `Facilities__c` multi-select picklist on `;` and renders each value as a styled pill in the Room section.

---

## ✅ Feedback 12 — Tenant Can View Contract Information (Read-Only)
**Request:** Tenants should be able to view their Contract information but not edit any.
**Resolution:** `RentIt_Tenant` permission set grants read-only access to `Contract` and its key fields. `RentItPortalDataHelper` (without sharing) validates tenancy ownership, then queries Contract. Note: Salesforce does not support community Sharing Sets or ContractShare for Contract — the without-sharing helper pattern with user-mode validation is the required workaround.

---

## ✅ Feedback 13 — Rent Amount Comes from Contract
**Request:** The rent shown on My Tenancy should come from the Contract, not `Room.Weekly_Rent__c`.
**Resolution:** `rentitTenancySummary` wires `getContract` and displays `contract.Rent_Amount__c` / `contract.Rent_Frequency__c` in the Room section when a contract exists.

---

## ✅ Feedback 14 — Address Information from Property
**Request:** The address information should come from the Property record.
**Resolution:** `getActiveTenancy` queries `Property__r.Address__Street__s`, `Address__City__s`, `Address__StateCode__s`, `Address__PostalCode__s`, `Address__CountryCode__s`. The `propertyAddress` getter formats these into a single display string.

---

## ✅ Feedback 15 — View Profile Shows Contact + User Info
**Request:** On click of View Profile, the tenant should see their own Contact and User information instead of My Tenancy.
**Resolution:** `rentitProfile` LWC page created at `/profile`. It shows User fields (from `@wire(getRecord)`) and Contact fields (from `getContactProfile` Apex). Includes Business & Tax section with ABN, GST Registered, GST Number.

---

## ✅ Feedback 16 — Full Contract Visible Including Attached Documents
**Request:** The entire Contract should be visible to the portal user including attached documents.
**Resolution:** `rentitContractDetail` LWC added. It shows all contract fields (ContractNumber, Status, Start/End Date, Rent Amount, Rent Frequency, Deposit, Special Conditions). `getContractFiles` Apex method retrieves `ContentDocumentLink` records via `RentItPortalDataHelper`. Download links use `/sfc/servlet.shepherd/document/download/{ContentDocumentId}`.

---

## ✅ Feedback 17 — Contract on Its Own Page with Collapsible Attachments
**Request:** Best to isolate the Contract in a new page, with attachments in a collapsible section.
**Resolution:** New Experience Builder page created at `/my-contract` (`sfdc_cms__view/My_Contract` + `sfdc_cms__route/My_Contract__c`). Contract section removed from `rentitTenancySummary`; replaced with a compact CTA banner showing ContractNumber + Status + "View Contract →" button. The attachments section inside `rentitContractDetail` is a collapsible toggle (Feedback 17 requirement).

---

## ✅ Feedback 18 — Invoice Number Clickable with Discount Indicator
**Request:** The invoice number on the Invoices tab should be clickable. Show a "Discount Applied" indicator if `Applied_Discount__c` (i.e., `Discount__c`) is set on the invoice.
**Resolution:** Invoice name in the list view is styled as a blue underlined link. When `Discount__c` is `true`, an orange "Discount Applied" pill badge is shown beside the invoice name. `Discount__c` and `Discount_Amount__c` added to `getInvoices` SOQL query. Full row remains clickable to open the detail view.

---

## ✅ Feedback 19 — Invoice Detail View with Collapsible Discount Section
**Request:** On click of the invoice number, show invoice detail in the same page with a back arrow button. Discount information in a collapsible section if discount was applied.
**Resolution:** The existing inline detail panel in `rentitInvoiceList` now includes a collapsible "Discount Details" section that appears only when `Discount__c = true`. It shows "Discount Applied: Yes" and `Discount_Amount__c`. Back button updated to use a `utility:chevronleft` icon.

---

## ✅ Feedback 20 — Payment Detail with Collapsible Attachments; Rename Reference Column
**Request:** Same collapsible attachment pattern for payments. Replace "Reference" column with "Payment Name". Payments show their screenshot attachment in a collapsible section.
**Resolution:**
- List view: "Reference" column renamed to **Payment Name**, now shows `pmt.Name` (styled as a blue underlined link).
- Detail view: title changed from `Payment_Reference__c` to `Name`. Reference shown as a detail row inside the panel. Collapsible "Attachments" section added, wiring `getPaymentFiles` Apex method via `RentItPortalDataHelper.getPaymentFilesForTenancy` (validates tenancy + payment ownership before querying `ContentDocumentLink`).

---

## ✅ Feedback 21 — Invoice Payment: Auto-fill Amount and Make Read-Only on Invoice Selection
**Request:** On the 'Invoice Payment' of Payments, if the user chooses an invoice or switches to another invoice, the field values (particularly Amount) must update to match the selected invoice, and the Amount field must become read-only.
**Resolution:** `rentitPaymentForm.js` builds an `_invoiceMap` (id → invoice record) after loading. `handleInvoiceChange` now calls `_applyInvoiceAmount(invoiceId)` which sets `amount = invoice.Balance_Due__c` and `isAmountReadOnly = true`. Amount field in HTML gets `read-only={isAmountReadOnly}`.

---

## ✅ Feedback 22 — Switching Invoice Updates Amount
**Request:** While the invoice is defaulted on Invoice Payment, if the user switches to another invoice, the Amount must update accordingly.
**Resolution:** Same as Feedback 21 — `handleInvoiceChange` always calls `_applyInvoiceAmount` on every combobox change, updating the amount and keeping it read-only.

---

## ✅ Feedback 23 — Switching to General Payment Clears Values; Switching Back Restores Them
**Request:** If the portal user switches from Invoice Payment to General Payment, invoice-related values should be cleared. When switched back to Invoice Payment, they should be filled in again.
**Resolution:** `handleTypeGeneral()` clears `amount = null` and sets `isAmountReadOnly = false` (amount becomes user-editable). `selectedInvoiceId` is NOT cleared — it's remembered. `handleTypeInvoice()` re-calls `_applyInvoiceAmount(selectedInvoiceId)` to restore the invoice balance and read-only state when switching back.

---

## ✅ Feedback 24 — Hide "Make a Payment" Button for Paid Invoices
**Request:** The "Make a Payment" button on the Invoice Detail must not be visible for paid invoices.
**Resolution:** Added `get isPaidInvoice()` getter in `rentitInvoiceList.js` checking `selectedInvoice.Status__c === 'Paid'`. The detail actions div is wrapped in `template if:false={isPaidInvoice}` so the button is hidden for paid invoices.

---

## ✅ Feedback 25 — "Make a Payment" Button Navigates to Invoice Payment Section with Pre-selected Invoice
**Request:** When "Make a Payment" is clicked on the Invoice Detail, the user should be taken to the Invoice Payment section of Make a Payment with that invoice pre-selected.
**Resolution:** `handleMakePayment()` in `rentitInvoiceList.js` now navigates to `/payments?invoiceId={invoiceId}`. `rentitPaymentHub.js` wires `CurrentPageReference` and forces `activeTab = 'make'` when `invoiceId` is in the URL. `rentitPaymentForm.js` wires `CurrentPageReference`, parses the `invoiceId` query param after invoices load via `_applyPreselectedInvoice()`, and auto-selects the invoice (amount auto-fills, read-only applied).

---

## ✅ Feedback 26 — Dynamic Invoice Detail Metrics: Show Amount/Discount/GST Conditionally
**Request:** On Invoice Details, dynamically include the Original Amount and Discount Amount if a discount is applied. Dynamically remove the GST Amount if there is none.
**Resolution:** Added `Amount__c` to the `getInvoices` SOQL query. Added getters: `selectedHasDiscount`, `selectedHasGst`, `selectedOriginalAmount`, `selectedDiscountAmount`, `selectedGstAmount`. In the detail metrics section: **Original Amount** and **Discount Applied** (green, with − prefix) appear only when `Discount_Amount__c > 0`. **GST Amount** appears only when `GST_Amount__c > 0`. **Total Amount**, **Total Paid**, **Balance Due** always shown.

---

## ✅ Feedback 27 — Spinner in Invoices Tab Below TYPE Filter (Not Above It)
**Request:** On the Invoices tab, the spinner is visible below the STATUS choices (All/Scheduled/Unpaid/Overdue/Paid). Instead, it must appear below the TYPE selection (Type: All/Rent/Utilities), in the content area where results will load.
**Resolution:** Moved the `ri-spinner-wrap` block from outside `showList` (where it rendered above the filter tabs) to inside `showList`, directly after the category filter tabs. The spinner now correctly appears in the result area, below both the status and type filter rows.

---

## ✅ Feedback 28 — Discount Details Shows Discount Period and Invoice Coverage Days
**Request:** The Discount Details collapsible should also highlight the discount period (start and end date of the Discount record) and how many days of the invoice period are covered by that discount.
**Resolution:** Added `Discount__r.Start_Date__c` and `Discount__r.End_Date__c` to the `getInvoices` SOQL. Added `discountPeriodStart`, `discountPeriodEnd`, `discountHasPeriodInfo`, and `discountCoverageText` getters in `rentitInvoiceList.js`. `discountCoverageText` computes the overlap between the invoice period and the discount period and returns "N of M days". Two new rows added to the Discount Details collapsible: **Discount Period** (formatted dates; "Open-ended" when no end date) and **Coverage** (e.g., "17 of 31 days"). `End_Date__c` is not a required field — if stripped by FLS, it gracefully falls back to "Open-ended" and uses the invoice end date for coverage calculation.

---

## ✅ Feedback 29 — Discount Details Section Slightly Darker Background
**Request:** The Discount Details collapsible section should be a slightly darker shade, similar to the Invoice List table header colour.
**Resolution:** Changed `.ri-collapsible-toggle { background }` in `rentitInvoiceList.css` from `#F7F9FC` to `#EEF2F7`, which matches the invoice table header background exactly. The body section remains `#fff` (white) — only the toggle/header bar of the collapsible was darkened.

---

## ✅ Feedback 30 — My Tenancy Tab Shows Spinner While Loading
**Request:** The My Tenancy tab does not display a spinner while loading. It shows "No active tenancy found." immediately instead of waiting for the data to resolve.
**Resolution:** The `@wire` adapter for cacheable Apex fires an initial cycle with `{data: undefined, error: undefined}` before the server responds. The old handler called `this.isLoading = false` unconditionally, so the empty state appeared immediately. Fixed `wiredTenancy` to use the full wire result object: `isLoading` is now only set to `false` when `result.data !== undefined` (including `null` when no active tenancy exists) or `result.error` is set. The spinner stays until the wire genuinely resolves.

---

## ✅ Feedback 31 — Make a Payment Uses Full Available Width; Better Landscape/Portrait Layout
**Request:** The Make a Payment form has a lot of unused width space. Make better use of the space and improve the form layout in both landscape and portrait views.
**Resolution:** Removed the `max-width: 680px` constraint from `.ri-card` in `rentitPaymentForm.css`. Updated `.ri-field-row` to use a **3-column grid** for wide screens (Amount / Date / Method in one row), collapsing to 2 columns at ≤767px and 1 column at ≤480px. Payment Reference and Comment are now in a **2-column inner sub-grid** (`.ri-field-row--2col`) spanning the full row, giving them side-by-side layout on wider screens. Body padding increased slightly to breathe in the wider layout.

---

## ✅ Feedback 32 — More Space Between Invoice Detail and Discount Details
**Request:** On the Invoice Details in the Invoices tab, add more space between the invoice detail section and the Discount Details collapsible.
**Resolution:** Added `ri-collapsible-section--spaced` modifier class to the discount collapsible wrapper, applying `margin-top: 1.25rem` to create clear visual separation from the invoice detail rows above it.

---

## ✅ Feedback 33 — Discount Details Should Show Discount Type and Value
**Request:** The Discount Details collapsible should also show the discount type and the original discount value (not just the applied amount).
**Resolution:** `Discount_Type__c` and `Discount_Value__c` are required fields with universal FLS Read for all profiles, so they are accessible via relationship query (`Discount__r.Discount_Type__c`, `Discount__r.Discount_Value__c`) directly in `getInvoices` using `WITH USER_MODE`. Three rows now shown in the collapsible: **Type**, **Discount Value**, **Applied Amount** (pro-rated).

---

## ✅ Feedback 34 — Discount Value Formatted with $ or % Based on Type
**Request:** Based on the discount type, the discount value should display with a `$` symbol for Fixed Amount or a `%` symbol for Percentage.
**Resolution:** Added `discountIsPercentage` and `discountIsFixed` getters in `rentitInvoiceList.js`. In the HTML, the Discount Value row uses `template if:true={discountIsPercentage}` to render `{discountValue}%` and `template if:true={discountIsFixed}` to render the value via `lightning-formatted-number` with `format-style="currency"`. Type label displayed as a colour-coded pill badge (blue = Percentage, green = Fixed Amount).