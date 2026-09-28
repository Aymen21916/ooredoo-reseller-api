'use strict';

/**
 * Wipes all transactional and reference data, then seeds:
 *   - the two stores (AAO Sobha, Kiosque Ain Meraine)
 *   - the four product categories
 *   - the six offer categories
 *   - one admin user (admin / admin@123)
 *
 * Run with: node scripts/reset-database.js
 */

const bcrypt = require('bcryptjs');
const { Pool } = require('pg');

try {
  require('fs').readFileSync('.env', 'utf8')
    .split('\n').filter((l) => l && !l.startsWith('#'))
    .forEach((l) => {
      const [k, ...r] = l.split('=');
      if (k && r.length && !process.env[k.trim()]) process.env[k.trim()] = r.join('=').trim();
    });
} catch {}

const pool = new Pool({
  host:     process.env.DB_HOST,
  port:     parseInt(process.env.DB_PORT || '5432', 10),
  database: process.env.DB_NAME,
  user:     process.env.DB_USER,
  password: process.env.DB_PASSWORD,
});

const ADMIN_USERNAME  = 'admin';
const ADMIN_PASSWORD  = 'admin@123';
const ADMIN_FULL_NAME = 'System Administrator';
const BCRYPT_ROUNDS   = parseInt(process.env.BCRYPT_ROUNDS || '12', 10);

async function run() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // 1. TRUNCATE all data tables in dependency-safe order via CASCADE.
    console.log('• Dropping immutability triggers…');
    await client.query(`DROP TRIGGER IF EXISTS trg_protect_daily_reports_delete ON daily_reports`);
    await client.query(`DROP TRIGGER IF EXISTS trg_protect_daily_reports_update ON daily_reports`);
    await client.query(`DROP TRIGGER IF EXISTS trg_protect_audit_logs ON audit_logs`);

    console.log('• Truncating tables…');
    await client.query(`
      TRUNCATE TABLE
        audit_logs,
        daily_reports,
        store_register_state,
        global_pool_state,
        register_expenses,
        cashier_advances,
        session_debts,
        session_accessory_sales,
        session_storm_entries,
        session_sim_sales,
        sim_cards,
        cashier_sessions,
        refresh_tokens,
        customers,
        products,
        offers,
        users,
        product_categories,
        offer_categories,
        stores
      RESTART IDENTITY CASCADE
    `);

    console.log('• Restoring immutability triggers…');
    await client.query(`
      CREATE TRIGGER trg_protect_daily_reports_delete
        BEFORE DELETE ON daily_reports
        FOR EACH ROW EXECUTE FUNCTION fn_protect_daily_reports()
    `);
    await client.query(`
      CREATE TRIGGER trg_protect_daily_reports_update
        BEFORE UPDATE ON daily_reports
        FOR EACH ROW EXECUTE FUNCTION fn_protect_daily_reports_update()
    `);
    await client.query(`
      CREATE TRIGGER trg_protect_audit_logs
        BEFORE UPDATE OR DELETE ON audit_logs
        FOR EACH ROW EXECUTE FUNCTION fn_protect_audit_logs()
    `);

    // 2. Seed stores
    console.log('• Seeding stores…');
    await client.query(`
      INSERT INTO stores (name, location) VALUES
        ('AAO Sobha',          'Sobha, Algeria'),
        ('Kiosque Ain Meraine','Ain Meraine, Algeria')
    `);

    // 3. Seed product categories
    console.log('• Seeding product categories…');
    await client.query(`
      INSERT INTO product_categories (name, sort_order) VALUES
        ('Phones',       1),
        ('PC Laptops',   2),
        ('PC Desktops',  3),
        ('Accessories',  4)
    `);

    // 4. Seed offer categories
    console.log('• Seeding offer categories…');
    await client.query(`
      INSERT INTO offer_categories (name, sort_order) VALUES
        ('Gold',             1),
        ('N''yooz',          2),
        ('Dima Ooredoo',     3),
        ('Ooredoo',          4),
        ('Ooredoo POP',      5),
        ('Ooredoo Internet', 6)
    `);

    // 5. Create admin
    console.log(`• Creating admin user "${ADMIN_USERNAME}"…`);
    const hash = await bcrypt.hash(ADMIN_PASSWORD, BCRYPT_ROUNDS);
    await client.query(
      `INSERT INTO users (username, password_hash, full_name, role, store_id)
       VALUES ($1, $2, $3, 'admin', NULL)`,
      [ADMIN_USERNAME.toLowerCase(), hash, ADMIN_FULL_NAME]
    );

    await client.query('COMMIT');

    console.log('\n✓ Database reset complete.');
    console.log(`  Admin login → username: ${ADMIN_USERNAME}  password: ${ADMIN_PASSWORD}`);
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

run()
  .then(() => pool.end())
  .catch((err) => {
    console.error('✗ Reset failed:', err.message);
    pool.end();
    process.exit(1);
  });