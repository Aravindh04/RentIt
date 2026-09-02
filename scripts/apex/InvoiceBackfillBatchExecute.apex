// ── Step 1: Create any missing invoices ─────────────────────────────────────
// Iterates all Activated Contracts from StartDate → today, creates invoices for
// any periods that do not already have a record. Discounts are applied pro-rated
// at creation time. Run this first and wait for it to complete.
Database.executeBatch(new InvoiceBackfillBatch(), 10);

// ── Step 2: Apply discounts to existing invoices ─────────────────────────────
// Run this AFTER Step 1 has finished (check Setup → Apex Jobs for completion).
// Updates Scheduled / Unpaid / Overdue invoices that have no discount applied yet.
// Paid invoices are skipped to avoid retroactively altering settled amounts.
// Database.executeBatch(new InvoiceDiscountBackfillBatch(), 50);
