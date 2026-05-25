/* eslint-disable camelcase */

'use strict';

/**
 * Switches SIM stock from session-scoped quantity assignments to physical
 * cashier-owned SIM cards identified by serial number.
 *
 *   - Adds enum `sim_card_status`
 *   - Adds table `sim_cards` (one row per physical SIM)
 *   - Adds columns to `session_sim_sales` linking the sale to the consumed card
 *   - Adds view `v_cashier_sim_inventory` for admin dashboards
 *   - Drops obsolete view `v_sim_stock_remaining` and table `sim_stock_assignments`
 */

exports.shorthands = undefined;

exports.up = (pgm) => {
  pgm.sql(`
    -- Enum
    CREATE TYPE sim_card_status AS ENUM ('available', 'sold', 'voided');

    -- Physical SIM cards owned by cashiers
    CREATE TABLE sim_cards (
      id              SERIAL          PRIMARY KEY,
      serial_number   VARCHAR(32)     NOT NULL UNIQUE,
      offer_id        INT             NOT NULL REFERENCES offers(id) ON DELETE RESTRICT,
      cashier_id      INT             NOT NULL REFERENCES users(id)  ON DELETE RESTRICT,
      status          sim_card_status NOT NULL DEFAULT 'available',
      assigned_by     INT             NOT NULL REFERENCES users(id)  ON DELETE RESTRICT,
      assigned_at     TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
      sold_at         TIMESTAMPTZ
    );

    COMMENT ON TABLE  sim_cards IS 'Physical SIM card inventory owned by cashiers.';
    COMMENT ON COLUMN sim_cards.serial_number IS 'Unique SIM serial number (15-20 digit numeric string).';

    CREATE INDEX idx_sim_cards_cashier ON sim_cards (cashier_id);
    CREATE INDEX idx_sim_cards_offer   ON sim_cards (offer_id);
    CREATE INDEX idx_sim_cards_status  ON sim_cards (status);
    CREATE INDEX idx_sim_cards_available ON sim_cards (cashier_id, offer_id, serial_number)
      WHERE status = 'available';

    -- Link session sales to the physical SIM consumed
    ALTER TABLE session_sim_sales
      ADD COLUMN sim_card_id            INT REFERENCES sim_cards(id) ON DELETE SET NULL,
      ADD COLUMN serial_number_snapshot VARCHAR(32);

    -- Admin dashboard view: per cashier, per offer, available/sold counts
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

    COMMENT ON VIEW v_cashier_sim_inventory IS
      'Cashier SIM inventory aggregated by offer with low-stock flag.';

    -- Drop obsolete session-scoped stock model
    DROP VIEW  IF EXISTS v_sim_stock_remaining;
    DROP TABLE IF EXISTS sim_stock_assignments;
  `);
};

exports.down = (pgm) => {
  pgm.sql(`
    DROP VIEW IF EXISTS v_cashier_sim_inventory;

    ALTER TABLE session_sim_sales
      DROP COLUMN IF EXISTS sim_card_id,
      DROP COLUMN IF EXISTS serial_number_snapshot;

    DROP TABLE IF EXISTS sim_cards;
    DROP TYPE  IF EXISTS sim_card_status;

    -- Recreate the old assignment table (data is lost — this is best-effort)
    CREATE TABLE sim_stock_assignments (
      id                SERIAL      PRIMARY KEY,
      session_id        INT         NOT NULL REFERENCES cashier_sessions(id) ON DELETE CASCADE,
      offer_id          INT         NOT NULL REFERENCES offers(id)           ON DELETE RESTRICT,
      assigned_quantity INT         NOT NULL CHECK (assigned_quantity >= 0),
      assigned_by       INT         NOT NULL REFERENCES users(id)            ON DELETE RESTRICT,
      assigned_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      CONSTRAINT unique_offer_per_session UNIQUE (session_id, offer_id)
    );
  `);
};
