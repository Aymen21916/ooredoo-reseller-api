/* eslint-disable camelcase */

'use strict';

exports.shorthands = undefined;

exports.up = (pgm) => {
  pgm.sql(`
    ALTER TABLE products
      ADD COLUMN IF NOT EXISTS real_price NUMERIC(12,2) DEFAULT 0
        CHECK (real_price >= 0);
    UPDATE products SET real_price = price WHERE real_price IS NULL OR real_price = 0;
    ALTER TABLE products ALTER COLUMN real_price SET NOT NULL;
    ALTER TABLE products ALTER COLUMN real_price DROP DEFAULT;

    ALTER TABLE session_accessory_sales
      ADD COLUMN IF NOT EXISTS real_price_snapshot NUMERIC(12,2),
      ADD COLUMN IF NOT EXISTS customer_id INT REFERENCES customers(id) ON DELETE SET NULL;
    UPDATE session_accessory_sales SET real_price_snapshot = price_snapshot
      WHERE real_price_snapshot IS NULL;
    ALTER TABLE session_accessory_sales ALTER COLUMN real_price_snapshot SET NOT NULL;

    CREATE INDEX IF NOT EXISTS idx_acc_sales_customer ON session_accessory_sales(customer_id);

    ALTER TABLE session_storm_entries
      ADD COLUMN IF NOT EXISTS customer_id INT REFERENCES customers(id) ON DELETE SET NULL;
    CREATE INDEX IF NOT EXISTS idx_storm_customer ON session_storm_entries(customer_id);

    DROP VIEW IF EXISTS v_session_live_totals;
    -- Recreated by the application's view-rebuild on startup or from schema.sql.
  `);
};

exports.down = (pgm) => {
  pgm.sql(`
    ALTER TABLE session_storm_entries DROP COLUMN IF EXISTS customer_id;
    ALTER TABLE session_accessory_sales DROP COLUMN IF EXISTS customer_id, DROP COLUMN IF EXISTS real_price_snapshot;
    ALTER TABLE products DROP COLUMN IF EXISTS real_price;
  `);
};
