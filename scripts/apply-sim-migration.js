'use strict';

/**
 * Apply the SIM-cards inventory migration directly to the existing database.
 * One-shot helper because the existing DB was bootstrapped from schema.sql,
 * not via node-pg-migrate.
 */

const { Pool } = require('pg');

try {
  require('fs').readFileSync('.env', 'utf8')
    .split('\n')
    .filter((line) => line && !line.startsWith('#'))
    .forEach((line) => {
      const [key, ...rest] = line.split('=');
      if (key && rest.length && !process.env[key.trim()]) {
        process.env[key.trim()] = rest.join('=').trim();
      }
    });
} catch { /* .env optional */ }

const pool = new Pool({
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT || '5432', 10),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
});

const SQL = `
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'sim_card_status') THEN
    CREATE TYPE sim_card_status AS ENUM ('available', 'sold', 'voided');
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS sim_cards (
  id              SERIAL          PRIMARY KEY,
  serial_number   VARCHAR(32)     NOT NULL UNIQUE,
  offer_id        INT             NOT NULL REFERENCES offers(id) ON DELETE RESTRICT,
  cashier_id      INT             NOT NULL REFERENCES users(id)  ON DELETE RESTRICT,
  status          sim_card_status NOT NULL DEFAULT 'available',
  assigned_by     INT             NOT NULL REFERENCES users(id)  ON DELETE RESTRICT,
  assigned_at     TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
  sold_at         TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_sim_cards_cashier ON sim_cards (cashier_id);
CREATE INDEX IF NOT EXISTS idx_sim_cards_offer   ON sim_cards (offer_id);
CREATE INDEX IF NOT EXISTS idx_sim_cards_status  ON sim_cards (status);
CREATE INDEX IF NOT EXISTS idx_sim_cards_available
  ON sim_cards (cashier_id, offer_id, serial_number)
  WHERE status = 'available';

ALTER TABLE session_sim_sales
  ADD COLUMN IF NOT EXISTS sim_card_id            INT REFERENCES sim_cards(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS serial_number_snapshot VARCHAR(32);

DROP VIEW IF EXISTS v_cashier_sim_inventory;
CREATE VIEW v_cashier_sim_inventory AS
SELECT
  sc.cashier_id,
  u.full_name                                                AS cashier_name,
  u.store_id,
  s.name                                                     AS store_name,
  sc.offer_id,
  o.name                                                     AS offer_name,
  o.low_stock_threshold,
  COUNT(*) FILTER (WHERE sc.status = 'available')            AS available_count,
  COUNT(*) FILTER (WHERE sc.status = 'sold')                 AS sold_count,
  COUNT(*) FILTER (WHERE sc.status = 'voided')               AS voided_count,
  MIN(sc.serial_number) FILTER (WHERE sc.status = 'available') AS next_serial,
  COUNT(*) FILTER (WHERE sc.status = 'available') <= o.low_stock_threshold
    AS is_low_stock
FROM sim_cards sc
JOIN users  u ON u.id = sc.cashier_id
JOIN stores s ON s.id = u.store_id
JOIN offers o ON o.id = sc.offer_id
GROUP BY sc.cashier_id, u.full_name, u.store_id, s.name,
         sc.offer_id, o.name, o.low_stock_threshold;

DROP VIEW  IF EXISTS v_sim_stock_remaining;
DROP TABLE IF EXISTS sim_stock_assignments;
`;

pool
  .query(SQL)
  .then(() => {
    console.log('✓ Migration applied successfully.');
    return pool.end();
  })
  .catch((err) => {
    console.error('✗ Migration failed:', err.message);
    pool.end();
    process.exit(1);
  });
