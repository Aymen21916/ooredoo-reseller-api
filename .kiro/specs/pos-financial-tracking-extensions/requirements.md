# Requirements Document

## Introduction

This feature extends the existing Ooredoo POS system with four interrelated financial-tracking capabilities:

1. **Customer-linked debt recording** — bringing the "Record Client Debt" cashier action up to the same standard as the existing "Sell SIM Card" multi-step flow, with mandatory customer information.
2. **Cashier advance management** — tracking money a cashier withdraws from the register for personal use, with a rolling outstanding balance and admin-recorded repayments.
3. **Register expense logging (La Caisse)** — letting cashiers and admins record operational expenses paid out of the register (utilities, restock purchases, etc.) and have those expenses correctly affect the register cash balance, including the case where today's cash is insufficient.
4. **Advanced date-range reporting** — a calendar-based date-range admin report that consolidates SIM sales, storm/bundle entries, accessory sales, debts, cashier advances, register expenses, and profits across both stores and all cashiers, while keeping cashiers limited to their own data.

All monetary values are in Algerian Dinar (DZD). All new behaviour reuses the existing audit-log, soft-void, session-ownership, and role-based-auth conventions.

## Glossary

- **POS_System**: The Ooredoo reseller point-of-sale application as a whole (Node.js/Express API plus React/Vite client).
- **Cashier_UI**: The cashier-facing portion of the POS_System, accessed by users with role `cashier`.
- **Admin_UI**: The admin-facing portion of the POS_System, accessed by users with role `admin`.
- **Cashier**: An authenticated user with role `cashier`. Owns at most one open `cashier_session` at a time and is bound to a single store.
- **Admin**: An authenticated user with role `admin`. Has cross-store visibility and elevated privileges.
- **Store**: A physical store location. The system has exactly two: AAO Sobha (id 1) and Kiosque Ain Meraine (id 2).
- **Cashier_Session**: One row in `cashier_sessions`. Represents a cashier's work day at a specific store. Status is `open` or `closed`.
- **Customer**: A row in `customers` containing `phone_number`, `first_name`, `last_name`, `address`, `profession`, optional `notes`. Phone number is the unique business key.
- **Active_Cashier**: A user with `role = 'cashier'` AND `is_active = TRUE`.
- **Debt_Record**: A row in `session_debts` describing money a customer owes the store after taking goods or service without full payment.
- **Cashier_Advance**: Money a cashier takes from the register for personal use, tracked in the new `cashier_advances` table.
- **Advance_Repayment**: A reduction of a cashier's outstanding advance balance, recorded as a row in `cashier_advances` with `direction = 'repayment'`. Both directions form a single rolling ledger per cashier.
- **Outstanding_Advance_Balance**: For a given cashier, the sum of all non-voided advance amounts minus the sum of all non-voided repayment amounts. Always greater than or equal to 0.
- **Register_Expense**: A row in the new `register_expenses` table representing money paid out of the register for an operational purpose (e.g. paying a bill, buying restock inventory).
- **Expense_Category**: A label classifying a `Register_Expense`. The initial closed set is `utility`, `inventory`, `other`.
- **Register_Cash_Balance**: For a given store, the cash currently on hand in the register, defined as the latest `cash_amount` value in `store_register_state` for that store (this is the field the existing `updateRegister` endpoint already maintains).
- **Active_Store**: A row in `stores` that has not been logically deleted (the schema does not currently have a soft-delete flag on `stores`; "active" is therefore equivalent to "row exists").
- **Daily_Cash_Inflow**: For a given store and calendar date, the sum across all of that store's sessions on that date of: SIM `selling_price_snapshot` + storm `amount` + accessory `price_snapshot`, all restricted to non-voided rows. Equivalent to the cash side of `v_session_live_totals` aggregated per store per day.
- **Date_Range_Report**: An on-demand (non-persisted) report produced by querying live data plus existing immutable `daily_reports`, scoped to a `[from_date, to_date]` inclusive range.
- **Active_In_Range**: For a Cashier and a date range, "active in range" means the Cashier has at least one non-voided row in any of `session_sim_sales`, `session_storm_entries`, `session_accessory_sales`, `session_debts`, `cashier_advances`, or `register_expenses` whose row date falls in the range.
- **Server_Local_Date**: The calendar date according to the application server's local timezone, used as the comparison basis for `CURRENT_DATE`, `expense_date`, `from_date`, and `to_date`.
- **Void**: The existing soft-delete pattern used on sale/debt rows: setting `is_voided = TRUE`, `voided_at`, `voided_by`, and `void_reason`. Voided rows are excluded from totals.
- **Audit_Log**: The existing `audit_logs` table. Every mutation in this feature MUST produce an entry consistent with the existing `audit_action` enum.

## Requirements

### Requirement 1: Customer-Linked Debt Recording

**User Story:** As a cashier, I want recording a client debt to follow the same multi-step flow as selling a SIM card, with mandatory customer information, so that every debt is traceable to a real customer and the admin can later contact them.

#### Acceptance Criteria

1. WHEN a Cashier clicks "Record Client Debt" in the Cashier_UI, THE Cashier_UI SHALL open a multi-step modal whose first step requires the Cashier to either select an existing Customer (searchable by `phone_number` exact match or by `(first_name || ' ' || last_name)` substring match, case-insensitive) or create a new Customer, and SHALL NOT advance to the second step until exactly one Customer is selected.

2. WHEN the Cashier creates a new Customer from the debt modal, THE Cashier_UI SHALL trim leading and trailing whitespace from each field and then require non-empty values for `phone_number` (8 to 20 characters; allowed characters: digits 0-9 with an optional single leading `+`), `first_name` (1 to 100 characters), `last_name` (1 to 100 characters), `address` (1 to 1000 characters), and `profession` (1 to 100 characters), matching the existing `customers` table NOT NULL constraints.

3. IF the Cashier submits the new-customer form with any field that fails the length, character-set, or non-empty rule defined in criterion 2, THEN THE Cashier_UI SHALL block submission and the POS_System SHALL reject any direct API call with HTTP 400 and error code `VALIDATION_ERROR`, and SHALL NOT insert a `customers` row or a `session_debts` row.

4. WHEN the Cashier confirms the debt at the second (amount) step and the submitted phone number already exists in `customers`, THE POS_System SHALL load the existing Customer record and link the Debt_Record to that existing Customer rather than creating a duplicate, performing the duplicate-prevention check at submission time so the Cashier is not blocked while still entering customer details on the first step.

5. WHEN the Cashier proceeds to the second step of the debt modal, THE Cashier_UI SHALL require an `amount` that is a strictly positive decimal in the closed range [0.01, 9999999999.99] with at most two decimal places, and SHALL accept an optional `description` of 0 to 1000 characters after trimming whitespace.

6. WHILE the Cashier has no `cashier_session` with `status = 'open'`, THE Cashier_UI SHALL disable the "Record Client Debt" entry point and the POS_System SHALL reject any direct debt-creation API call with HTTP 400 and error code `NO_OPEN_SESSION`.

7. WHEN the Cashier confirms the debt, THE POS_System SHALL insert one row into `session_debts` containing the Cashier's open `session_id`, the linked `customer_id`, the validated `amount`, and the optional `description`.

8. THE POS_System SHALL make `customer_id` a NOT NULL foreign key on `session_debts` referencing `customers(id)` with `ON DELETE RESTRICT`.

9. WHERE pre-existing rows in `session_debts` have a NULL `customer_id` at migration time, THE POS_System SHALL link them to a designated placeholder Customer with `phone_number = 'LEGACY-UNKNOWN'`, `first_name = 'Unknown'`, `last_name = 'Customer (legacy)'`, `address = '—'`, `profession = '—'`, creating that Customer idempotently if it does not already exist (so re-running the migration does not create duplicates and respects the `phone_number` UNIQUE NOT NULL constraint).

10. WHEN a Debt_Record is submitted without a linked Customer (programmatic or API-direct call), THE POS_System SHALL reject the request with HTTP 400 and error code `CUSTOMER_REQUIRED` and SHALL NOT insert any row in `session_debts`.

11. WHEN a Cashier views the Cashier_UI debt list for the current session, THE Cashier_UI SHALL display each debt's customer full name, customer `phone_number`, `amount` formatted with thousands separator and two decimal places, and `description` if present (rendered as an em-dash if NULL).

12. WHEN the Admin views debts in any report or list, THE Admin_UI SHALL display the linked Customer's full name, phone number, and profession for each Debt_Record, and SHALL visually distinguish voided rows (e.g. with a "Voided" badge) from non-voided rows.

13. WHEN a Debt_Record is voided, THE POS_System SHALL apply the existing soft-void pattern (`is_voided`, `voided_at`, `voided_by`, `void_reason`) and SHALL exclude voided debts from all totals; AND IF the targeted row already has `is_voided = TRUE`, THEN the POS_System SHALL reject the request with HTTP 409 and error code `ALREADY_VOIDED`.

14. WHEN a debt is created or voided, THE POS_System SHALL write an entry to `audit_logs` with `action = 'INSERT'` or `action = 'VOID'` respectively, including `customer_id`, `session_id`, and `amount` in the `new_values` payload.

### Requirement 2: Cashier Advance and Repayment Tracking

**User Story:** As a cashier, I want to record money I take from the register for personal use as an advance and see my running balance, and as an admin I want to record repayments and see each cashier's outstanding balance, so that personal draws never get confused with sales or expenses.

#### Acceptance Criteria

1. THE POS_System SHALL provide a new table `cashier_advances` with at minimum the columns: `id`, `cashier_id` (NOT NULL FK to `users`), `session_id` (NOT NULL FK to `cashier_sessions` for advance entries; nullable for admin-recorded repayments), `direction` (enum or check constraint with values `'advance'` and `'repayment'`), `amount` (NUMERIC(12,2), CHECK > 0), `note` (TEXT, optional, maximum 500 characters), `is_voided` (BOOLEAN, default FALSE), `voided_at`, `voided_by` (FK to `users`), `void_reason`, `created_at`, `created_by` (NOT NULL FK to `users`).

2. WHEN a Cashier submits an advance entry from the Cashier_UI with an `amount` that is greater than or equal to 0.01 DZD and less than or equal to 9999999999.99 DZD, THE POS_System SHALL insert a row with `direction = 'advance'`, `cashier_id` and `created_by` equal to the Cashier's user id, `session_id` equal to the Cashier's currently open `cashier_session.id`, and `amount` equal to the submitted value.

3. IF a Cashier submits an advance entry with an `amount` that is less than 0.01 DZD, greater than 9999999999.99 DZD, non-numeric, or with more than two decimal places, THEN THE POS_System SHALL reject the request with HTTP 400 and error code `INVALID_AMOUNT` and SHALL NOT insert a row.

4. IF a Cashier has no open `cashier_session` when submitting an advance, THEN THE POS_System SHALL reject the request with HTTP 400 and error code `NO_OPEN_SESSION`.

5. WHEN an Admin records a repayment for a specific Cashier from the Admin_UI with an `amount` that is greater than or equal to 0.01 DZD and less than or equal to 9999999999.99 DZD, THE POS_System SHALL insert a row with `direction = 'repayment'`, `cashier_id` equal to the selected Cashier's id, `created_by` equal to the Admin's id, `session_id` set to NULL, and `amount` equal to the submitted value.

6. IF an Admin attempts to record a repayment whose amount is strictly greater than the Cashier's current Outstanding_Advance_Balance, THEN THE POS_System SHALL reject the request with HTTP 400 and error code `REPAYMENT_EXCEEDS_BALANCE` and SHALL include the current balance in the response payload.

7. THE POS_System SHALL compute Outstanding_Advance_Balance for a Cashier as `SUM(amount) FILTER (direction = 'advance' AND is_voided = FALSE) - SUM(amount) FILTER (direction = 'repayment' AND is_voided = FALSE)`.

8. THE POS_System SHALL expose the Cashier's own Outstanding_Advance_Balance and paginated advance history (ordered by `created_at` descending, default page size 50 rows, maximum page size 200 rows) in a Cashier_UI panel scoped to that Cashier.

9. THE POS_System SHALL expose every Active_Cashier's Outstanding_Advance_Balance in an Admin_UI list, sorted by Outstanding_Advance_Balance descending by default and including each Cashier's full name, store name, and the timestamp of the most recent non-voided advance or repayment row.

10. WHEN an advance row (either direction) is voided, THE POS_System SHALL apply the existing soft-void pattern and SHALL exclude voided rows from Outstanding_Advance_Balance.

11. WHERE the actor voiding an advance row is a Cashier, THE POS_System SHALL allow the void only if the row's `cashier_id` equals the actor's user id AND the row's `session_id` equals the actor's currently open session id; otherwise the void SHALL return HTTP 403 with error code `FORBIDDEN`.

12. WHERE the actor voiding an advance row is an Admin, THE POS_System SHALL allow the void regardless of session state.

13. WHEN any advance row is created or voided, THE POS_System SHALL write an entry to `audit_logs` with the appropriate `action`, `table_name = 'cashier_advances'`, and a `description` indicating direction (`advance` or `repayment`).

14. WHEN a Cashier_Session is closed, THE POS_System SHALL NOT change Outstanding_Advance_Balance; the rolling balance SHALL persist across sessions and across days.

15. THE POS_System SHALL NOT modify `store_register_state` automatically when an advance or repayment is recorded; the register cash adjustment SHALL be performed separately by the Admin via the existing `updateRegister` endpoint, so that advances do not affect the cash count flow without explicit admin action.

### Requirement 3: Register Expense Logging (La Caisse)

**User Story:** As a cashier or admin, I want to log expenses paid out of the register with amount, date, description, and category, so that the register cash balance and reports correctly reflect operational spending, even when the day's cash inflow alone is not enough to cover the expense.

#### Acceptance Criteria

1. THE POS_System SHALL provide a new table `register_expenses` with at minimum the columns: `id`, `store_id` (NOT NULL FK to `stores`), `session_id` (FK to `cashier_sessions`, nullable for admin-recorded expenses), `amount` (NUMERIC(12,2), CHECK between 0.01 and 9999999.99), `expense_date` (DATE, NOT NULL), `description` (TEXT, NOT NULL, length 1 to 500 characters after trimming whitespace), `category` (text/enum, NOT NULL, one of `'utility'`, `'inventory'`, `'other'`), `is_voided` (BOOLEAN, default FALSE), `voided_at`, `voided_by`, `void_reason` (TEXT, length 1 to 500 characters when set), `created_at`, `created_by` (NOT NULL FK to `users`).

2. WHEN a Cashier submits a Register_Expense from the Cashier_UI, THE POS_System SHALL automatically set `store_id` to the Cashier's store, `session_id` to the Cashier's currently open session, `expense_date` to `CURRENT_DATE` evaluated in Server_Local_Date, and `created_by` to the Cashier's user id, ignoring any client-supplied values for these fields.

3. IF a Cashier submits a Register_Expense and has no open session, THEN THE POS_System SHALL reject the request with HTTP 400 and error code `NO_OPEN_SESSION`.

4. IF a Cashier submits a Register_Expense with `expense_date` not equal to `CURRENT_DATE`, THEN THE POS_System SHALL reject the request with HTTP 400 and error code `BACKDATE_FORBIDDEN`.

5. WHEN an Admin submits a Register_Expense from the Admin_UI, THE POS_System SHALL accept any `expense_date` not in the future and any `store_id` referencing a non-deleted row in `stores`, with `session_id` set to NULL and `created_by` equal to the Admin.

6. IF a Register_Expense is submitted with `expense_date` strictly greater than `CURRENT_DATE` (Server_Local_Date), THEN THE POS_System SHALL reject the request with HTTP 400 and error code `FUTURE_DATE`.

7. IF a Register_Expense is submitted with `amount` outside the closed interval [0.01, 9999999.99] DZD, with more than two decimal places, with non-numeric value, with `description` shorter than 1 or longer than 500 characters after trimming whitespace, or with `category` outside the closed set {`'utility'`, `'inventory'`, `'other'`}, THEN THE POS_System SHALL reject the request with HTTP 400, error code `VALIDATION_ERROR`, and a response body listing each failing field; AND the POS_System SHALL NOT insert any row in `register_expenses` and SHALL NOT append any row to `store_register_state`.

8. WHEN a Register_Expense is created, THE POS_System SHALL atomically (within a single SQL transaction that holds a row-level lock on the latest `store_register_state` row for the affected `store_id` via `SELECT ... FOR UPDATE` to prevent concurrent over-spending) append a new row to `store_register_state` for the affected store with `cash_amount` equal to the previous Register_Cash_Balance minus the expense `amount`, and `notes` equal to `"Register expense #<id>: <description>"`.

9. IF the previous Register_Cash_Balance for the store (read under the `SELECT ... FOR UPDATE` lock from criterion 8) is strictly less than the submitted expense `amount`, THEN THE POS_System SHALL reject the request with HTTP 400 and error code `INSUFFICIENT_REGISTER_CASH`, SHALL include the current Register_Cash_Balance in the response payload, AND SHALL NOT insert a row in `register_expenses` and SHALL NOT append any row to `store_register_state` (consistent with the existing `store_register_state.cash_amount >= 0` CHECK constraint).

10. WHEN a Register_Expense is voided, THE POS_System SHALL atomically (within the same SQL transaction that performs the soft-void update from criterion 11, holding a row-level lock on the latest `store_register_state` row for the affected `store_id`) append a new row to `store_register_state` for the affected store with `cash_amount` equal to the previous Register_Cash_Balance plus the voided expense `amount`, and `notes` equal to `"Void of register expense #<id>"`.

11. WHEN a Register_Expense row is voided, THE POS_System SHALL apply the existing soft-void pattern (`is_voided`, `voided_at`, `voided_by`, `void_reason`) and SHALL exclude voided expenses from: register-cash-balance reconciliation queries, the cashier-session totals view (`v_session_live_totals` and any equivalent), the immutable `daily_reports` totals computed at end-of-day generation, and any admin date-range or store-level expense report.

12. IF a void request targets a row that is missing `void_reason`, has `void_reason` shorter than 1 character or longer than 500 characters after trimming whitespace, or has `is_voided = TRUE` already, THEN THE POS_System SHALL reject the request with HTTP 400 and error code `MISSING_VOID_REASON`, `INVALID_VOID_REASON`, or HTTP 409 and error code `ALREADY_VOIDED` respectively, AND SHALL NOT modify `register_expenses` and SHALL NOT append any row to `store_register_state`.

13. WHERE the actor voiding a Register_Expense is a Cashier, THE POS_System SHALL allow the void only if the row's `session_id` is non-null and equals the Cashier's currently open session id AND the Cashier is the original `created_by`; otherwise the void SHALL return HTTP 403 with error code `FORBIDDEN`.

14. WHERE the actor voiding a Register_Expense is an Admin, THE POS_System SHALL allow the void unconditionally on any non-voided row.

15. WHEN any Register_Expense is created or voided, THE POS_System SHALL write an entry to `audit_logs` within the same SQL transaction as the `register_expenses` and `store_register_state` writes, with `table_name = 'register_expenses'`, action `INSERT` or `VOID`, and full `new_values`/`old_values` payloads.

16. THE POS_System SHALL display the Cashier's current-session Register_Expenses in a Cashier_UI panel scoped to the Cashier's open session, ordered by `created_at` descending, paginated with default page size 50 rows and maximum page size 200 rows.

17. THE POS_System SHALL display all Register_Expenses across both Stores in an Admin_UI list ordered by `expense_date` descending then `created_at` descending, paginated with default page size 50 rows and maximum page size 200 rows, filterable by `store_id`, `category`, `expense_date` range, and void status.

### Requirement 4: Advanced Date-Range Reporting

**User Story:** As an admin, I want to pick a calendar date range and see consolidated, per-cashier and per-store financial data across both stores at once, while cashiers see only their own data within that range, so that I can analyse the business across arbitrary periods without flipping between per-day per-store reports.

#### Acceptance Criteria

1. WHEN an authenticated user opens the reports page, THE Cashier_UI and Admin_UI SHALL render a calendar-based date-range picker that allows selecting a `from_date` and a `to_date`, both required, both interpreted as Server_Local_Date, with `to_date >= from_date` and both not strictly greater than `CURRENT_DATE` evaluated in Server_Local_Date.

2. IF a date-range query is submitted with `to_date < from_date`, THEN THE POS_System SHALL reject the request with HTTP 400 and error code `INVALID_DATE_RANGE`.

3. IF a date-range query is submitted with `(to_date - from_date) > 366` days, THEN THE POS_System SHALL reject the request with HTTP 400 and error code `RANGE_TOO_LARGE`.

4. WHEN an Admin submits a date-range query, THE POS_System SHALL return a Date_Range_Report aggregated across both Stores and all Cashiers Active_In_Range.

5. WHEN a Cashier submits a date-range query, THE POS_System SHALL return a Date_Range_Report restricted to that Cashier's own sessions only, regardless of any `store_id` or `cashier_id` filter passed in the request.

6. THE POS_System SHALL include in every Date_Range_Report the following totals, each computed across non-voided rows whose row date (`sold_at` / `entered_at` / `expense_date`, all interpreted as Server_Local_Date) falls within `[from_date, to_date]` inclusive:
   1. `sim_units_sold` (count)
   2. `sim_total_real_price`
   3. `sim_total_selling_price`
   4. `sim_total_points`
   5. `sim_total_commission`
   6. `storm_total`
   7. `accessories_total_selling`
   8. `accessories_total_real`
   9. `accessories_total_commission`
   10. `debt_total` (with linked customer info available in the per-row breakdown)
   11. `cashier_advance_total` (sum of `direction = 'advance'` rows)
   12. `cashier_repayment_total` (sum of `direction = 'repayment'` rows)
   13. `register_expense_total` (sum of non-voided expenses, broken down by category)
   14. `sim_profit` defined as `sim_total_points + sim_total_selling_price - sim_total_real_price`
   15. `accessory_profit` defined as `accessories_total_selling - accessories_total_real`
   16. `gross_profit` defined as `sim_profit + accessory_profit + storm_total - register_expense_total`

7. THE POS_System SHALL include in every Date_Range_Report a per-cashier breakdown row (one row per `cashier_id` Active_In_Range) with the same fields as in criterion 6 plus `cashier_id`, `cashier_full_name`, and `store_id`.

8. WHERE the requesting user is an Admin, THE POS_System SHALL include in every Date_Range_Report a per-store rollup (one row per `store_id`) with the same fields as in criterion 6 plus `store_id` and `store_name`, computed from the per-cashier rows.

9. THE POS_System SHALL exclude voided rows (any row where `is_voided = TRUE`) from every total in the Date_Range_Report. A row voided after creation but inside the range SHALL count as zero for that range.

10. WHERE a Debt_Record falls within the range, THE Date_Range_Report row-level breakdown SHALL include the linked Customer's `full_name`, `phone_number`, and `profession`.

11. WHEN the Date_Range_Report is rendered in the Admin_UI, THE Admin_UI SHALL display tabs or sections for: per-cashier rows, per-store rollup, totals, debts (with customer info), advances/repayments per cashier, and register expenses by category.

12. WHEN the Date_Range_Report is rendered in the Cashier_UI, THE Cashier_UI SHALL display only the requesting Cashier's own per-cashier section and totals.

13. THE POS_System SHALL produce the Date_Range_Report directly from live tables and views (`session_sim_sales`, `session_storm_entries`, `session_accessory_sales`, `session_debts`, `cashier_advances`, `register_expenses`) joined to `cashier_sessions` and `stores`, and SHALL NOT depend on `daily_reports` rows existing for every date in the range.

14. IF a Date_Range_Report query takes longer than 5000 milliseconds end-to-end (database round-trip), THEN THE POS_System SHALL log a warning to the application logger including `from_date`, `to_date`, requesting user id, and elapsed milliseconds.

15. WHEN a Date_Range_Report is generated, THE POS_System SHALL write an entry to `audit_logs` with `action = 'REPORT_GENERATE'`, `description` containing `from_date` and `to_date`, and `user_id` equal to the requesting user.

16. WHEN a Date_Range_Report is generated for a range in which there are no non-voided rows in any of `session_sim_sales`, `session_storm_entries`, `session_accessory_sales`, `session_debts`, `cashier_advances`, or `register_expenses`, THE POS_System SHALL return HTTP 200 with an empty per-cashier breakdown array, an empty per-store rollup array (for Admin requesters), and a totals object whose every numeric field is exactly 0.

## Open Decisions Captured as Defaults

The defaults below are encoded directly in the requirements above and may be revisited during the design phase. They were chosen to match patterns already used elsewhere in the system; flag any that should change.

1. **Cashier advances and register expenses follow the same soft-void pattern as sales/debts.** Both new tables include `is_voided`, `voided_at`, `voided_by`, `void_reason`. (Requirements 2.10, 3.11.)
2. **Cashiers may only void their own current-session entries; admins may void any non-voided entry.** Mirrors the implicit current behaviour of session-scoped row ownership. (Requirements 2.11, 2.12, 3.13, 3.14.)
3. **Register expenses cannot be backdated by cashiers; admins may backdate to any non-future date.** Cashiers always log `CURRENT_DATE`. (Requirements 3.4, 3.5, 3.6.)
4. **"Deduct from total of money when day is not enough" maps onto the existing `store_register_state` (latest-row-wins) running balance.** A register expense always reduces the store's running register cash directly. If the running balance would go below zero, the expense is rejected because `store_register_state.cash_amount` has a `CHECK (cash_amount >= 0)` constraint. The user described this as "deduct from the total of money"; the running register balance is the natural "total of money" because today's cash inflow is already part of it. (Requirement 3.9.) If the user instead meant the `global_pool_state.available_balance`, requirement 3 would need to be revised in the design phase.
5. **Cashier advances do NOT auto-adjust register cash.** This avoids double-counting: the admin still controls register cash via the existing `updateRegister` endpoint. (Requirement 2.15.)
6. **Date-range report grain: one per-cashier row plus one per-store rollup plus grand totals.** Cashiers see only their own per-cashier row plus their totals; admins see all three layers. (Requirements 4.7, 4.8, 4.11, 4.12.)
7. **Voids are reflected immediately in date-range totals; a row voided after the range was first viewed will count as zero on subsequent queries.** Date-range reports are computed on demand and not persisted, so there is no stale snapshot to reconcile. (Requirements 4.9, 4.13.)
8. **Legacy NULL `customer_id` debts are migrated to a placeholder customer named "Unknown Customer (legacy)" with phone `LEGACY-UNKNOWN`.** This preserves historical totals while letting `customer_id` become NOT NULL. (Requirement 1.9.)
9. **Server_Local_Date is the single date-comparison basis.** All `CURRENT_DATE`, `from_date`, `to_date`, `expense_date`, `sold_at`, and `entered_at` comparisons resolve in the application server's local timezone. If the deployment ever spans multiple timezones, criteria 3.2, 3.4, 3.6, 4.1, 4.6 will need revisiting in the design phase.
