/* eslint-disable camelcase */

'use strict';

/**
 * Make SIM cards generic: a card no longer carries an offer_id at assignment.
 * The offer is decided at sale time and snapshotted onto session_sim_sales.
 */

exports.shorthands = undefined;

exports.up = (pgm) => {
  pgm.sql(`
    DROP VIEW IF EXISTS v_cashier_sim_inventory;

    DROP INDEX IF EXISTS idx_sim_cards_available;
    DROP INDEX IF EXISTS idx_sim_cards_offer;
    ALTER TABLE sim_cards DROP COLUMN IF EXISTS offer_id;

    CREATE INDEX idx_sim_cards_available
      ON sim_cards (cashier_id, serial_number)
      WHERE status = 'available';

    CREATE VIEW v_cashier_sim_inventory AS
    SELECT
      sc.cashier_id,
      u.full_name                                                 AS cashier_name,
      u.store_id,
      s.name                                                      AS store_name,
      COUNT(*) FILTER (WHERE sc.status = 'available')             AS available_count,
      COUNT(*) FILTER (WHERE sc.status = 'sold')                  AS sold_count,
      COUNT(*) FILTER (WHERE sc.status = 'voided')                AS voided_count,
      MIN(sc.serial_number) FILTER (WHERE sc.status = 'available') AS next_serial,
      MAX(sc.serial_number) FILTER (WHERE sc.status = 'available') AS last_serial,
      COUNT(*) FILTER (WHERE sc.status = 'available') <= 5
        AS is_low_stock
    FROM sim_cards sc
    JOIN users  u ON u.id = sc.cashier_id
    JOIN stores s ON s.id = u.store_id
    GROUP BY sc.cashier_id, u.full_name, u.store_id, s.name;
  `);
};

exports.down = (pgm) => {
  pgm.sql(`
    DROP VIEW IF EXISTS v_cashier_sim_inventory;
    DROP INDEX IF EXISTS idx_sim_cards_available;

    ALTER TABLE sim_cards
      ADD COLUMN offer_id INT REFERENCES offers(id) ON DELETE RESTRICT;

    CREATE INDEX idx_sim_cards_offer ON sim_cards (offer_id);
    CREATE INDEX idx_sim_cards_available
      ON sim_cards (cashier_id, offer_id, serial_number)
      WHERE status = 'available';
  `);
};
