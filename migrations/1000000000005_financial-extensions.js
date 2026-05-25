/* eslint-disable camelcase */

'use strict';

/**
 * POS financial-tracking extensions:
 *
 *   1. Inserts the `LEGACY-UNKNOWN` placeholder customer used to back-fill
 *      pre-existing `session_debts` rows that have no `customer_id`.
 *
 *   2. Adds `customer_id` (NOT NULL, FK to `customers`) to `session_debts`,
 *      back-filling NULLs to the placeholder before flipping the column to
 *      NOT NULL, and creates `idx_debts_customer`.
 *
 *   3. Creates `cashier_advances` for tracking cashier draws and admin-recorded
 *      repayments, with a CHECK that advance rows carry a `session_id` and
 *      repayment rows do not. Adds the three indexes from the design.
 *
 *   4. Creates `register_expenses` for La Caisse spend tracking, with the four
 *      indexes from the design.
 *
 *   5. Rebuilds `v_session_live_totals` so the per-session
 *      `expected_register_cash` projection nets out non-voided
 *      `register_expenses.amount` rows scoped to the same session.
 *
 * The `down` migration drops the new tables, the `customer_id` column, and
 * rebuilds `v_session_live_totals` without the register-expense subtraction.
 * The placeholder customer is intentionally NOT removed — deleting it would
 * fail if any debt rows still reference it under the ON DELETE RESTRICT FK.
 */

exports.shorthands = undefined;

exports.up = (pgm) => {
  pgm.sql(`
    -- ─── 1. Placeholder customer for legacy debts ─────────────────────────
    INSERT INTO customers (phone_number, first_name, last_name, address, profession, notes)
    VALUES ('LEGACY-UNKNOWN', 'Unknown', 'Customer (legacy)', '—', '—',
            'Auto-created placeholder for pre-customer-link debts.')
    ON CONFLICT (phone_number) DO NOTHING;

    -- ─── 2. Add customer_id to session_debts ──────────────────────────────
    ALTER TABLE session_debts
      ADD COLUMN IF NOT EXISTS customer_id INT REFERENCES customers(id) ON DELETE RESTRICT;

    UPDATE session_debts
       SET customer_id = (SELECT id FROM customers WHERE phone_number = 'LEGACY-UNKNOWN')
     WHERE customer_id IS NULL;

    ALTER TABLE session_debts ALTER COLUMN customer_id SET NOT NULL;
    CREATE INDEX IF NOT EXISTS idx_debts_customer ON session_debts(customer_id);

    -- ─── 3. Cashier advances ──────────────────────────────────────────────
    CREATE TABLE IF NOT EXISTS cashier_advances (
      id            SERIAL          PRIMARY KEY,
      cashier_id    INT             NOT NULL REFERENCES users(id)            ON DELETE RESTRICT,
      session_id    INT             REFERENCES cashier_sessions(id)          ON DELETE RESTRICT,
      direction     VARCHAR(10)     NOT NULL CHECK (direction IN ('advance','repayment')),
      amount        NUMERIC(12, 2)  NOT NULL CHECK (amount >= 0.01 AND amount <= 9999999999.99),
      note          TEXT            CHECK (note IS NULL OR length(note) <= 500),
      is_voided     BOOLEAN         NOT NULL DEFAULT FALSE,
      voided_at     TIMESTAMPTZ,
      voided_by     INT             REFERENCES users(id) ON DELETE SET NULL,
      void_reason   TEXT            CHECK (void_reason IS NULL OR
                                           (length(trim(void_reason)) BETWEEN 1 AND 500)),
      created_at    TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
      created_by    INT             NOT NULL REFERENCES users(id) ON DELETE RESTRICT,

      -- Advance entries must have a session; repayments must not.
      CONSTRAINT advance_has_session
        CHECK ((direction = 'advance'   AND session_id IS NOT NULL) OR
               (direction = 'repayment' AND session_id IS NULL))
    );

    COMMENT ON TABLE  cashier_advances IS
      'Rolling ledger of cashier register draws (advance) and admin-recorded repayments.';
    COMMENT ON COLUMN cashier_advances.session_id IS
      'Open session at the time of an advance; NULL for admin-recorded repayments.';

    CREATE INDEX IF NOT EXISTS idx_advances_cashier ON cashier_advances(cashier_id);
    CREATE INDEX IF NOT EXISTS idx_advances_session ON cashier_advances(session_id);
    CREATE INDEX IF NOT EXISTS idx_advances_active  ON cashier_advances(cashier_id)
      WHERE is_voided = FALSE;

    -- ─── 4. Register expenses ─────────────────────────────────────────────
    CREATE TABLE IF NOT EXISTS register_expenses (
      id            SERIAL          PRIMARY KEY,
      store_id      INT             NOT NULL REFERENCES stores(id)           ON DELETE RESTRICT,
      session_id    INT             REFERENCES cashier_sessions(id)          ON DELETE RESTRICT,
      amount        NUMERIC(12, 2)  NOT NULL CHECK (amount >= 0.01 AND amount <= 9999999.99),
      expense_date  DATE            NOT NULL,
      description   TEXT            NOT NULL CHECK (length(trim(description)) BETWEEN 1 AND 500),
      category      VARCHAR(20)     NOT NULL CHECK (category IN ('utility','inventory','other')),
      is_voided     BOOLEAN         NOT NULL DEFAULT FALSE,
      voided_at     TIMESTAMPTZ,
      voided_by     INT             REFERENCES users(id) ON DELETE SET NULL,
      void_reason   TEXT            CHECK (void_reason IS NULL OR
                                           (length(trim(void_reason)) BETWEEN 1 AND 500)),
      created_at    TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
      created_by    INT             NOT NULL REFERENCES users(id) ON DELETE RESTRICT
    );

    COMMENT ON TABLE  register_expenses IS
      'Operational spend out of the store register (utilities, restock, other).';
    COMMENT ON COLUMN register_expenses.session_id IS
      'Open session at the time of a cashier-recorded expense; NULL for admin entries.';

    CREATE INDEX IF NOT EXISTS idx_expenses_store_date ON register_expenses(store_id, expense_date DESC);
    CREATE INDEX IF NOT EXISTS idx_expenses_session    ON register_expenses(session_id);
    CREATE INDEX IF NOT EXISTS idx_expenses_active     ON register_expenses(store_id)
      WHERE is_voided = FALSE;
    CREATE INDEX IF NOT EXISTS idx_expenses_category   ON register_expenses(category);

    -- ─── 5. Rebuild v_session_live_totals ─────────────────────────────────
    -- Same shape as the previous view (keeps profit columns the controllers
    -- depend on) but the expected_register_cash projection now subtracts
    -- non-voided register expenses for the session.
    DROP VIEW IF EXISTS v_session_live_totals;

    CREATE VIEW v_session_live_totals AS
    SELECT
        cs.id                                                       AS session_id,
        cs.cashier_id,
        u.full_name                                                 AS cashier_name,
        cs.store_id,
        s.name                                                      AS store_name,
        cs.session_date,
        cs.opening_cash,

        -- SIM totals (non-voided)
        COUNT(ss.id) FILTER (WHERE ss.is_voided = FALSE)            AS sim_units_sold,
        COALESCE(SUM(ss.real_price_snapshot)
                 FILTER (WHERE ss.is_voided = FALSE), 0)            AS sim_total_real_price,
        COALESCE(SUM(ss.selling_price_snapshot)
                 FILTER (WHERE ss.is_voided = FALSE), 0)            AS sim_total_selling_price,
        COALESCE(SUM(ss.points_snapshot)
                 FILTER (WHERE ss.is_voided = FALSE), 0)            AS sim_total_points,
        COALESCE(SUM(ss.commission_snapshot)
                 FILTER (WHERE ss.is_voided = FALSE), 0)            AS sim_total_commission,
        COALESCE(SUM(ss.points_snapshot + ss.selling_price_snapshot - ss.real_price_snapshot)
                 FILTER (WHERE ss.is_voided = FALSE), 0)            AS sim_total_profit,

        -- Storm totals
        COALESCE(SUM(se.amount)
                 FILTER (WHERE se.is_voided = FALSE), 0)            AS storm_total,

        -- Accessory totals
        COALESCE(SUM(sa.price_snapshot)
                 FILTER (WHERE sa.is_voided = FALSE), 0)            AS accessories_total,
        COALESCE(SUM(sa.real_price_snapshot)
                 FILTER (WHERE sa.is_voided = FALSE), 0)            AS accessories_total_real_price,
        COALESCE(SUM(sa.commission_snapshot)
                 FILTER (WHERE sa.is_voided = FALSE), 0)            AS accessories_total_commission,
        COALESCE(SUM(sa.price_snapshot - sa.real_price_snapshot)
                 FILTER (WHERE sa.is_voided = FALSE), 0)            AS accessories_total_profit,

        -- Debt total
        COALESCE(SUM(sd.amount)
                 FILTER (WHERE sd.is_voided = FALSE), 0)            AS debt_total,

        -- Register-expense total for the session (non-voided only)
        COALESCE(re.expense_total, 0)                               AS register_expense_total,

        -- Expected register cash =
        --   opening_cash + SIM selling + Storm + Accessories
        --   − Debts − Register expenses (non-voided, session-scoped)
        cs.opening_cash
        + COALESCE(SUM(ss.selling_price_snapshot) FILTER (WHERE ss.is_voided = FALSE), 0)
        + COALESCE(SUM(se.amount)                 FILTER (WHERE se.is_voided = FALSE), 0)
        + COALESCE(SUM(sa.price_snapshot)         FILTER (WHERE sa.is_voided = FALSE), 0)
        - COALESCE(SUM(sd.amount)                 FILTER (WHERE sd.is_voided = FALSE), 0)
        - COALESCE(re.expense_total, 0)
                                                                    AS expected_register_cash,

        -- Total cashier benefit (commissions, unchanged)
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
    LEFT JOIN (
        SELECT session_id,
               SUM(amount) FILTER (WHERE is_voided = FALSE) AS expense_total
          FROM register_expenses
         WHERE session_id IS NOT NULL
         GROUP BY session_id
    ) re ON re.session_id = cs.id
    GROUP BY cs.id, u.full_name, s.name, re.expense_total;

    COMMENT ON VIEW v_session_live_totals IS
      'Real-time totals per session. SIM profit = points + selling - real, accessory profit = selling - real. Cash projection nets out non-voided register expenses for the session.';
  `);
};

exports.down = (pgm) => {
  pgm.sql(`
    -- The view depends on register_expenses; drop it first so the table can go.
    DROP VIEW IF EXISTS v_session_live_totals;

    DROP TABLE IF EXISTS register_expenses;
    DROP TABLE IF EXISTS cashier_advances;

    ALTER TABLE session_debts DROP COLUMN IF EXISTS customer_id;

    -- Recreate the previous v_session_live_totals (without the register-expense
    -- subtraction). The placeholder customer is intentionally NOT deleted: it
    -- may still be referenced by debts created after the up-migration ran.
    CREATE VIEW v_session_live_totals AS
    SELECT
        cs.id                                                       AS session_id,
        cs.cashier_id,
        u.full_name                                                 AS cashier_name,
        cs.store_id,
        s.name                                                      AS store_name,
        cs.session_date,
        cs.opening_cash,

        COUNT(ss.id) FILTER (WHERE ss.is_voided = FALSE)            AS sim_units_sold,
        COALESCE(SUM(ss.real_price_snapshot)
                 FILTER (WHERE ss.is_voided = FALSE), 0)            AS sim_total_real_price,
        COALESCE(SUM(ss.selling_price_snapshot)
                 FILTER (WHERE ss.is_voided = FALSE), 0)            AS sim_total_selling_price,
        COALESCE(SUM(ss.points_snapshot)
                 FILTER (WHERE ss.is_voided = FALSE), 0)            AS sim_total_points,
        COALESCE(SUM(ss.commission_snapshot)
                 FILTER (WHERE ss.is_voided = FALSE), 0)            AS sim_total_commission,
        COALESCE(SUM(ss.points_snapshot + ss.selling_price_snapshot - ss.real_price_snapshot)
                 FILTER (WHERE ss.is_voided = FALSE), 0)            AS sim_total_profit,

        COALESCE(SUM(se.amount)
                 FILTER (WHERE se.is_voided = FALSE), 0)            AS storm_total,

        COALESCE(SUM(sa.price_snapshot)
                 FILTER (WHERE sa.is_voided = FALSE), 0)            AS accessories_total,
        COALESCE(SUM(sa.real_price_snapshot)
                 FILTER (WHERE sa.is_voided = FALSE), 0)            AS accessories_total_real_price,
        COALESCE(SUM(sa.commission_snapshot)
                 FILTER (WHERE sa.is_voided = FALSE), 0)            AS accessories_total_commission,
        COALESCE(SUM(sa.price_snapshot - sa.real_price_snapshot)
                 FILTER (WHERE sa.is_voided = FALSE), 0)            AS accessories_total_profit,

        COALESCE(SUM(sd.amount)
                 FILTER (WHERE sd.is_voided = FALSE), 0)            AS debt_total,

        cs.opening_cash
        + COALESCE(SUM(ss.selling_price_snapshot) FILTER (WHERE ss.is_voided = FALSE), 0)
        + COALESCE(SUM(se.amount)                 FILTER (WHERE se.is_voided = FALSE), 0)
        + COALESCE(SUM(sa.price_snapshot)         FILTER (WHERE sa.is_voided = FALSE), 0)
        - COALESCE(SUM(sd.amount)                 FILTER (WHERE sd.is_voided = FALSE), 0)
                                                                    AS expected_register_cash,

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
  `);
};
