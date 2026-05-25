-- =============================================================================
-- OOREDOO RESELLER — INVENTORY & SALES MANAGEMENT SYSTEM
-- Database Schema v1.0  |  PostgreSQL 15+
-- Stores: AAO Sobha (store 1) | Kiosque Ain Meraine (store 2)
-- All monetary values in Algerian Dinar (DZD)
-- =============================================================================

-- =============================================================================
-- EXTENSIONS
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";  -- gen_random_uuid(), crypt()
CREATE EXTENSION IF NOT EXISTS "pg_trgm";   -- trigram indexes for name search

-- =============================================================================
-- ENUM TYPES
-- =============================================================================

CREATE TYPE user_role AS ENUM (
    'admin',
    'cashier'
);

CREATE TYPE session_status AS ENUM (
    'open',
    'closed'
);

CREATE TYPE audit_action AS ENUM (
    'INSERT',
    'UPDATE',
    'DELETE',
    'LOGIN',
    'LOGOUT',
    'VOID',
    'SESSION_OPEN',
    'SESSION_CLOSE',
    'REPORT_GENERATE',
    'STOCK_ASSIGN'
);

-- =============================================================================
-- STORES
-- The two physical store locations.
-- =============================================================================

CREATE TABLE stores (
    id          SERIAL          PRIMARY KEY,
    name        VARCHAR(100)    NOT NULL UNIQUE,
    location    VARCHAR(200),
    is_active   BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  stores             IS 'Physical store locations.';
COMMENT ON COLUMN stores.name        IS 'Display name, e.g. "AAO Sobha", "Kiosque Ain Meraine".';

-- Seed the two stores immediately — they are fixed business entities.
INSERT INTO stores (name, location) VALUES
    ('AAO Sobha',          'Sobha, Algeria'),
    ('Kiosque Ain Meraine','Ain Meraine, Algeria');

-- =============================================================================
-- USERS  (cashiers + the single admin)
-- =============================================================================

CREATE TABLE users (
    id              SERIAL          PRIMARY KEY,
    username        VARCHAR(50)     NOT NULL UNIQUE,
    password_hash   VARCHAR(255)    NOT NULL,           -- bcrypt, cost factor 12
    full_name       VARCHAR(100)    NOT NULL,
    role            user_role       NOT NULL DEFAULT 'cashier',
    store_id        INT             REFERENCES stores(id) ON DELETE RESTRICT,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    -- Admin has no store affiliation; cashiers must belong to a store.
    CONSTRAINT cashier_requires_store CHECK (
        role = 'admin' OR store_id IS NOT NULL
    )
);

COMMENT ON TABLE  users              IS 'System users: one admin + four cashiers.';
COMMENT ON COLUMN users.password_hash IS 'bcrypt hash. Never store plaintext.';
COMMENT ON COLUMN users.store_id     IS 'NULL for admin. Required for cashiers.';

-- =============================================================================
-- REFRESH TOKENS  (JWT rotation / secure session management)
-- =============================================================================

CREATE TABLE refresh_tokens (
    id          SERIAL          PRIMARY KEY,
    user_id     INT             NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash  VARCHAR(255)    NOT NULL UNIQUE,   -- SHA-256 of the raw token
    issued_at   TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    expires_at  TIMESTAMPTZ     NOT NULL,
    is_revoked  BOOLEAN         NOT NULL DEFAULT FALSE,
    revoked_at  TIMESTAMPTZ,
    ip_address  INET
);

COMMENT ON TABLE  refresh_tokens            IS 'Hashed refresh tokens for JWT rotation.';
COMMENT ON COLUMN refresh_tokens.token_hash IS 'SHA-256 of the random token sent to client.';

-- =============================================================================
-- OFFERS  (SIM card offers — admin-configurable)
-- =============================================================================

CREATE TABLE offers (
    id                  SERIAL          PRIMARY KEY,
    name                VARCHAR(100)    NOT NULL,
    real_price          NUMERIC(12, 2)  NOT NULL CHECK (real_price >= 0),
    selling_price       NUMERIC(12, 2)  NOT NULL CHECK (selling_price >= 0),
    points              INT             NOT NULL DEFAULT 0 CHECK (points >= 0),
    commission_amount   NUMERIC(12, 2)  NOT NULL DEFAULT 0 CHECK (commission_amount >= 0),
    low_stock_threshold INT             NOT NULL DEFAULT 5 CHECK (low_stock_threshold >= 0),
    is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
    sort_order          INT             NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  offers                    IS 'SIM card offer types. Admin-configurable.';
COMMENT ON COLUMN offers.real_price         IS 'Buying/cost price in DZD.';
COMMENT ON COLUMN offers.selling_price      IS 'Price charged to customer in DZD.';
COMMENT ON COLUMN offers.points             IS 'Loyalty points generated per unit sold.';
COMMENT ON COLUMN offers.commission_amount  IS 'Cashier commission per unit sold in DZD.';
COMMENT ON COLUMN offers.low_stock_threshold IS 'Alert admin when assigned stock falls below this.';
COMMENT ON COLUMN offers.sort_order         IS 'Controls display order of offer buttons in UI.';

-- =============================================================================
-- PRODUCT CATEGORIES  (Phones | PC Laptops | PC Desktops | Accessories)
-- =============================================================================

CREATE TABLE product_categories (
    id          SERIAL          PRIMARY KEY,
    name        VARCHAR(50)     NOT NULL UNIQUE,
    sort_order  INT             NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

INSERT INTO product_categories (name, sort_order) VALUES
    ('Phones',       1),
    ('PC Laptops',   2),
    ('PC Desktops',  3),
    ('Accessories',  4);

-- =============================================================================
-- PRODUCTS  (Phones, PCs, Accessories — admin-configurable)
-- =============================================================================

CREATE TABLE products (
    id                  SERIAL          PRIMARY KEY,
    name                VARCHAR(200)    NOT NULL,
    price               NUMERIC(12, 2)  NOT NULL CHECK (price >= 0),
    category_id         INT             NOT NULL REFERENCES product_categories(id)
                                            ON DELETE RESTRICT,
    commission_amount   NUMERIC(12, 2)  NOT NULL DEFAULT 0 CHECK (commission_amount >= 0),
    is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
    sort_order          INT             NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  products                  IS 'Phone, PC, and accessory product catalogue. Admin-configurable.';
COMMENT ON COLUMN products.price            IS 'Selling price in DZD. Snapshotted at time of sale.';
COMMENT ON COLUMN products.commission_amount IS 'Cashier commission per unit sold in DZD.';

-- =============================================================================
-- CASHIER SESSIONS
-- One session per cashier per calendar day (DB-enforced).
-- =============================================================================

CREATE TABLE cashier_sessions (
    id              SERIAL          PRIMARY KEY,
    cashier_id      INT             NOT NULL REFERENCES users(id)  ON DELETE RESTRICT,
    store_id        INT             NOT NULL REFERENCES stores(id) ON DELETE RESTRICT,
    session_date    DATE            NOT NULL DEFAULT CURRENT_DATE,
    status          session_status  NOT NULL DEFAULT 'open',
    opening_cash    NUMERIC(12, 2)  NOT NULL DEFAULT 0,  -- register cash snapshot at session start
    closed_at       TIMESTAMPTZ,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    -- Enforce one active session per cashier per day.
    CONSTRAINT one_session_per_cashier_per_day UNIQUE (cashier_id, session_date)
);

COMMENT ON TABLE  cashier_sessions             IS 'A cashier work session scoped to a single calendar day.';
COMMENT ON COLUMN cashier_sessions.opening_cash IS 'Cash in register when session opens (admin-set or carry-over).';

-- =============================================================================
-- SIM STOCK ASSIGNMENTS
-- Admin assigns a quantity of each offer to each cashier at session start.
-- System tracks sold quantity by counting non-voided sim sales rows.
-- =============================================================================

CREATE TABLE sim_stock_assignments (
    id                  SERIAL      PRIMARY KEY,
    session_id          INT         NOT NULL REFERENCES cashier_sessions(id) ON DELETE CASCADE,
    offer_id            INT         NOT NULL REFERENCES offers(id)           ON DELETE RESTRICT,
    assigned_quantity   INT         NOT NULL CHECK (assigned_quantity >= 0),
    assigned_by         INT         NOT NULL REFERENCES users(id)            ON DELETE RESTRICT,
    assigned_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT unique_offer_per_session UNIQUE (session_id, offer_id)
);

COMMENT ON TABLE sim_stock_assignments IS
    'Admin-assigned SIM card quota per offer per session. '
    'Sold qty = COUNT of non-voided session_sim_sales rows for this (session, offer).';

-- =============================================================================
-- SESSION SIM SALES
-- One row per SIM card unit sold.
-- Prices/commission are snapshotted at time of sale so historical data
-- remains correct even if offer configuration changes later.
-- =============================================================================

CREATE TABLE session_sim_sales (
    id                      SERIAL          PRIMARY KEY,
    session_id              INT             NOT NULL REFERENCES cashier_sessions(id) ON DELETE CASCADE,
    offer_id                INT             NOT NULL REFERENCES offers(id)           ON DELETE RESTRICT,

    -- Snapshot columns — immutable after insert
    offer_name_snapshot         VARCHAR(100)    NOT NULL,
    real_price_snapshot         NUMERIC(12, 2)  NOT NULL,
    selling_price_snapshot      NUMERIC(12, 2)  NOT NULL,
    points_snapshot             INT             NOT NULL,
    commission_snapshot         NUMERIC(12, 2)  NOT NULL,

    -- Void support
    is_voided               BOOLEAN         NOT NULL DEFAULT FALSE,
    voided_at               TIMESTAMPTZ,
    voided_by               INT             REFERENCES users(id) ON DELETE SET NULL,
    void_reason             TEXT,

    sold_at                 TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  session_sim_sales             IS 'One row = one SIM card unit sold within a session.';
COMMENT ON COLUMN session_sim_sales.is_voided   IS 'Soft-delete. Voided rows excluded from all totals.';

-- =============================================================================
-- SESSION STORM / BUNDLE ENTRIES
-- Cashier manually types a Storm/Bundle amount. One row per entry.
-- =============================================================================

CREATE TABLE session_storm_entries (
    id          SERIAL          PRIMARY KEY,
    session_id  INT             NOT NULL REFERENCES cashier_sessions(id) ON DELETE CASCADE,
    amount      NUMERIC(12, 2)  NOT NULL CHECK (amount > 0),
    note        TEXT,

    -- Void support
    is_voided   BOOLEAN         NOT NULL DEFAULT FALSE,
    voided_at   TIMESTAMPTZ,
    voided_by   INT             REFERENCES users(id) ON DELETE SET NULL,
    void_reason TEXT,

    entered_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE session_storm_entries IS 'Manual Storm/Bundle purchase amounts. One row per cashier entry.';

-- =============================================================================
-- SESSION ACCESSORY SALES  (Phones, PCs, Accessories)
-- One row per device/accessory unit sold.
-- product_id is nullable: if a product is later deleted, the historical row
-- still holds the snapshot data.
-- =============================================================================

CREATE TABLE session_accessory_sales (
    id                      SERIAL          PRIMARY KEY,
    session_id              INT             NOT NULL REFERENCES cashier_sessions(id) ON DELETE CASCADE,
    product_id              INT             REFERENCES products(id) ON DELETE SET NULL,

    -- Snapshot columns — immutable after insert
    product_name_snapshot   VARCHAR(200)    NOT NULL,
    category_name_snapshot  VARCHAR(50)     NOT NULL,
    price_snapshot          NUMERIC(12, 2)  NOT NULL,
    commission_snapshot     NUMERIC(12, 2)  NOT NULL DEFAULT 0,

    -- Void support
    is_voided               BOOLEAN         NOT NULL DEFAULT FALSE,
    voided_at               TIMESTAMPTZ,
    voided_by               INT             REFERENCES users(id) ON DELETE SET NULL,
    void_reason             TEXT,

    sold_at                 TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE session_accessory_sales IS 'One row = one phone/PC/accessory unit sold within a session.';

-- =============================================================================
-- SESSION DEBTS
-- Cashier records a debt amount during their session.
-- =============================================================================

CREATE TABLE session_debts (
    id          SERIAL          PRIMARY KEY,
    session_id  INT             NOT NULL REFERENCES cashier_sessions(id) ON DELETE CASCADE,
    amount      NUMERIC(12, 2)  NOT NULL CHECK (amount > 0),
    description TEXT,

    -- Void support
    is_voided   BOOLEAN         NOT NULL DEFAULT FALSE,
    voided_at   TIMESTAMPTZ,
    voided_by   INT             REFERENCES users(id) ON DELETE SET NULL,
    void_reason TEXT,

    entered_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE session_debts IS 'Debt entries recorded by a cashier within a session.';

-- =============================================================================
-- GLOBAL POOL STATE  (admin-maintained, shared across BOTH stores)
-- Append-only log: every admin change produces a new row.
-- Latest row per field = current state. Full history retained for free.
-- =============================================================================

CREATE TABLE global_pool_state (
    id                  SERIAL          PRIMARY KEY,
    available_balance   NUMERIC(14, 2)  NOT NULL CHECK (available_balance >= 0),
    available_bonus     NUMERIC(14, 2)  NOT NULL DEFAULT 0 CHECK (available_bonus >= 0),
    available_points    INT             NOT NULL DEFAULT 0 CHECK (available_points >= 0),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_by          INT             NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    notes               TEXT
);

COMMENT ON TABLE  global_pool_state              IS
    'Append-only log of admin-set global pool values (balance, bonus, points). '
    'Current state = MAX(id) row. Full audit trail retained automatically.';
COMMENT ON COLUMN global_pool_state.available_balance IS 'Total DZD balance available across both stores.';
COMMENT ON COLUMN global_pool_state.available_points  IS 'Total loyalty points available in the pool.';

-- =============================================================================
-- STORE REGISTER STATE  (per store, admin-maintained)
-- Append-only, same pattern as global_pool_state.
-- =============================================================================

CREATE TABLE store_register_state (
    id          SERIAL          PRIMARY KEY,
    store_id    INT             NOT NULL REFERENCES stores(id)  ON DELETE CASCADE,
    cash_amount NUMERIC(12, 2)  NOT NULL DEFAULT 0 CHECK (cash_amount >= 0),
    updated_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_by  INT             NOT NULL REFERENCES users(id)   ON DELETE RESTRICT,
    notes       TEXT
);

COMMENT ON TABLE store_register_state IS
    'Append-only log of admin-set per-store cash register amounts. '
    'Current state = MAX(id) WHERE store_id = X.';

-- =============================================================================
-- DAILY REPORTS  (immutable end-of-day snapshot — admin triggers generation)
-- One row per store per day, created once and never mutated.
-- Pre-computed numeric totals allow fast monthly aggregation queries.
-- Full JSONB snapshot preserves the complete picture for historical browsing.
-- =============================================================================

CREATE TABLE daily_reports (
    id                      SERIAL          PRIMARY KEY,
    report_date             DATE            NOT NULL,
    store_id                INT             NOT NULL REFERENCES stores(id)  ON DELETE RESTRICT,
    created_by              INT             NOT NULL REFERENCES users(id)   ON DELETE RESTRICT,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    -- Pre-computed aggregate columns (fast monthly queries)
    total_sim_units         INT             NOT NULL DEFAULT 0,
    total_real_price        NUMERIC(14, 2)  NOT NULL DEFAULT 0,
    total_selling_price     NUMERIC(14, 2)  NOT NULL DEFAULT 0,
    total_points            INT             NOT NULL DEFAULT 0,
    total_storm             NUMERIC(14, 2)  NOT NULL DEFAULT 0,
    total_accessories       NUMERIC(14, 2)  NOT NULL DEFAULT 0,
    total_debts             NUMERIC(14, 2)  NOT NULL DEFAULT 0,
    total_commissions       NUMERIC(14, 2)  NOT NULL DEFAULT 0,
    gross_profit            NUMERIC(14, 2)  NOT NULL DEFAULT 0,

    -- Full snapshot for historical browsing (immutable JSONB blob)
    -- Structure: { sessions: [...], global_pool: {...}, register_cash: {...} }
    snapshot                JSONB           NOT NULL,

    CONSTRAINT one_report_per_store_per_day UNIQUE (report_date, store_id)
);

COMMENT ON TABLE  daily_reports          IS 'Immutable end-of-day report. Never updated after creation.';
COMMENT ON COLUMN daily_reports.snapshot IS
    'Full JSONB snapshot of all session data, pool state, and register cash for this day. '
    'Structure: { sessions: [{ cashier, sim_sales, storm_entries, accessory_sales, debts, totals }], '
    'global_pool: { balance, bonus, points }, register: { cash_amount } }';

-- =============================================================================
-- AUDIT LOGS
-- Every data mutation and admin action is logged here.
-- The backend triggers this on: INSERT/UPDATE/DELETE on key tables,
-- all admin field changes, login/logout events, void operations,
-- session open/close, and report generation.
-- =============================================================================

CREATE TABLE audit_logs (
    id          BIGSERIAL       PRIMARY KEY,    -- high volume; use BIGSERIAL
    user_id     INT             NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    action      audit_action    NOT NULL,
    table_name  VARCHAR(100),
    record_id   INT,
    old_values  JSONB,
    new_values  JSONB,
    description TEXT,
    ip_address  INET,
    created_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE audit_logs IS
    'Append-only audit trail for all system mutations and admin actions. '
    'Never update or delete rows from this table.';

-- =============================================================================
-- INDEXES
-- =============================================================================

-- users
CREATE INDEX idx_users_store       ON users (store_id);
CREATE INDEX idx_users_role        ON users (role);
CREATE INDEX idx_users_active      ON users (is_active) WHERE is_active = TRUE;

-- refresh_tokens
CREATE INDEX idx_refresh_tokens_user     ON refresh_tokens (user_id);
CREATE INDEX idx_refresh_tokens_expires  ON refresh_tokens (expires_at);

-- offers
CREATE INDEX idx_offers_active     ON offers (is_active)   WHERE is_active = TRUE;
CREATE INDEX idx_offers_sort       ON offers (sort_order);
CREATE INDEX idx_offers_name_trgm  ON offers USING GIN (name gin_trgm_ops);

-- products
CREATE INDEX idx_products_category ON products (category_id);
CREATE INDEX idx_products_active   ON products (is_active) WHERE is_active = TRUE;
CREATE INDEX idx_products_sort     ON products (category_id, sort_order);
CREATE INDEX idx_products_name_trgm ON products USING GIN (name gin_trgm_ops);

-- cashier_sessions
CREATE INDEX idx_sessions_cashier  ON cashier_sessions (cashier_id);
CREATE INDEX idx_sessions_store    ON cashier_sessions (store_id);
CREATE INDEX idx_sessions_date     ON cashier_sessions (session_date);
CREATE INDEX idx_sessions_status   ON cashier_sessions (status) WHERE status = 'open';

-- sim_stock_assignments
CREATE INDEX idx_stock_session     ON sim_stock_assignments (session_id);
CREATE INDEX idx_stock_offer       ON sim_stock_assignments (offer_id);

-- session_sim_sales
CREATE INDEX idx_sim_sales_session ON session_sim_sales (session_id);
CREATE INDEX idx_sim_sales_offer   ON session_sim_sales (offer_id);
CREATE INDEX idx_sim_sales_voided  ON session_sim_sales (session_id) WHERE is_voided = FALSE;

-- session_storm_entries
CREATE INDEX idx_storm_session     ON session_storm_entries (session_id);
CREATE INDEX idx_storm_voided      ON session_storm_entries (session_id) WHERE is_voided = FALSE;

-- session_accessory_sales
CREATE INDEX idx_acc_session       ON session_accessory_sales (session_id);
CREATE INDEX idx_acc_product       ON session_accessory_sales (product_id);
CREATE INDEX idx_acc_voided        ON session_accessory_sales (session_id) WHERE is_voided = FALSE;

-- session_debts
CREATE INDEX idx_debts_session     ON session_debts (session_id);
CREATE INDEX idx_debts_voided      ON session_debts (session_id) WHERE is_voided = FALSE;

-- global_pool_state
CREATE INDEX idx_pool_updated      ON global_pool_state (updated_at DESC);

-- store_register_state
CREATE INDEX idx_register_store    ON store_register_state (store_id, updated_at DESC);

-- daily_reports
CREATE INDEX idx_reports_date      ON daily_reports (report_date DESC);
CREATE INDEX idx_reports_store     ON daily_reports (store_id);

-- audit_logs  (high-volume table — keep index set minimal)
CREATE INDEX idx_audit_user        ON audit_logs (user_id);
CREATE INDEX idx_audit_table       ON audit_logs (table_name, record_id);
CREATE INDEX idx_audit_created     ON audit_logs (created_at DESC);

-- =============================================================================
-- VIEWS  (convenience — no materialized views needed at this scale)
-- =============================================================================

-- Current session totals per cashier (only active/open sessions)
CREATE VIEW v_session_live_totals AS
SELECT
    cs.id                                                       AS session_id,
    cs.cashier_id,
    u.full_name                                                 AS cashier_name,
    cs.store_id,
    s.name                                                      AS store_name,
    cs.session_date,
    cs.opening_cash,

    -- SIM totals (non-voided only)
    COUNT(ss.id)    FILTER (WHERE ss.is_voided = FALSE)         AS sim_units_sold,
    COALESCE(SUM(ss.real_price_snapshot)
             FILTER (WHERE ss.is_voided = FALSE), 0)            AS sim_total_real_price,
    COALESCE(SUM(ss.selling_price_snapshot)
             FILTER (WHERE ss.is_voided = FALSE), 0)            AS sim_total_selling_price,
    COALESCE(SUM(ss.points_snapshot)
             FILTER (WHERE ss.is_voided = FALSE), 0)            AS sim_total_points,
    COALESCE(SUM(ss.commission_snapshot)
             FILTER (WHERE ss.is_voided = FALSE), 0)            AS sim_total_commission,

    -- Storm totals
    COALESCE(SUM(se.amount)
             FILTER (WHERE se.is_voided = FALSE), 0)            AS storm_total,

    -- Accessory totals
    COALESCE(SUM(sa.price_snapshot)
             FILTER (WHERE sa.is_voided = FALSE), 0)            AS accessories_total,
    COALESCE(SUM(sa.commission_snapshot)
             FILTER (WHERE sa.is_voided = FALSE), 0)            AS accessories_total_commission,

    -- Debt total
    COALESCE(SUM(sd.amount)
             FILTER (WHERE sd.is_voided = FALSE), 0)            AS debt_total,

    -- Expected register cash =
    --   opening_cash + SIM selling + Storm + Accessories − Debts
    cs.opening_cash
    + COALESCE(SUM(ss.selling_price_snapshot) FILTER (WHERE ss.is_voided = FALSE), 0)
    + COALESCE(SUM(se.amount)                 FILTER (WHERE se.is_voided = FALSE), 0)
    + COALESCE(SUM(sa.price_snapshot)         FILTER (WHERE sa.is_voided = FALSE), 0)
    - COALESCE(SUM(sd.amount)                 FILTER (WHERE sd.is_voided = FALSE), 0)
                                                                AS expected_register_cash,

    -- Total cashier benefit (SIM + accessories)
    COALESCE(SUM(ss.commission_snapshot) FILTER (WHERE ss.is_voided = FALSE), 0)
    + COALESCE(SUM(sa.commission_snapshot) FILTER (WHERE sa.is_voided = FALSE), 0)
                                                                AS total_cashier_benefit

FROM cashier_sessions cs
JOIN users  u  ON u.id  = cs.cashier_id
JOIN stores s  ON s.id  = cs.store_id
LEFT JOIN session_sim_sales       ss ON ss.session_id = cs.id
LEFT JOIN session_storm_entries   se ON se.session_id = cs.id
LEFT JOIN session_accessory_sales sa ON sa.session_id = cs.id
LEFT JOIN session_debts           sd ON sd.session_id = cs.id
GROUP BY cs.id, u.full_name, s.name;

COMMENT ON VIEW v_session_live_totals IS
    'Real-time totals for every cashier session. '
    'Used by cashier UI (own session only) and admin dashboard (all sessions).';

-- Current SIM stock remaining per cashier per offer
CREATE VIEW v_sim_stock_remaining AS
SELECT
    ssa.session_id,
    ssa.offer_id,
    o.name                                                      AS offer_name,
    ssa.assigned_quantity,
    COUNT(ss.id) FILTER (WHERE ss.is_voided = FALSE)            AS units_sold,
    ssa.assigned_quantity
    - COUNT(ss.id) FILTER (WHERE ss.is_voided = FALSE)          AS remaining,
    o.low_stock_threshold,
    (ssa.assigned_quantity
     - COUNT(ss.id) FILTER (WHERE ss.is_voided = FALSE))
     <= o.low_stock_threshold                                   AS is_low_stock
FROM sim_stock_assignments ssa
JOIN offers o ON o.id = ssa.offer_id
LEFT JOIN session_sim_sales ss
       ON ss.session_id = ssa.session_id
      AND ss.offer_id   = ssa.offer_id
GROUP BY ssa.session_id, ssa.offer_id, o.name,
         ssa.assigned_quantity, o.low_stock_threshold;

COMMENT ON VIEW v_sim_stock_remaining IS
    'Per-session per-offer remaining SIM card stock with low-stock flag.';

-- Current global pool state (latest admin entry)
CREATE VIEW v_current_pool AS
SELECT available_balance, available_bonus, available_points, updated_at, updated_by
FROM global_pool_state
ORDER BY id DESC
LIMIT 1;

-- Current register cash per store (latest admin entry per store)
CREATE VIEW v_current_register AS
SELECT DISTINCT ON (store_id)
    store_id, cash_amount, updated_at, updated_by
FROM store_register_state
ORDER BY store_id, id DESC;

-- Monthly summary (for admin dashboard charts)
CREATE VIEW v_monthly_summary AS
SELECT
    DATE_TRUNC('month', report_date)::DATE  AS month,
    store_id,
    SUM(total_sim_units)                    AS total_sim_units,
    SUM(total_selling_price)                AS total_selling_price,
    SUM(total_real_price)                   AS total_real_price,
    SUM(total_storm)                        AS total_storm,
    SUM(total_accessories)                  AS total_accessories,
    SUM(total_commissions)                  AS total_commissions,
    SUM(total_debts)                        AS total_debts,
    SUM(gross_profit)                       AS gross_profit,
    COUNT(*)                                AS days_with_activity
FROM daily_reports
GROUP BY DATE_TRUNC('month', report_date), store_id;

COMMENT ON VIEW v_monthly_summary IS 'Aggregated monthly KPIs per store from daily_reports.';

-- =============================================================================
-- UPDATED_AT TRIGGER FUNCTION
-- Keeps updated_at in sync automatically for tables that have it.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_offers_updated_at
    BEFORE UPDATE ON offers
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_products_updated_at
    BEFORE UPDATE ON products
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

-- =============================================================================
-- ENFORCE IMMUTABILITY ON DAILY REPORTS
-- Once a daily report row is created it must never be updated or deleted.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_protect_daily_reports()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION
        'daily_reports rows are immutable. '
        'Delete operation on id=% is forbidden.', OLD.id;
END;
$$;

CREATE TRIGGER trg_protect_daily_reports_delete
    BEFORE DELETE ON daily_reports
    FOR EACH ROW EXECUTE FUNCTION fn_protect_daily_reports();

CREATE OR REPLACE FUNCTION fn_protect_daily_reports_update()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION
        'daily_reports rows are immutable. '
        'Update operation on id=% is forbidden.', OLD.id;
END;
$$;

CREATE TRIGGER trg_protect_daily_reports_update
    BEFORE UPDATE ON daily_reports
    FOR EACH ROW EXECUTE FUNCTION fn_protect_daily_reports_update();

-- =============================================================================
-- ENFORCE IMMUTABILITY ON AUDIT LOGS
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_protect_audit_logs()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'audit_logs is append-only. Mutation forbidden on id=%', OLD.id;
END;
$$;

CREATE TRIGGER trg_protect_audit_logs
    BEFORE UPDATE OR DELETE ON audit_logs
    FOR EACH ROW EXECUTE FUNCTION fn_protect_audit_logs();

-- =============================================================================
-- CLOSE SESSION GUARD
-- Prevent inserting new line items into a closed session.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_guard_closed_session()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_status session_status;
BEGIN
    SELECT status INTO v_status
    FROM cashier_sessions
    WHERE id = NEW.session_id;

    IF v_status = 'closed' THEN
        RAISE EXCEPTION
            'Cannot add entries to a closed session (session_id=%).', NEW.session_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_guard_sim_sales_closed_session
    BEFORE INSERT ON session_sim_sales
    FOR EACH ROW EXECUTE FUNCTION fn_guard_closed_session();

CREATE TRIGGER trg_guard_storm_closed_session
    BEFORE INSERT ON session_storm_entries
    FOR EACH ROW EXECUTE FUNCTION fn_guard_closed_session();

CREATE TRIGGER trg_guard_acc_sales_closed_session
    BEFORE INSERT ON session_accessory_sales
    FOR EACH ROW EXECUTE FUNCTION fn_guard_closed_session();

CREATE TRIGGER trg_guard_debts_closed_session
    BEFORE INSERT ON session_debts
    FOR EACH ROW EXECUTE FUNCTION fn_guard_closed_session();

-- =============================================================================
-- ROW-LEVEL SECURITY (RLS)
-- Enables cashier data isolation at the database layer.
-- The application sets the session variable "app.current_user_id" and
-- "app.current_user_role" on every connection.
-- =============================================================================

ALTER TABLE cashier_sessions        ENABLE ROW LEVEL SECURITY;
ALTER TABLE session_sim_sales       ENABLE ROW LEVEL SECURITY;
ALTER TABLE session_storm_entries   ENABLE ROW LEVEL SECURITY;
ALTER TABLE session_accessory_sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE session_debts           ENABLE ROW LEVEL SECURITY;
ALTER TABLE sim_stock_assignments    ENABLE ROW LEVEL SECURITY;

-- Admin sees all rows; cashier sees only their own sessions.
CREATE POLICY policy_sessions_isolation ON cashier_sessions
    USING (
        current_setting('app.current_user_role', TRUE) = 'admin'
        OR cashier_id = current_setting('app.current_user_id', TRUE)::INT
    );

-- Line-item tables: inherit session isolation via cashier_sessions join.
-- The session_id FK is the anchor — if you can see the session, you see its rows.
CREATE POLICY policy_sim_sales_isolation ON session_sim_sales
    USING (
        current_setting('app.current_user_role', TRUE) = 'admin'
        OR EXISTS (
            SELECT 1 FROM cashier_sessions cs
            WHERE cs.id = session_id
              AND cs.cashier_id = current_setting('app.current_user_id', TRUE)::INT
        )
    );

CREATE POLICY policy_storm_isolation ON session_storm_entries
    USING (
        current_setting('app.current_user_role', TRUE) = 'admin'
        OR EXISTS (
            SELECT 1 FROM cashier_sessions cs
            WHERE cs.id = session_id
              AND cs.cashier_id = current_setting('app.current_user_id', TRUE)::INT
        )
    );

CREATE POLICY policy_acc_sales_isolation ON session_accessory_sales
    USING (
        current_setting('app.current_user_role', TRUE) = 'admin'
        OR EXISTS (
            SELECT 1 FROM cashier_sessions cs
            WHERE cs.id = session_id
              AND cs.cashier_id = current_setting('app.current_user_id', TRUE)::INT
        )
    );

CREATE POLICY policy_debts_isolation ON session_debts
    USING (
        current_setting('app.current_user_role', TRUE) = 'admin'
        OR EXISTS (
            SELECT 1 FROM cashier_sessions cs
            WHERE cs.id = session_id
              AND cs.cashier_id = current_setting('app.current_user_id', TRUE)::INT
        )
    );

CREATE POLICY policy_stock_isolation ON sim_stock_assignments
    USING (
        current_setting('app.current_user_role', TRUE) = 'admin'
        OR EXISTS (
            SELECT 1 FROM cashier_sessions cs
            WHERE cs.id = session_id
              AND cs.cashier_id = current_setting('app.current_user_id', TRUE)::INT
        )
    );

-- =============================================================================
-- END OF SCHEMA
-- =============================================================================
