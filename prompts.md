  # Ooredoo Reseller — System Documentation

  A comprehensive overview of the inventory, sales, and commission management web application for an Ooredoo authorised reseller operating two physical stores (**AAO Sobha** and **Kiosque Ain Meraine**). All monetary values are in Algerian Dinar (DZD).

  ---

  ## 1. Project Overview & File Structure

  ### High-Level Summary

  The system is a two-tier web application split into:

  - **`ooredoo-reseller-api`** — a Node.js/Express REST API backed by PostgreSQL 15+ that owns all business logic, data persistence, and aggregation.
  - **`ooredoo-pos-client`** — a React 19 + Vite + Tailwind CSS single-page client with role-aware routing (admin vs cashier).

  It manages five intertwined domains:

  1. **SIM card inventory** — physical SIM cards owned per cashier, identified by serial number, sold under named "offers" (Gold, N'yooz, Dima Ooredoo, Ooredoo, Ooredoo POP, Ooredoo Internet).
  2. **Sales** — SIM sales, Storm/bundle entries, accessory & device sales, and customer debts, all bound to a per-day cashier session and snapshotted for historical accuracy.
  3. **Customer ledger** — phone-keyed customer records linked to debts and (optionally) sales.
  4. **Financial tracking** — global pool state (shared across stores), per-store register cash, cashier advances/repayments, and register expenses (utility/inventory/other) with a date-range consolidated report.
  5. **Reporting & audit** — immutable end-of-day daily reports per store plus an append-only audit log of every mutation, login, void, and report generation.

  ### File Tree (workspace root)

  ```
  ooredoo-reseller-api/
  ├── .env.example              # template env vars (DB, JWT, rate-limits, Sentry)
  ├── .github/workflows/ci.yml  # CI: lint, jest, vitest+fast-check, vite build, docker
  ├── .kiro/specs/              # spec-driven design documents (requirements/design/tasks)
  ├── database/
  │   └── schema.sql            # canonical PostgreSQL schema (DDL + views + triggers)
  ├── docker-compose.yml        # local Postgres + API stack
  ├── Dockerfile                # API image
  ├── migrations/               # node-pg-migrate migrations (chronological)
  │   ├── 1000000000000_baseline-schema.js
  │   ├── 1000000000001_sim-cards-inventory.js
  │   ├── 1000000000002_sim-cards-generic.js
  │   ├── 1000000000003_categories-customers.js
  │   ├── 1000000000004_profit-and-customer-link.js
  │   └── 1000000000005_financial-extensions.js
  ├── package.json              # API deps + scripts (start, dev, migrate, test, test:integration)
  ├── scripts/                  # one-shot maintenance scripts (seed admin, reset DB, load test)
  ├── src/                      # backend source
  │   ├── server.js             # Express entry: middleware, route mounting, graceful shutdown
  │   ├── config/
  │   │   ├── db.js             # pg Pool, query/withTransaction/withRLS/healthCheck
  │   │   ├── env.js            # typed env loader (validates required vars)
  │   │   └── sentry.js         # optional Sentry initialisation
  │   ├── controllers/          # one file per domain
  │   │   ├── advancesController.js
  │   │   ├── authController.js
  │   │   ├── customersController.js
  │   │   ├── expensesController.js
  │   │   ├── financesController.js
  │   │   ├── offersController.js
  │   │   ├── productsController.js
  │   │   ├── reportsController.js
  │   │   ├── salesController.js
  │   │   ├── sessionsController.js
  │   │   ├── stockController.js
  │   │   └── usersController.js
  │   ├── middleware/
  │   │   ├── authenticate.js   # Bearer token verification
  │   │   ├── authorize.js      # role-based gate factory
  │   │   └── errorHandler.js   # AppError + PG error mapping + Sentry
  │   ├── routes/               # Express routers (one per controller)
  │   └── utils/
  │       ├── AppError.js       # operational error class with .withDetails()
  │       ├── asyncHandler.js   # wrapper + sendSuccess/sendCreated helpers
  │       ├── audit.js          # fire-and-forget audit_logs insert
  │       ├── jwt.js            # access/refresh token sign/verify/hash helpers
  │       ├── logger.js         # pino instance
  │       └── validators.js     # shared field validators (amounts, dates, customers, …)
  ├── tests/integration/        # vitest + fast-check property/integration suite
  ├── ooredoo-pos-client/       # React/Vite frontend
  │   ├── package.json          # react 19, react-router-dom 7, axios, lucide-react, tailwind 4
  │   ├── vite.config.js
  │   ├── eslint.config.js
  │   ├── public/
  │   └── src/
  │       ├── App.jsx           # BrowserRouter + ProtectedRoute composition
  │       ├── main.jsx
  │       ├── index.css         # Tailwind base
  │       ├── api/axios.js      # axios instance, JWT interceptors, auto-refresh, offline guard
  │       ├── assets/
  │       ├── components/
  │       │   ├── AccessorySaleModal.jsx
  │       │   ├── CashierAdvancePanel.jsx
  │       │   ├── CustomerPicker.jsx
  │       │   ├── DebtModal.jsx
  │       │   ├── Layout.jsx          # top bar + nav (admin vs cashier)
  │       │   ├── OfflineBanner.jsx
  │       │   ├── ProtectedRoute.jsx  # auth + role gate
  │       │   ├── RegisterExpenseModal.jsx
  │       │   ├── SimSaleModal.jsx
  │       │   └── StormSaleModal.jsx
  │       ├── context/AuthContext.jsx # login/logout/user + localStorage persistence
  │       ├── hooks/
  │       │   ├── useAuth.js
  │       │   └── useOnlineStatus.js
  │       └── pages/
  │           ├── Login.jsx
  │           ├── admin/
  │           │   ├── AdminAdvances.jsx
  │           │   ├── AdminDashboard.jsx
  │           │   ├── AdminExpenses.jsx
  │           │   ├── AssignStock.jsx
  │           │   ├── CashManagement.jsx
  │           │   ├── DailyReports.jsx
  │           │   ├── DateRangeReports.jsx
  │           │   ├── ManageCustomers.jsx
  │           │   ├── ManageOffers.jsx
  │           │   ├── ManageProducts.jsx
  │           │   └── ManageUsers.jsx
  │           └── cashier/
  │               ├── CashierDateRangeReport.jsx
  │               ├── POSDashboard.jsx
  │               └── TransactionLedger.jsx
  └── vitest.config.js
  ```

  ---

  ## 2. Database Schema (PostgreSQL)

  The schema lives in `database/schema.sql` (canonical seed) and is incrementally extended by the migrations under `migrations/`. PostgreSQL extensions used: `pgcrypto`, `pg_trgm` (for trigram name search).

  ### Enums

  - `user_role` — `admin | cashier`
  - `session_status` — `open | closed`
  - `sim_card_status` — `available | sold | voided`
  - `audit_action` — `INSERT | UPDATE | DELETE | LOGIN | LOGOUT | VOID | SESSION_OPEN | SESSION_CLOSE | REPORT_GENERATE | STOCK_ASSIGN`

  ### Tables (with primary/foreign keys and key aggregate columns)

  | Table | PK | Notable FKs / unique constraints | Aggregate / business columns |
  |---|---|---|---|
  | **stores** | `id` | `name UNIQUE` | seeded with the two physical stores |
  | **users** | `id` | `store_id → stores(id)`; `username UNIQUE`; CHECK `cashier_requires_store` | `password_hash` (bcrypt), `role`, `is_active` |
  | **refresh_tokens** | `id` | `user_id → users(id) ON DELETE CASCADE`; `token_hash UNIQUE` | `expires_at`, `is_revoked`, `ip_address` |
  | **offers** (SIM offers) | `id` | `category_id → offer_categories(id)` | `real_price`, `selling_price`, `points`, `commission_amount`, `low_stock_threshold` |
  | **offer_categories** | `id` | `name UNIQUE` | seeded: Gold, N'yooz, Dima Ooredoo, Ooredoo, Ooredoo POP, Ooredoo Internet |
  | **product_categories** | `id` | `name UNIQUE` | seeded: Phones, PC Laptops, PC Desktops, Accessories |
  | **products** | `id` | `category_id → product_categories(id)` | `price`, `real_price`, `commission_amount` |
  | **customers** | `id` | `phone_number UNIQUE`; `created_by → users(id)` | `first_name`, `last_name`, `address`, `profession` (loyalty/debt ledger key) |
  | **cashier_sessions** | `id` | `cashier_id → users(id)`, `store_id → stores(id)`; UNIQUE `(cashier_id, session_date)` | `status`, `opening_cash`, `closed_at` (one open session per cashier per day) |
  | **sim_cards** | `id` | `serial_number UNIQUE`, `offer_id → offers(id)`, `cashier_id → users(id)` | `status` (available/sold/voided), `sold_at` (physical inventory) |
  | **session_sim_sales** | `id` | `session_id → cashier_sessions(id)`, `offer_id → offers(id)`, `sim_card_id → sim_cards(id)`, `customer_id → customers(id)` | snapshots: `offer_name_snapshot`, `real_price_snapshot`, `selling_price_snapshot`, `points_snapshot`, `commission_snapshot`; `is_voided` |
  | **session_storm_entries** | `id` | `session_id`, `customer_id` | `amount`, `is_voided` (manual Storm/bundle amounts) |
  | **session_accessory_sales** | `id` | `session_id`, `product_id`, `customer_id` | snapshots: `product_name_snapshot`, `category_name_snapshot`, `price_snapshot`, `real_price_snapshot`, `commission_snapshot`; `is_voided` |
  | **session_debts** | `id` | `session_id`, `customer_id → customers(id) ON DELETE RESTRICT` (mandatory link, NOT NULL) | `amount`, `description`, `is_voided` |
  | **cashier_advances** | `id` | `cashier_id`, `session_id` (NULL for repayments), `voided_by`, `created_by`; CHECK `advance_has_session` | `direction` (`advance | repayment`), `amount`, `note`, `is_voided` |
  | **register_expenses** | `id` | `store_id`, `session_id` (NULL for admin entries), `voided_by`, `created_by` | `amount`, `expense_date`, `category` (`utility | inventory | other`), `description`, `is_voided` |
  | **global_pool_state** | `id` | `updated_by → users(id)` | append-only log: `available_balance`, `available_bonus`, `available_points` (current = MAX(id)) |
  | **store_register_state** | `id` | `store_id`, `updated_by` | append-only log: `cash_amount` per store (current = MAX(id) per store) |
  | **daily_reports** | `id` | UNIQUE `(report_date, store_id)`; immutable (BEFORE DELETE/UPDATE trigger) | pre-computed: `total_sim_units`, `total_real_price`, `total_selling_price`, `total_points`, `total_storm`, `total_accessories`, `total_debts`, `total_commissions`, `gross_profit`; full `snapshot JSONB` |
  | **audit_logs** | `id BIGSERIAL` | `user_id → users(id)` | `action`, `table_name`, `record_id`, `old_values JSONB`, `new_values JSONB`, `description`, `ip_address` (append-only) |

  ### Convenience Views

  - **`v_session_live_totals`** — real-time per-session aggregates (SIM units/real/selling/points/commission, Storm total, accessory totals, debt total, `expected_register_cash`, `total_cashier_benefit`). Migration `1000000000005` rebuilds this view to additionally subtract non-voided register expenses for the session.
  - **`v_cashier_sim_inventory`** — per-cashier per-offer SIM availability with `is_low_stock` flag.
  - **`v_current_pool`** — latest `global_pool_state` row.
  - **`v_current_register`** — `DISTINCT ON (store_id)` latest `store_register_state` row per store.
  - **`v_monthly_summary`** — monthly rollup over `daily_reports` for admin charts.

  ### Trigger Behaviour

  - `fn_set_updated_at()` keeps `updated_at` synced on `users`, `offers`, `products`, `customers` via `BEFORE UPDATE` triggers.
  - `fn_protect_daily_reports()` blocks `DELETE`/`UPDATE` on `daily_reports` so historical reports are immutable by construction.

  ### Aggregate Conventions

  - **Sales totals** are always computed with `FILTER (WHERE is_voided = FALSE)` — voided rows never contribute to any aggregate.
  - **Snapshot columns** on every sale row keep historical data correct even after offers/products mutate.
  - **Profit formulas** (used in `daily_reports.gross_profit` and the date-range report):
    - SIM profit per row = `points + selling_price − real_price`
    - Accessory profit per row = `selling_price − real_price`
    - Storm contribution = `amount` (no cost basis)
    - Gross profit = SIM + accessory + storm − register expenses (− cashier commissions in some surfaces)
  - **Outstanding advance balance per cashier** = `Σ advance.amount FILTER (is_voided=FALSE) − Σ repayment.amount FILTER (is_voided=FALSE)`.
  - **Live register cash** = latest `store_register_state.cash_amount` row for the store. Register-expense create/void atomically inserts a new row with the delta.

  ---

  ## 3. Backend Architecture (Node.js / Express)

  ### Stack

  - **Runtime** Node ≥18, CommonJS modules
  - **Framework** Express 4 with `helmet`, `cors`, `pino-http`, `express-rate-limit`
  - **DB driver** `pg` (with custom NUMERIC/INT8 type parsers so monetary values arrive as JS numbers)
  - **Auth** `jsonwebtoken` (access + refresh, refresh stored as SHA-256 hash) and `bcryptjs` (rounds 12)
  - **Migrations** `node-pg-migrate`
  - **Logging** `pino` + `pino-http`
  - **Error monitoring** optional `@sentry/node`
  - **Tests** `jest` (unit, configured but no `__tests__` populated yet) + `vitest` + `fast-check` for DB-backed property/integration tests

  ### Server Bootstrap (`src/server.js`)

  1. Initialise Sentry (no-op without DSN).
  2. Build the Express app with `trust proxy`, `pino-http`, `helmet`, `cors`, `express.json({ limit: '100kb' })`.
  3. Apply two rate limiters: `globalLimiter` on `/api`, stricter `authLimiter` on `/api/auth` (skips successful logins).
  4. Mount routers in order (note: `/api/finances/expenses` is mounted **before** `/api/finances` so the finance router's blanket `authorize('admin')` does not block cashiers from posting expenses):
    - `/api/auth`, `/api/users`, `/api/offers`, `/api/products`, `/api/sessions`, `/api/sales`, `/api/reports`, `/api/finances/expenses`, `/api/finances`, `/api/stock`, `/api/customers`, `/api/advances`
  5. Register `notFoundHandler` and the global `errorHandler`.
  6. Background interval cleans up expired refresh tokens every 6 hours.
  7. Graceful shutdown on `SIGTERM`/`SIGINT` (close server then drain pool, force-exit after 10 s).

  ### Middleware

  - **`authenticate`** — verifies `Authorization: Bearer <jwt>`, decodes claims (`sub`, `username`, `role`, `storeId`), attaches `req.user` and `req.clientIp`. Maps `TokenExpiredError` to `TOKEN_EXPIRED`, anything else to `TOKEN_INVALID`.
  - **`authorize(...roles)`** — factory that rejects with `INSUFFICIENT_ROLE` (403) when `req.user.role` is not in the allow-list. Helper `assertOwnerOrAdmin(resourceOwnerId, req)` is exported for per-resource ownership checks.
  - **`errorHandler`** — distinguishes operational `AppError` (uses `err.statusCode`, merges `err.details` into the response) from PG constraint errors (mapped to `DUPLICATE_ENTRY` 409, `INVALID_REFERENCE` 422, `CONSTRAINT_VIOLATION` 422), JWT errors, body-parser errors, and unexpected bugs (logged + Sentry capture, generic 500).

  ### Authentication & Session Management

  Auth uses a stateless **access token** + stateful **refresh token** with rotation and reuse detection:

  1. `POST /api/auth/login` — fetches user, runs bcrypt against either the real hash or a dummy hash (timing-attack mitigation), revokes any existing active refresh tokens for that user (one active session per user, matching the shift model), inserts a new `refresh_tokens` row keyed on the SHA-256 of a `crypto.randomBytes(48)` value, and returns `{ accessToken, refreshToken, user }`. Audited as `LOGIN`.
  2. `POST /api/auth/refresh` — looks up the hashed token; on a hit it rotates (revoke old, insert new). If the token is already revoked it interprets the call as token theft, **revokes ALL refresh tokens for the user**, audits the event, and returns `TOKEN_REUSE`.
  3. `POST /api/auth/logout` — revokes the supplied refresh token plus all of the user's active tokens, audits as `LOGOUT`.
  4. `GET /api/auth/me` — returns the authenticated user + their `store_name`.

  Access-token expiry is governed by `JWT_ACCESS_EXPIRES_IN` (default `1h`), refresh by `JWT_REFRESH_EXPIRES_IN` (default `8h`, parser supports `s|m|h|d`). Tokens carry `iss=ooredoo-reseller`, `aud=ooredoo-reseller-client`. The frontend axios interceptor automatically retries any 401 once after refreshing, falling back to a hard logout if the refresh also fails.

  ### Core API Endpoints (selected)

  | Method & path | Roles | Purpose |
  |---|---|---|
  | `POST /api/auth/login` | public | issue tokens |
  | `POST /api/auth/refresh` | public | rotate tokens |
  | `POST /api/auth/logout`, `GET /api/auth/me` | any auth | end session, profile |
  | `GET/POST/PATCH/DELETE /api/users/...` | admin (mutations); cashier (own record only via list/get filter) | user management |
  | `GET /api/offers`, `GET /api/products` (+ `/categories`) | admin & cashier | active list for cashiers, full list for admin |
  | `POST/PATCH/DELETE /api/offers`, `/api/products` | admin | catalogue management |
  | `GET /api/customers`, `/lookup`, `/:id`, `/:id/purchases`; `POST/PATCH /api/customers` | admin & cashier | customer ledger |
  | `DELETE /api/customers/:id` | admin | hard delete |
  | `POST /api/sessions`, `GET /api/sessions`, `POST /api/sessions/:id/close` | admin & cashier | open/list/close shifts |
  | `GET /api/sessions/live` | admin | real-time view of all open sessions |
  | `GET /api/sessions/:id`, `/totals`, `/stock`, `/history` | admin & cashier (own session only) | session detail/aggregates |
  | `POST /api/sessions/:id/stock-assign` | admin | assign SIM stock to cashier session |
  | `POST /api/sales/sim`, `/storm`, `/accessory`, `/debt`, `/:type/:id/void` | cashier | record/void sales |
  | `GET /my`, `GET /cashiers`, `GET /cards`, `POST /assign` (`/api/stock/...`) | mixed | physical SIM inventory |
  | `GET/PUT /api/finances/pool`, `/registers`, `/registers/:id` | admin | global pool + per-store cash |
  | `POST /api/finances/expenses`, `GET /me`, `GET /`, `POST /:id/void` | cashier (`POST /`, `/me`, void within own session); admin (any) | register expenses |
  | `POST /api/advances` (cashier), `POST /repayment` (admin), `GET /me`, `GET /`, `GET /cashier/:id`, `POST /:id/void` | mixed | cashier advance ledger |
  | `GET /api/reports/preview`, `POST /api/reports/generate`, `GET /api/reports`, `GET /api/reports/:id` | admin | daily report lifecycle |
  | `GET /api/reports/range?from=&to=` | admin & cashier | consolidated date-range report (cashier scope server-enforced) |

  ### Environment Variables (`.env.example`)

  Required (will throw on boot if missing):

  - `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`
  - `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`

  Optional (with defaults):

  - `NODE_ENV` (`development`), `PORT` (`3001`)
  - `DB_POOL_MAX` (`20`)
  - `JWT_ACCESS_EXPIRES_IN` (`1h`), `JWT_REFRESH_EXPIRES_IN` (`8h`)
  - `BCRYPT_ROUNDS` (`12`), `CORS_ORIGIN` (`http://localhost:3000`)
  - `RATE_LIMIT_WINDOW_MS` (`900000`), `RATE_LIMIT_MAX` (`200`), `AUTH_RATE_LIMIT_MAX` (`10`)
  - `SENTRY_DSN` (empty)

  ### Request Lifecycle Conventions

  - Controllers wrap handlers in `asyncHandler` and return via `sendSuccess` / `sendCreated` for a uniform `{ success, status, message?, data }` envelope.
  - Mutating multi-statement flows use `db.withTransaction(async client => …)` with explicit row locks (`SELECT … FOR UPDATE`) where a balance must be read-modified-written safely (register cash, advances, expenses).
  - Every successful mutation calls the fire-and-forget `audit({ userId, action, table, recordId, oldValues, newValues, description, ip })` helper. For register-cash mutations (`expensesController`) the audit insert lives inside the same transaction so the audit row is rolled back if the write fails.

  ---

  ## 4. Frontend Architecture (React / Tailwind CSS)

  ### Stack

  - **React 19** + **react-router-dom 7**
  - **Tailwind CSS 4** via `@tailwindcss/vite`
  - **Vite 8** (dev/build), **ESLint 10** with `react-hooks` and `react-refresh` plugins
  - **Axios 1** with custom request/response interceptors
  - **lucide-react** for icons
  - Plain `localStorage` for session persistence (no Redux; React Context is the single source of auth truth)

  ### Component Hierarchy

  ```
  <BrowserRouter>
  └── <AuthProvider>           // context/AuthContext.jsx — login/logout, persists user
      └── <Routes>
          ├── /login → <Login />
          └── <ProtectedRoute>  // requires auth
              └── <Layout>      // top bar (logo, user pill, logout) + nav strip
                  ├── Cashier routes
                  │   ├── /pos                 → <POSDashboard>
                  │   │     ├── <SimSaleModal>          (3-step: stock → offer → customer)
                  │   │     ├── <StormSaleModal>
                  │   │     ├── <AccessorySaleModal>
                  │   │     ├── <DebtModal>             (CustomerPicker → amount → review)
                  │   │     ├── <RegisterExpenseModal mode="cashier">
                  │   │     ├── <CashierAdvancePanel>   (outstanding balance + history + record + void)
                  │   │     └── <TransactionLedger>
                  │   └── /cashier/reports/range → <CashierDateRangeReport>  (own scope)
                  │       (wrapped in <ProtectedRoute requireCashier>)
                  └── Admin routes (wrapped in <ProtectedRoute requireAdmin>)
                      ├── /admin/dashboard         → <AdminDashboard>
                      ├── /admin/users             → <ManageUsers>
                      ├── /admin/customers         → <ManageCustomers>
                      ├── /admin/offers            → <ManageOffers>
                      ├── /admin/products          → <ManageProducts>
                      ├── /admin/stock             → <AssignStock>
                      ├── /admin/finances          → <CashManagement>
                      ├── /admin/advances          → <AdminAdvances>     (per-cashier balances + drill-down + repayment)
                      ├── /admin/expenses          → <AdminExpenses>     (filters + RegisterExpenseModal mode="admin" + void)
                      ├── /admin/reports           → <DailyReports>
                      └── /admin/reports/range     → <DateRangeReports>  (Totals / Per-cashier / Per-store / Debts / Advances / Expenses tabs)

  Shared building blocks: <CustomerPicker>, <OfflineBanner>
  ```

  ### Routing Logic & Access Control

  `<ProtectedRoute>` consumes `useAuth()` (which proxies to `AuthContext`) and applies three checks in sequence:

  1. While `isLoading` is true (initial localStorage read), it renders a centred spinner so the redirect logic never fires before the user state is hydrated.
  2. If `!isAuthenticated`, it `<Navigate to="/login" replace />`.
  3. If `requireAdmin` is true and the user is not an admin, it sends them to `/pos`. If `requireCashier` is true and the user is an admin, it sends them to `/admin/dashboard`. Otherwise it renders the nested `<Outlet>`.

  `Layout.jsx` then conditionally renders the admin tab strip vs the cashier tab strip from the same `useAuth()` (`isAdmin` / `isCashier`), so a cashier never sees an admin link and vice versa.

  ### Auth Flow on the Client

  - **`AuthContext`** stores `user`, exposes `login(username, password)`, `logout()`, plus derived flags (`isAuthenticated`, `isAdmin`, `isCashier`). On mount it rehydrates from `localStorage.user`.
  - **`api/axios.js`**:
    - **Request interceptor** short-circuits with `code: 'OFFLINE'` when `navigator.onLine === false`, then attaches `Authorization: Bearer <accessToken>` from localStorage.
    - **Response interceptor** catches a 401 once per request, calls `POST /auth/refresh` with the stored refresh token, swaps in the new pair, and replays the original request. If refresh also fails the interceptor wipes localStorage and hard-redirects to `/login`.
  - **`useOnlineStatus`** subscribes to `online`/`offline` window events and powers the `<OfflineBanner>`.

  ### UI Conventions

  - Tailwind 4 configured via the official Vite plugin; styling lives inline as utility classes.
  - All monetary values are formatted via `new Intl.NumberFormat('fr-DZ', { style: 'currency', currency: 'DZD' })`.
  - Date inputs cap at `today` (`max={today}`) on every report and expense surface; the **server is authoritative** for all range/future-date validation, the client only surfaces friendly hints (`INVALID_DATE_RANGE`, `RANGE_TOO_LARGE`, `FUTURE_DATE`).
  - API error codes (`CUSTOMER_REQUIRED`, `NO_OPEN_SESSION`, `INSUFFICIENT_REGISTER_CASH` w/ `current_balance`, `REPAYMENT_EXCEEDS_BALANCE` w/ `current_balance`, `ALREADY_VOIDED`, …) are mapped to user-facing strings inside the modal/page that triggered them.

  ---

  ## 5. Core Business Logic & Features

  ### Multi-Store Handling

  The two physical stores (**AAO Sobha**, **Kiosque Ain Meraine**) are first-class rows in the `stores` table. Every cashier `users` row carries a non-null `store_id` (enforced by the `cashier_requires_store` CHECK), and every operational row that needs a store dimension references it directly:

  - `cashier_sessions.store_id` — pinned at session-open from `users.store_id`.
  - `store_register_state.store_id` — the per-store cash log; one current row per store via `DISTINCT ON (store_id)` in `v_current_register`.
  - `register_expenses.store_id` — for cashier expenses derived from the cashier's session; for admin entries the admin picks the store directly.
  - `daily_reports` — keyed by `(report_date, store_id)` with `UNIQUE` constraint, one immutable report per store per day.

  Cashiers see **only their own store** because:

  1. The JWT carries `storeId`.
  2. Server-side controllers always filter by `req.user.id` / `req.user.storeId` for cashier roles. The cashier never receives data from the other store, even in the consolidated date-range report (`per_store` is omitted from the response payload entirely for cashiers).
  3. The frontend additionally drops any leaked rows defensively (`per_cashier.filter(r => r.cashier_id === user.id)`).

  Admins see **both stores**: the admin dashboard, advances list, expenses table, daily reports, and date-range report all aggregate across stores and break down per-store via the `per_store` rollup.

  ### Centralisation Strategy

  - **Stores share the global pool** (`global_pool_state`) — admin-set balance/bonus/points that span both locations. The pool is append-only so every adjustment is auditable.
  - **Per-store register cash** (`store_register_state`) is also append-only. The `expensesController` uses `SELECT … FOR UPDATE` on the latest row before inserting a new one with the new balance and an audit entry, all inside a single transaction. Voiding an expense atomically inserts another row that adds the cash back. This guarantees the property: *register balance after = sum of all signed deltas*.
  - **Cashier advances** live in `cashier_advances` and have **no store dimension** — a cashier's outstanding balance is global to that cashier. Repayments are admin-only and rejected with `REPAYMENT_EXCEEDS_BALANCE` (HTTP 400, payload includes `current_balance`) when they exceed the live outstanding.
  - **Audit log** (`audit_logs`) is the cross-store source of truth for compliance — every login, logout, mutation, void, session open/close, and report generation lands here with the actor's user id and IP.

  ### Reporting

  There are **two reporting surfaces** — both centralise across stores when the requester is admin:

  1. **Daily reports** (`reportsController.previewDailyReport` / `generateDailyReport`):
    - Preview shows per-store readiness for a given date (open sessions blocking generation, closed sessions, already-generated stores).
    - Generate runs inside a transaction: optionally force-closes open sessions (when `force_close_open_sessions=true`), pulls every closed session's totals from `v_session_live_totals`, fetches line-level rows (sim sales, storm entries, accessory sales, debts) in parallel, snapshots `global_pool_state` and `store_register_state`, then writes one immutable `daily_reports` row per store with both pre-computed totals and a full JSONB `snapshot`. Every generated report is audited as `REPORT_GENERATE`.
    - Subsequent monthly aggregation reads `v_monthly_summary` for instant chart data.

  2. **Date-range report** (`reportsController.getDateRangeReport`, `GET /api/reports/range?from=&to=`):
    - Validation goes through `validateDateRange` — emits `INVALID_DATE_RANGE`, `RANGE_TOO_LARGE` (>366 days), or `FUTURE_DATE`.
    - The query is a single CTE-based SQL: one CTE per source table keyed on `(cashier_id, store_id)` for sales/storm/accessory/debts, plus parallel queries for advances (keyed on `cashier_id`) and expenses (keyed on `(store_id, category)`). Each CTE applies a `($3::int IS NULL OR cs.cashier_id = $3)` predicate so the cashier-scope filter is enforced inside the database.
    - In application code the per-(cashier, store) cells are rolled up into:
      - **`per_cashier`** — one row per cashier with all aggregates plus derived `sim_profit`, `accessory_profit`, `gross_profit`.
      - **`per_store`** (admin only) — sale cells re-aggregated by `store_id`, expenses overlaid from the per-store bucket.
      - **`totals`** — grand totals, also incorporating advances and expenses.
      - **`debts`** — every non-voided debt row in the range, joined to the customer for full name / phone / profession.
      - **`advances`** — per-cashier `advance_total` / `repayment_total` / `outstanding_balance` for the range.
    - Performance: query time is measured; if it exceeds 5 s the controller logs a structured `pino` warning with `from`, `to`, `user_id`, `elapsed_ms` (the value is also returned in the response payload). The call is audited as `REPORT_GENERATE`.
    - Cashier scope is server-enforced: `per_store` is omitted entirely from the response when the requester is a cashier.

  ### Voiding & Soft Deletes

  Sales rows, storm entries, accessory sales, debts, advances, and expenses all use soft voids: `is_voided`, `voided_at`, `voided_by`, `void_reason`. Void endpoints reject the second attempt with HTTP 409 `ALREADY_VOIDED`. Cashiers may only void rows that belong to their currently open session (and, for advances, only `direction='advance'` rows); admins may void any non-voided row. Every aggregate query in the codebase includes `FILTER (WHERE is_voided = FALSE)` so voided rows never contribute to totals, register cash, daily reports, or date-range reports.

  ### Validation Layer (`src/utils/validators.js`)

  Shared, reusable validators back every domain:

  - `requireFields(obj, [...])`, `parsePositiveInt`, `parseId`, `parsePagination`
  - `validateAmount(value, { min, max, decimals_allowed })` — string-based decimal-place check so floating-point error cannot bypass it
  - `validateCustomerFields(...)` — enforces phone `^\+?\d+$` 8..20, names/profession 1..100, address 1..1000 (post-trim)
  - `validateVoidReason` — emits `MISSING_VOID_REASON` / `INVALID_VOID_REASON`
  - `parseDateOnly` — strict `YYYY-MM-DD` calendar check (rejects `2024-02-30`)
  - `validateDateRange(from, to)` — calls the above plus `INVALID_DATE_RANGE` / `RANGE_TOO_LARGE` / `FUTURE_DATE`

  ### Testing & CI

  - Unit tests under `__tests__/` (Jest, `--runInBand`).
  - DB-backed property/integration tests under `tests/integration/` (Vitest 4 + fast-check 4 against a dedicated `ooredoo_test` Postgres). The setup file refuses to run against the dev DB name, captures the fast-check seed in a single grep-friendly log line for CI reproducibility, and truncates the financial tables between iterations.
  - GitHub Actions CI (`.github/workflows/ci.yml`) provisions Postgres 15, applies `database/schema.sql`, runs Jest, then Vitest, syntax-checks the API entry, builds the frontend, and finally builds the Docker image.

  ---

  *Documentation generated from the workspace as of the current session. The spec under `.kiro/specs/pos-financial-tracking-extensions/` (requirements/design/tasks) is the canonical source for the financial-extensions feature behaviour and was produced by Kiro's spec workflow before implementation.*
