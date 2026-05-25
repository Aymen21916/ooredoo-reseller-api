'use strict';

/**
 * - Adds products.real_price (cost) for profit calculation
 * - Adds session_accessory_sales.real_price_snapshot + customer_id
 * - Adds session_storm_entries.customer_id
 * - Recreates v_session_live_totals to use the new profit formulas:
 *     SIM profit per unit       = points + selling - real
 *     Accessory profit per unit = selling - real
 *     Storm contribution        = amount (no cost basis)
 *
 * Backfills products.real_price = price (zero margin) so existing rows have a
 * valid value; admin can adjust afterwards.
 */

const { Pool } = require('pg');

try {
  require('fs').readFileSync('.env', 'utf8')
    .split('\n').filter(l => l && !l.startsWith('#'))
    .forEach(l => {
      const [k, ...r] = l.split('=');
      if (k && r.length && !process.env[k.trim()]) process.env[k.trim()] = r.join('=').trim();
    });
} catch {}

const pool = new Pool({
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT || '5432', 10),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
});

const SQL = `
-- 1. products.real_price (cost)
ALTER TABLE products
  ADD COLUMN IF NOT EXISTS real_price NUMERIC(12,2) DEFAULT 0
    CHECK (real_price >= 0);
UPDATE products SET real_price = price WHERE real_price IS NULL OR real_price = 0;
ALTER TABLE products ALTER COLUMN real_price SET NOT NULL;
ALTER TABLE products ALTER COLUMN real_price DROP DEFAULT;
COMMENT ON COLUMN products.real_price IS 'Cost/buying price in DZD. Used for profit calculation.';

-- 2. session_accessory_sales: real_price_snapshot + customer_id
ALTER TABLE session_accessory_sales
  ADD COLUMN IF NOT EXISTS real_price_snapshot NUMERIC(12,2),
  ADD COLUMN IF NOT EXISTS customer_id INT REFERENCES customers(id) ON DELETE SET NULL;

-- Backfill real_price_snapshot to match price_snapshot for historical rows
UPDATE session_accessory_sales SET real_price_snapshot = price_snapshot
  WHERE real_price_snapshot IS NULL;
ALTER TABLE session_accessory_sales ALTER COLUMN real_price_snapshot SET NOT NULL;

CREATE INDEX IF NOT EXISTS idx_acc_sales_customer ON session_accessory_sales(customer_id);

-- 3. session_storm_entries: customer_id
ALTER TABLE session_storm_entries
  ADD COLUMN IF NOT EXISTS customer_id INT REFERENCES customers(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_storm_customer ON session_storm_entries(customer_id);

-- 4. Rebuild the live-totals view with new profit formulas
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
    COUNT(ss.id)    FILTER (WHERE ss.is_voided = FALSE)         AS sim_units_sold,
    COALESCE(SUM(ss.real_price_snapshot)
             FILTER (WHERE ss.is_voided = FALSE), 0)            AS sim_total_real_price,
    COALESCE(SUM(ss.selling_price_snapshot)
             FILTER (WHERE ss.is_voided = FALSE), 0)            AS sim_total_selling_price,
    COALESCE(SUM(ss.points_snapshot)
             FILTER (WHERE ss.is_voided = FALSE), 0)            AS sim_total_points,
    COALESCE(SUM(ss.commission_snapshot)
             FILTER (WHERE ss.is_voided = FALSE), 0)            AS sim_total_commission,
    -- New: SIM profit = points + selling - real (per the business rule)
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
    -- New: Accessory profit = selling - real
    COALESCE(SUM(sa.price_snapshot - sa.real_price_snapshot)
             FILTER (WHERE sa.is_voided = FALSE), 0)            AS accessories_total_profit,

    -- Debt total
    COALESCE(SUM(sd.amount)
             FILTER (WHERE sd.is_voided = FALSE), 0)            AS debt_total,

    -- Expected register cash (unchanged)
    cs.opening_cash
    + COALESCE(SUM(ss.selling_price_snapshot) FILTER (WHERE ss.is_voided = FALSE), 0)
    + COALESCE(SUM(se.amount)                 FILTER (WHERE se.is_voided = FALSE), 0)
    + COALESCE(SUM(sa.price_snapshot)         FILTER (WHERE sa.is_voided = FALSE), 0)
    - COALESCE(SUM(sd.amount)                 FILTER (WHERE sd.is_voided = FALSE), 0)
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
GROUP BY cs.id, u.full_name, s.name;

COMMENT ON VIEW v_session_live_totals IS
  'Real-time totals per session. Profit formulas: SIM profit = points + selling - real, accessory profit = selling - real.';
`;

pool
  .query(SQL)
  .then(() => { console.log('✓ Migration applied.'); return pool.end(); })
  .catch(err => { console.error('✗ Failed:', err.message); pool.end(); process.exit(1); });
