# Implementation Plan: POS Financial Tracking Extensions

Convert the feature design into a series of prompts for a code-generation LLM that will implement each step with incremental progress. Make sure that each prompt builds on the previous prompts, and ends with wiring things together. There should be no hanging or orphaned code that isn't integrated into a previous step. Focus ONLY on tasks that involve writing, modifying, or testing code.

## Overview

The implementation proceeds backend-first:

1. Database migration introduces the `customer_id` link on `session_debts`, the placeholder customer, the `cashier_advances` and `register_expenses` tables, and rebuilds `v_session_live_totals` to net out non-voided register expenses.
2. Shared validators and the test scaffolding (fast-check + DB integration harness) land next so every later property test can reuse them.
3. Each financial domain — debts with customer link, cashier advances, register expenses — gets its controller, routes, and property tests in turn.
4. Cross-cutting properties (open-session prerequisite, void access control, audit-log invariants, voids excluded from aggregates) are tested once all three domains exist.
5. The date-range report endpoint reads from those tables and adds its own property tests plus the slow-query and empty-range integration cases.
6. Frontend components and pages are added and wired into the existing `POSDashboard`, `Layout`, and `App` routing.

The stack is **Node.js/Express + PostgreSQL on the API side** and **React/Vite + Vitest on the client side**, matching the existing codebase. Property tests use **fast-check** against an isolated PostgreSQL test schema.

## Tasks

- [x] 1. Database migration and test infrastructure
  - [x] 1.1 Create migration `migrations/1000000000005_financial-extensions.js`
    - Idempotently insert the `LEGACY-UNKNOWN` placeholder customer (`ON CONFLICT (phone_number) DO NOTHING`).
    - Add `customer_id INT REFERENCES customers(id) ON DELETE RESTRICT` to `session_debts`, backfill NULL rows to the placeholder, then `SET NOT NULL` and create `idx_debts_customer`.
    - Create `cashier_advances` table with all columns, CHECK constraints, the `advance_has_session` constraint, and the three indexes from the design.
    - Create `register_expenses` table with all columns, CHECK constraints, and the four indexes from the design.
    - Rebuild `v_session_live_totals` so the cash-on-hand projection subtracts `SUM(register_expenses.amount) FILTER (is_voided = FALSE)` for the session.
    - Provide a symmetric `down` migration that drops the new tables and the `customer_id` column but leaves the placeholder customer in place.
    - _Requirements: 1.8, 1.9, 2.1, 3.1, 3.11_

  - [ ]* 1.2 Write property test for migration idempotency
    - **Property 7: Migration backfills NULL `customer_id` idempotently**
    - Generate arbitrary pre-migration `session_debts` rows with NULL `customer_id`, run the migration twice via the `node-pg-migrate` programmatic API against a temporary schema, and assert that every row references a single `LEGACY-UNKNOWN` customer with the same `id` after both runs and that no duplicate placeholder exists.
    - **Validates: Requirements 1.9**

  - [x] 1.3 Add fast-check and DB-backed test scaffolding
    - Add `fast-check` as a dev dependency in the root `package.json`.
    - Create `tests/integration/setup.js` that connects to a dedicated test database (re-uses the existing `docker-compose.yml` Postgres), exposes a `truncateFinancialTables()` helper, and registers a Vitest `beforeEach` hook to reset `session_debts`, `cashier_advances`, `register_expenses`, `store_register_state`, and `audit_logs` between iterations.
    - Add a Vitest configuration entry that points at the new integration suite and captures the fast-check seed in CI logs.
    - _Requirements: testing infrastructure for Requirements 1, 2, 3, 4_

- [x] 2. Shared validation utilities
  - [x] 2.1 Extend `src/utils/validators.js`
    - Add `validateCustomerFields({ phone_number, first_name, last_name, address, profession })` enforcing length/charset rules (post-trim) from the design's "Field Validation Rules" table.
    - Add `validateAmount(value, { min, max, decimals_allowed = 2 })` returning either a normalized `Number` or throwing `AppError('VALIDATION_ERROR', 400)`.
    - Add `validateVoidReason(reason)` enforcing 1..500 chars after trim and emitting `MISSING_VOID_REASON` / `INVALID_VOID_REASON`.
    - Add `parseDateOnly(value)` that accepts only `YYYY-MM-DD`, and `validateDateRange(from, to)` enforcing `to >= from`, `to <= CURRENT_DATE`, `(to - from) <= 366` days.
    - Export the new helpers for reuse across controllers and tests.
    - _Requirements: 1.2, 1.3, 1.5, 2.3, 3.7, 4.1, 4.2, 4.3_

  - [ ]* 2.2 Write property test for customer field validation
    - **Property 1: Customer field validation accepts only well-formed inputs**
    - **Validates: Requirements 1.2, 1.3**

  - [ ]* 2.3 Write property test for numeric amount validation
    - **Property 2: Numeric amount validation rule (parameterised)**
    - Run the same property under three configurations: debt amounts (`0.01..9_999_999_999.99`, 2 dp), advance amounts (same), expense amounts (`0.01..9_999_999.99`, 2 dp).
    - **Validates: Requirements 1.5, 2.3, 3.7**

- [x] 3. Customer-linked debt recording
  - [x] 3.1 Update `salesController.recordDebt`
    - Require `customer_id` in the body; reject missing with `CUSTOMER_REQUIRED` (HTTP 400).
    - Validate that the cashier has an open session (otherwise `NO_OPEN_SESSION`).
    - Re-validate `amount` and `description` using the new validator helpers.
    - Lookup the customer by `id`; if not found return `CUSTOMER_NOT_FOUND` (HTTP 404).
    - When the modal sends a phone-only payload (existing customer flow), resolve by phone and link to that customer instead of creating a duplicate (defer to the existing `customersController.findOrCreate` helper if it exists, otherwise issue a `SELECT ... WHERE phone_number = $1` first).
    - Insert `session_debts` row with the resolved `customer_id`, fire-and-forget audit log (`action='INSERT'`, `new_values` includes `customer_id`, `session_id`, `amount`).
    - Return the persisted row plus `customer_name` (concatenated `first_name || ' ' || last_name`).
    - _Requirements: 1.4, 1.7, 1.8, 1.10, 1.14_

  - [x] 3.2 Update `salesController.voidTransaction` to handle the customer-linked debt path
    - When `type === 'debt'`, ensure the customer link is preserved on the voided row and the audit log carries `customer_id` in `old_values`.
    - Reject already-voided rows with HTTP 409 and code `ALREADY_VOIDED`.
    - Validate `void_reason` via the shared helper.
    - _Requirements: 1.13, 1.14_

  - [ ]* 3.3 Write property test for existing-phone customer reuse
    - **Property 3: Debt submission with existing phone links to existing customer**
    - **Validates: Requirements 1.4**

  - [ ]* 3.4 Write property test for mandatory customer link
    - **Property 4: Every debt insert is linked to a customer**
    - **Validates: Requirements 1.7, 1.8, 1.10**

  - [ ]* 3.5 Write property test for debt insert field preservation
    - **Property 6: Successful debt insert preserves submitted fields**
    - **Validates: Requirements 1.7**

- [x] 4. Cashier advances backend
  - [x] 4.1 Create `src/controllers/advancesController.js`
    - Implement `createAdvance` (cashier-only): validate amount, require open session, insert row with `direction='advance'`, audit log.
    - Implement `createRepayment` (admin-only): validate amount, look up the cashier (404 `CASHIER_NOT_FOUND` if missing/inactive), compute current `outstanding_balance` using the SQL from the design, reject with `REPAYMENT_EXCEEDS_BALANCE` (and the current balance in the payload) if the amount exceeds it, otherwise insert with `direction='repayment'`, `session_id=NULL`.
    - Implement `getMyAdvances` (cashier): paginate (default 50, max 200), return `{ outstanding_balance, items }`.
    - Implement `getAllAdvances` (admin): return one row per active cashier with `outstanding_balance`, `last_activity_at`, sorted desc by balance.
    - Implement `getCashierAdvances` (admin): per-cashier drill-down with paginated history and current balance.
    - Implement `voidAdvance`: shared by cashier (own current-session row only) and admin (any non-voided row); validate `void_reason`; reject already-voided with 409 `ALREADY_VOIDED`; audit log.
    - All audit writes use the existing `audit()` helper with `table_name='cashier_advances'`.
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 2.10, 2.11, 2.12, 2.13_

  - [x] 4.2 Create `src/routes/advancesRoutes.js` and register at `/api/advances` in `src/server.js`
    - Apply `authenticate` to the whole router.
    - Mount `POST /` and `GET /me` and `POST /:id/void` behind `authorize('cashier','admin')` (handlers branch on role internally).
    - Mount `POST /repayment`, `GET /`, `GET /cashier/:id` behind `authorize('admin')`.
    - Add `app.use('/api/advances', advancesRoutes)` next to the existing route registrations in `src/server.js`.
    - _Requirements: 2.2-2.13_

  - [ ]* 4.3 Write property test for outstanding balance formula
    - **Property 8: Outstanding advance balance formula**
    - **Validates: Requirements 2.7, 2.10, 2.14**

  - [ ]* 4.4 Write property test for repayment ceiling
    - **Property 9: Repayment cannot exceed outstanding balance**
    - **Validates: Requirements 2.6**

  - [ ]* 4.5 Write property test for advance scope isolation
    - **Property 10: Advance scope isolation**
    - **Validates: Requirements 2.8, 2.9**

  - [ ]* 4.6 Write property test for session-close balance invariance
    - **Property 11: Closing a session does not change the advance balance**
    - **Validates: Requirements 2.14**

  - [ ]* 4.7 Write property test for advance non-effect on register cash
    - **Property 12: Advances and repayments do not auto-modify register cash**
    - **Validates: Requirements 2.15**

- [x] 5. Register expenses backend
  - [x] 5.1 Create `src/controllers/expensesController.js`
    - Implement `createExpense` for both roles using the existing `withTransaction` helper:
      1. Validate `amount`, `description`, `category` via the shared validators.
      2. For cashier role: derive `store_id` from the cashier's `users.store_id`, `session_id` from the open session (else `NO_OPEN_SESSION`), require `expense_date == CURRENT_DATE` (else `BACKDATE_FORBIDDEN`).
      3. For admin role: accept `store_id` and `expense_date` from the body, set `session_id = NULL`; reject `expense_date > CURRENT_DATE` with `FUTURE_DATE`.
      4. Open transaction, run `SELECT * FROM store_register_state WHERE store_id = $1 ORDER BY id DESC LIMIT 1 FOR UPDATE`.
      5. If `previous.cash_amount < amount`, rollback with HTTP 400 `INSUFFICIENT_REGISTER_CASH` and include `current_balance` in the payload.
      6. Insert into `register_expenses`, then insert a new `store_register_state` row with `cash_amount = previous - amount` and `notes = 'Register expense #<id>: <description>'`.
      7. Insert audit-log entries for both writes inside the same transaction.
      8. Return the persisted expense plus `register_balance_after`.
    - Implement `listMyExpenses` (cashier, scoped to current session, paginated 50/200).
    - Implement `listAllExpenses` (admin, filters: `store_id`, `category`, `from`, `to`, `voided`, paginated; ordered by `expense_date DESC, created_at DESC`).
    - Implement `voidExpense` symmetrically: validate `void_reason`, reject `ALREADY_VOIDED`, enforce role-based access (cashier ⇒ own current-session only; admin ⇒ any), within a transaction insert a new `store_register_state` row adding the amount back and audit-log both updates.
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10, 3.11, 3.12, 3.13, 3.14, 3.15, 3.16, 3.17_

  - [x] 5.2 Create `src/routes/expensesRoutes.js` and register at `/api/finances/expenses` in `src/server.js`
    - Define a sub-router with `authenticate` applied globally; do NOT use the existing finance router's blanket `authorize('admin')`.
    - Mount cashier+admin endpoints (`POST /`, `POST /:id/void`) with `authorize('cashier','admin')` and admin-only endpoints (`GET /`) with `authorize('admin')`; mount `GET /me` with `authorize('cashier')`.
    - In `src/server.js`, mount the new sub-router at `/api/finances/expenses` BEFORE the existing `app.use('/api/finances', financesRoutes)` so the admin-only middleware on `financesRoutes` does not block cashiers from `/api/finances/expenses`.
    - _Requirements: 3.1-3.17_

  - [ ]* 5.3 Write property test for cashier expense auto-fill
    - **Property 13: Cashier expense auto-fills server-derived fields**
    - **Validates: Requirements 3.2**

  - [ ]* 5.4 Write property test for date constraints
    - **Property 14: Date constraints on expense creation**
    - **Validates: Requirements 3.4, 3.5, 3.6**

  - [ ]* 5.5 Write property test for insufficient-balance rejection
    - **Property 15: Insufficient register balance rejects expense**
    - **Validates: Requirements 3.9**

  - [ ]* 5.6 Write property test for register balance algebra
    - **Property 16: Register balance algebra under expense create/void**
    - **Validates: Requirements 3.8, 3.10**

  - [ ]* 5.7 Write property test for concurrent expense safety
    - **Property 18: Concurrent expense creation does not over-spend the register**
    - Use `Promise.all` with multiple parallel POSTs against the integration suite. Reduce iteration count to 50 to keep CI runtime reasonable.
    - **Validates: Requirements 3.8**

- [ ] 6. Cross-cutting financial-mutation properties
  - [ ]* 6.1 Write property test for open-session prerequisite
    - **Property 5: Open-session prerequisite for cashier-only mutations**
    - Exercises `POST /api/sales/debt`, `POST /api/advances`, and `POST /api/finances/expenses` in the same property.
    - **Validates: Requirements 1.6, 2.4, 3.3**

  - [ ]* 6.2 Write property test for voided-row exclusion from aggregates
    - **Property 17: Voided rows are excluded from every total**
    - Asserts the property across the outstanding-advance balance, the live register balance, `v_session_live_totals`, and the date-range report totals (the report path can be stubbed at the SQL layer to avoid HTTP setup).
    - **Validates: Requirements 1.13, 2.10, 3.11, 4.9**

  - [ ]* 6.3 Write property test for void access control
    - **Property 19: Void access control**
    - Covers debts, advances, and expenses in a single parametrised property.
    - **Validates: Requirements 1.13, 2.11, 2.12, 3.13, 3.14**

  - [ ]* 6.4 Write property test for idempotent void rejection
    - **Property 20: Idempotent void rejection**
    - **Validates: Requirements 1.13, 3.12**

  - [ ]* 6.5 Write property test for audit-log presence and atomicity
    - **Property 21: Audit log written on every successful mutation**
    - For register-cash mutations, additionally assert that the audit row, `register_expenses` row, and `store_register_state` row appear in the same transaction by checking they share a `now()`-bracketing window when one of them is rolled back via a probe error.
    - **Validates: Requirements 1.14, 2.13, 3.15, 4.15**

- [x] 7. Backend checkpoint
  - Ensure all tests pass, ask the user if questions arise.

- [x] 8. Date-range report backend
  - [x] 8.1 Add `getDateRangeReport` to `src/controllers/reportsController.js`
    - Parse `from` and `to` via `parseDateOnly` and validate via `validateDateRange` (errors: `INVALID_DATE_RANGE`, `RANGE_TOO_LARGE`, `FUTURE_DATE`).
    - Branch on role: cashier scope appends `WHERE cs.cashier_id = $current_user_id` to every CTE; admin scope is unrestricted.
    - Build the single CTE-based query from the design (one CTE per source table keyed on `(cashier_id, store_id)` for sale tables, on `cashier_id` for advances, and on `(store_id, category)` for expenses), then LEFT JOIN to project the per-cashier shape.
    - In application code, roll up per-cashier rows into per-store (admin only) and grand totals; compute `sim_profit`, `accessory_profit`, `gross_profit` per the formulas in Requirement 4.6.
    - Build the `debts` array including `customer.full_name`, `phone_number`, `profession` for every non-voided debt in the range.
    - Build the `advances` summary (one row per cashier with `advance_total`, `repayment_total`, `outstanding_balance`).
    - Time the database round-trip; if elapsed > 5000 ms call `logger.warn({ from, to, user_id, elapsed_ms }, ...)`.
    - Write an audit-log entry with `action='REPORT_GENERATE'`, `description='Date range report from=… to=…'`, `user_id` of the requester.
    - Return HTTP 200 with the full payload (zero totals and empty arrays when no rows exist in range).
    - _Requirements: 4.1, 4.2, 4.3, 4.6, 4.7, 4.8, 4.9, 4.10, 4.13, 4.14, 4.15, 4.16_

  - [x] 8.2 Add `GET /api/reports/range` route allowing cashiers
    - In `src/routes/reportsRoutes.js`, define a separate sub-router that applies `authenticate` + `authorize('cashier','admin')` (instead of the existing admin-only middleware) and mount only the new range endpoint on it.
    - Wire it before the admin-only sub-router so cashiers can hit `/api/reports/range` while every other `/api/reports/*` remains admin-only.
    - _Requirements: 4.4, 4.5, 4.12_

  - [ ]* 8.3 Write property test for date-range query validation
    - **Property 22: Date-range query validation**
    - **Validates: Requirements 4.1, 4.2, 4.3**

  - [ ]* 8.4 Write property test for date-range arithmetic correctness
    - **Property 23: Date-range report arithmetic correctness**
    - Generate arbitrary multi-cashier multi-store data sets and assert per-store rollups equal the sum of per-cashier rows assigned to that store, totals equal the sum of all per-cashier rows, and the derived profit fields satisfy the formulas in Requirement 4.6.
    - **Validates: Requirements 4.6, 4.7, 4.8, 4.9, 4.13**

  - [ ]* 8.5 Write property test for cashier scope enforcement
    - **Property 24: Date-range report scope is enforced server-side**
    - **Validates: Requirements 4.4, 4.5, 4.12**

  - [ ]* 8.6 Write property test for debt-row customer info
    - **Property 25: Debt rows in date-range breakdown carry customer info**
    - **Validates: Requirements 4.10**

  - [ ]* 8.7 Write integration tests for empty range and slow-query warning
    - Single example test that hits `/api/reports/range` against an empty database and asserts every numeric total is `0` and every array is empty.
    - Single example test that stubs the `pool.query` of the report path to delay > 5000 ms and asserts `logger.warn` is invoked with `from`, `to`, `user_id`, and `elapsed_ms`.
    - _Requirements: 4.14, 4.16_

- [x] 9. Cashier UI components and POS dashboard integration
  - [x] 9.1 Create `ooredoo-pos-client/src/components/DebtModal.jsx`
    - Implement the three-step flow (customer → amount → review) mirroring `SimSaleModal.jsx`, reusing `CustomerPicker.jsx` verbatim for step 1.
    - Step 2 enforces the amount and description rules from Requirement 1.5 client-side and displays inline errors.
    - On confirm, POSTs `{ session_id, customer_id, amount, description }` to `/api/sales/debt`; on success calls `onComplete(persisted)`.
    - Map the API error codes (`CUSTOMER_REQUIRED`, `NO_OPEN_SESSION`, `VALIDATION_ERROR`, `CUSTOMER_NOT_FOUND`) to user-facing strings.
    - _Requirements: 1.1, 1.5, 1.11_

  - [x] 9.2 Create `ooredoo-pos-client/src/components/CashierAdvancePanel.jsx`
    - Fetch `/api/advances/me` on mount and on every `refreshKey` change.
    - Render the outstanding balance prominently and a paginated history list below.
    - Provide a "Record advance" button that opens an inline modal (amount + optional note) and POSTs `/api/advances`.
    - Provide a void-row action constrained to the current session's rows; on success calls back to refresh the panel.
    - _Requirements: 2.2, 2.8, 2.11_

  - [x] 9.3 Create `ooredoo-pos-client/src/components/RegisterExpenseModal.jsx`
    - Single-step modal supporting `mode='cashier'` (hides `expense_date` and `store_id`, defaults them server-side) and `mode='admin'` (exposes a date input and a store select populated from `/api/stores`).
    - `category` is a dropdown of `'utility' | 'inventory' | 'other'`.
    - On confirm POSTs `/api/finances/expenses`; map `INSUFFICIENT_REGISTER_CASH` to a banner that shows the current balance from the response payload.
    - _Requirements: 3.2, 3.5, 3.7, 3.9, 3.16_

  - [x] 9.4 Integrate the three new components into `ooredoo-pos-client/src/pages/cashier/POSDashboard.jsx`
    - Replace the existing single-input "Record Client Debt" trigger with `<DebtModal>`.
    - Mount `<CashierAdvancePanel>` and a "Record expense" button that opens `<RegisterExpenseModal mode='cashier'>`.
    - Disable the debt and expense triggers when there is no open session.
    - _Requirements: 1.1, 1.6, 2.8, 3.3, 3.16_

  - [ ]* 9.5 Write React Testing Library tests for `DebtModal`
    - Cover step transitions (cannot advance without a selected customer; cannot submit without a valid amount), existing-phone-reuse path, and error banner rendering with mocked axios responses.
    - _Requirements: 1.1_

- [x] 10. Admin UI pages and final wiring
  - [x] 10.1 Create `ooredoo-pos-client/src/pages/admin/AdminAdvances.jsx`
    - Render the GET `/api/advances` list sorted by outstanding balance descending, each row clickable to open a drill-down panel populated from `/api/advances/cashier/:id`.
    - Provide a "Record repayment" action that POSTs `/api/advances/repayment` with the selected cashier; render `REPAYMENT_EXCEEDS_BALANCE` errors with the current balance shown.
    - _Requirements: 2.5, 2.6, 2.9_

  - [x] 10.2 Create `ooredoo-pos-client/src/pages/admin/AdminExpenses.jsx`
    - Render `GET /api/finances/expenses` with filters (store, category, date range, void state) and pagination via `limit`/`offset`.
    - Provide a "Record expense" button that opens `<RegisterExpenseModal mode='admin'>`.
    - Provide a void action with a `void_reason` input; on success refresh the list.
    - _Requirements: 3.5, 3.13, 3.14, 3.17_

  - [x] 10.3 Create `ooredoo-pos-client/src/pages/admin/DateRangeReports.jsx`
    - Calendar-based date-range picker (max 366-day span enforced client-side as a UX hint, server-side as authoritative).
    - On submit, GET `/api/reports/range?from=&to=` and render tabs for Totals, Per-cashier, Per-store, Debts (with customer info), Advances/repayments per cashier, Expenses by category.
    - Surface error codes `INVALID_DATE_RANGE`, `RANGE_TOO_LARGE`, `FUTURE_DATE` as inline messages.
    - _Requirements: 4.1, 4.6, 4.10, 4.11_

  - [x] 10.4 Create `ooredoo-pos-client/src/pages/cashier/CashierDateRangeReport.jsx`
    - Same calendar picker, but renders only the Totals and the cashier's own per-cashier section. Hides per-store rollup and other-cashier data.
    - _Requirements: 4.1, 4.5, 4.12_

  - [x] 10.5 Update `ooredoo-pos-client/src/components/Layout.jsx`
    - Add admin nav links for `Advances` (→ `/admin/advances`) and `Expenses` (→ `/admin/expenses`).
    - Reorganize the existing `Reports` link into a tabbed page that surfaces both the existing daily-report list and the new date-range report.
    - _Requirements: 2.9, 3.17, 4.11_

  - [x] 10.6 Wire the new pages into `ooredoo-pos-client/src/App.jsx`
    - Add `ProtectedRoute role='admin'` entries for `/admin/advances`, `/admin/expenses`, `/admin/reports/range`.
    - Add a `ProtectedRoute role='cashier'` entry for `/cashier/reports/range`.
    - Verify the existing `/admin/reports` and `/cashier` routes continue to mount their existing pages.
    - _Requirements: 2.9, 3.17, 4.4, 4.5_

  - [ ]* 10.7 Write snapshot tests for the new admin pages and modals
    - Snapshot `AdminAdvances`, `AdminExpenses`, `DateRangeReports`, and `CashierDateRangeReport` under representative mocked API responses.
    - _Requirements: 2.9, 3.17, 4.11, 4.12_

- [x] 11. Final checkpoint
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP delivery — they are exclusively unit, property-based, integration, RTL, and snapshot tests.
- Each task references the requirement clauses it satisfies for traceability.
- Property-based tests sit immediately after the implementation they validate, except for the cross-cutting set in section 6 which intentionally lands once all three financial domains are in place.
- Each property test references its property number from the design's "Correctness Properties" section.
- Property tests run against an isolated PostgreSQL test database via the harness in task 1.3; concurrency property 18 reduces iteration count to 50 to keep CI runtime reasonable.
- The migration view rebuild in task 1.1 is what makes Property 17 hold for `v_session_live_totals` once expenses exist.
- The expenses sub-router in task 5.2 must be mounted before the existing admin-only `/api/finances` router so cashier requests reach it.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.3", "2.1"] },
    { "id": 1, "tasks": ["1.2", "2.2", "2.3", "3.1", "4.1", "5.1", "8.1"] },
    { "id": 2, "tasks": ["3.2", "4.2", "8.2"] },
    { "id": 3, "tasks": ["5.2"] },
    { "id": 4, "tasks": ["3.3", "3.4", "3.5", "4.3", "4.4", "4.5", "4.6", "4.7", "5.3", "5.4", "5.5", "5.6", "5.7", "6.1", "6.2", "6.3", "6.4", "6.5", "8.3", "8.4", "8.5", "8.6", "8.7"] },
    { "id": 5, "tasks": ["9.1", "9.2", "9.3", "10.1", "10.2", "10.3", "10.4"] },
    { "id": 6, "tasks": ["9.4", "10.5"] },
    { "id": 7, "tasks": ["10.6"] },
    { "id": 8, "tasks": ["9.5", "10.7"] }
  ]
}
```
