/* eslint-disable camelcase */

'use strict';

/**
 * Adds offer categories, a customer loyalty table, and a link from
 * session_sim_sales to the customer.
 */

exports.shorthands = undefined;

exports.up = (pgm) => {
  pgm.sql(`
    CREATE TABLE IF NOT EXISTS offer_categories (
      id          SERIAL          PRIMARY KEY,
      name        VARCHAR(50)     NOT NULL UNIQUE,
      sort_order  INT             NOT NULL DEFAULT 0,
      is_active   BOOLEAN         NOT NULL DEFAULT TRUE,
      created_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW()
    );

    INSERT INTO offer_categories (name, sort_order) VALUES
      ('Gold',             1),
      ('N''yooz',          2),
      ('Dima Ooredoo',     3),
      ('Ooredoo',          4),
      ('Ooredoo POP',      5),
      ('Ooredoo Internet', 6)
    ON CONFLICT (name) DO NOTHING;

    ALTER TABLE offers
      ADD COLUMN IF NOT EXISTS category_id INT
        REFERENCES offer_categories(id) ON DELETE RESTRICT;

    -- Best-effort backfill by name
    UPDATE offers SET category_id = (SELECT id FROM offer_categories WHERE name = 'Gold')
      WHERE category_id IS NULL AND LOWER(name) LIKE '%gold%';
    UPDATE offers SET category_id = (SELECT id FROM offer_categories WHERE name = 'Ooredoo POP')
      WHERE category_id IS NULL AND LOWER(name) LIKE '%pop%';
    UPDATE offers SET category_id = (SELECT id FROM offer_categories WHERE name = 'Ooredoo Internet')
      WHERE category_id IS NULL AND LOWER(name) LIKE '%internet%';
    UPDATE offers SET category_id = (SELECT id FROM offer_categories WHERE name = 'Dima Ooredoo')
      WHERE category_id IS NULL AND LOWER(name) LIKE '%dima%';
    UPDATE offers SET category_id = (SELECT id FROM offer_categories WHERE name = 'N''yooz')
      WHERE category_id IS NULL AND (LOWER(name) LIKE '%nyooz%' OR LOWER(name) LIKE E'%n\\'yooz%');
    UPDATE offers SET category_id = (SELECT id FROM offer_categories WHERE name = 'Ooredoo')
      WHERE category_id IS NULL;

    ALTER TABLE offers ALTER COLUMN category_id SET NOT NULL;
    CREATE INDEX IF NOT EXISTS idx_offers_category ON offers(category_id);

    CREATE TABLE IF NOT EXISTS customers (
      id            SERIAL          PRIMARY KEY,
      phone_number  VARCHAR(20)     NOT NULL UNIQUE,
      first_name    VARCHAR(100)    NOT NULL,
      last_name     VARCHAR(100)    NOT NULL,
      address       TEXT            NOT NULL,
      profession    VARCHAR(100)    NOT NULL,
      notes         TEXT,
      created_by    INT             REFERENCES users(id) ON DELETE SET NULL,
      created_at    TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
      updated_at    TIMESTAMPTZ     NOT NULL DEFAULT NOW()
    );

    CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone_number);
    CREATE INDEX IF NOT EXISTS idx_customers_name_trgm
      ON customers USING GIN ((first_name || ' ' || last_name) gin_trgm_ops);

    DO $$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_customers_updated_at') THEN
        CREATE TRIGGER trg_customers_updated_at
          BEFORE UPDATE ON customers
          FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();
      END IF;
    END$$;

    ALTER TABLE session_sim_sales
      ADD COLUMN IF NOT EXISTS customer_id INT
        REFERENCES customers(id) ON DELETE SET NULL;

    CREATE INDEX IF NOT EXISTS idx_sim_sales_customer ON session_sim_sales(customer_id);
  `);
};

exports.down = (pgm) => {
  pgm.sql(`
    ALTER TABLE session_sim_sales DROP COLUMN IF EXISTS customer_id;
    DROP TABLE IF EXISTS customers;

    ALTER TABLE offers DROP COLUMN IF EXISTS category_id;
    DROP TABLE IF EXISTS offer_categories;
  `);
};
