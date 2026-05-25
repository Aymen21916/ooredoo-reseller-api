'use strict';

/**
 * Adds offer categories, a customers table for loyalty tracking, and a link
 * from session_sim_sales to the customer who bought the SIM.
 *
 * Existing offers are auto-assigned a category by name match, with "Ooredoo"
 * as the fallback bucket so the admin can re-categorize any stragglers in
 * the UI later.
 */

const { Pool } = require('pg');

try {
  require('fs').readFileSync('.env', 'utf8')
    .split('\n').filter(l => l && !l.startsWith('#'))
    .forEach(l => {
      const [k, ...r] = l.split('=');
      if (k && r.length && !process.env[k.trim()]) {
        process.env[k.trim()] = r.join('=').trim();
      }
    });
} catch {}

const pool = new Pool({
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT || '5432', 10),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
});

const SEED_CATEGORIES = [
  { name: 'Gold',             sort_order: 1 },
  { name: "N'yooz",           sort_order: 2 },
  { name: 'Dima Ooredoo',     sort_order: 3 },
  { name: 'Ooredoo',          sort_order: 4 },
  { name: 'Ooredoo POP',      sort_order: 5 },
  { name: 'Ooredoo Internet', sort_order: 6 },
];

// Best-effort name-match rules; first match wins. Fallback is "Ooredoo".
const NAME_MATCH_RULES = [
  { match: 'gold',     category: 'Gold' },
  { match: 'pop',      category: 'Ooredoo POP' },
  { match: 'internet', category: 'Ooredoo Internet' },
  { match: 'dima',     category: 'Dima Ooredoo' },
  { match: 'nyooz',    category: "N'yooz" },
  { match: "n'yooz",   category: "N'yooz" },
  { match: 'switch',   category: 'Ooredoo' },
];

async function run() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // 1. offer_categories
    await client.query(`
      CREATE TABLE IF NOT EXISTS offer_categories (
        id          SERIAL          PRIMARY KEY,
        name        VARCHAR(50)     NOT NULL UNIQUE,
        sort_order  INT             NOT NULL DEFAULT 0,
        is_active   BOOLEAN         NOT NULL DEFAULT TRUE,
        created_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW()
      )
    `);

    for (const c of SEED_CATEGORIES) {
      await client.query(
        `INSERT INTO offer_categories (name, sort_order)
         VALUES ($1, $2)
         ON CONFLICT (name) DO NOTHING`,
        [c.name, c.sort_order]
      );
    }

    // 2. offers.category_id (nullable first so we can backfill)
    await client.query(`
      ALTER TABLE offers
      ADD COLUMN IF NOT EXISTS category_id INT
        REFERENCES offer_categories(id) ON DELETE RESTRICT
    `);

    // 3. Backfill: for each rule, assign matching offers
    for (const rule of NAME_MATCH_RULES) {
      await client.query(
        `UPDATE offers
         SET category_id = (SELECT id FROM offer_categories WHERE name = $1)
         WHERE category_id IS NULL
           AND LOWER(name) LIKE '%' || $2 || '%'`,
        [rule.category, rule.match.toLowerCase()]
      );
    }

    // Fallback: anything still null → Ooredoo
    await client.query(
      `UPDATE offers
       SET category_id = (SELECT id FROM offer_categories WHERE name = 'Ooredoo')
       WHERE category_id IS NULL`
    );

    // 4. Now make NOT NULL
    await client.query(`ALTER TABLE offers ALTER COLUMN category_id SET NOT NULL`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_offers_category ON offers(category_id)`);

    // 5. customers
    await client.query(`
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
      )
    `);

    await client.query(`CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone_number)`);
    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_customers_name_trgm
      ON customers USING GIN ((first_name || ' ' || last_name) gin_trgm_ops)
    `);

    // updated_at trigger (re-uses fn_set_updated_at)
    await client.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_customers_updated_at') THEN
          CREATE TRIGGER trg_customers_updated_at
            BEFORE UPDATE ON customers
            FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();
        END IF;
      END$$
    `);

    // 6. Link sim sales to customers (nullable for historical rows)
    await client.query(`
      ALTER TABLE session_sim_sales
      ADD COLUMN IF NOT EXISTS customer_id INT
        REFERENCES customers(id) ON DELETE SET NULL
    `);
    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_sim_sales_customer ON session_sim_sales(customer_id)
    `);

    await client.query('COMMIT');
    console.log('✓ Migration applied: offer_categories, customers, session_sim_sales.customer_id.');

    const { rows } = await client.query(`
      SELECT oc.name AS category, COUNT(*) AS offer_count
      FROM offers o
      JOIN offer_categories oc ON oc.id = o.category_id
      GROUP BY oc.name
      ORDER BY oc.name
    `);
    console.log('\nOffers per category:');
    rows.forEach(r => console.log(`  ${r.category.padEnd(20)} ${r.offer_count}`));
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

run()
  .then(() => pool.end())
  .catch(err => {
    console.error('✗ Migration failed:', err.message);
    pool.end();
    process.exit(1);
  });
