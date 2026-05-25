'use strict';

/**
 * Wipes all transactional data and reseeds reference tables, but keeps the
 * existing admin user(s). Cashiers and their related rows are removed.
 *
 * Run with: node scripts/clear-keep-admin.js
 */

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

async function run() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Snapshot the admin(s) we want to keep so we can restore the rows verbatim
    console.log('• Snapshotting admin user(s)…');
    const { rows: admins } = await client.query(`
      SELECT id, username, password_hash, full_name, role, store_id, is_active,
             created_at, updated_at
      FROM users
      WHERE role = 'admin'
    `);
    console.log(`  Found ${admins.length} admin(s) to preserve: ${admins.map(a => a.username).join(', ') || '(none)'}`);

    // Drop append-only / immutability triggers so we can wipe their tables.
    console.log('• Temporarily dropping protective triggers…');
    await client.query(`DROP TRIGGER IF EXISTS trg_protect_daily_reports_delete ON daily_reports`);
    await client.query(`DROP TRIGGER IF EXISTS trg_protect_daily_reports_update ON daily_reports`);
    await client.query(`DROP TRIGGER IF EXISTS trg_protect_audit_logs ON audit_logs`);

    // Truncate everything (CASCADE handles FK chains in one shot)
    console.log('• Truncating tables…');
    await client.query(`
      TRUNCATE TABLE
        audit_logs,
        daily_reports,
        store_register_state,
        global_pool_state,
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

    // Restore the protective triggers immediately
    console.log('• Restoring protective triggers…');
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

    // Reseed reference tables
    console.log('• Seeding stores…');
    await client.query(`
      INSERT INTO stores (name, location) VALUES
        ('AAO Sobha',          'Sobha, Algeria'),
        ('Kiosque Ain Meraine','Ain Meraine, Algeria')
    `);

    console.log('• Seeding product categories…');
    await client.query(`
      INSERT INTO product_categories (name, sort_order) VALUES
        ('Phones',       1),
        ('PC Laptops',   2),
        ('PC Desktops',  3),
        ('Accessories',  4)
    `);

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

    // Restore the admin(s) with their original IDs preserved
    if (admins.length === 0) {
      throw new Error('No admin found in the database! Aborting to avoid an unusable system.');
    }

    console.log('• Restoring admin user(s)…');
    for (const a of admins) {
      await client.query(
        `INSERT INTO users
           (id, username, password_hash, full_name, role, store_id, is_active, created_at, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
        [a.id, a.username, a.password_hash, a.full_name, a.role, a.store_id, a.is_active, a.created_at, a.updated_at]
      );
    }

    // Bump the users id sequence so future inserts don't collide
    await client.query(`SELECT setval('users_id_seq', GREATEST(MAX(id), 1)) FROM users`);

    await client.query('COMMIT');

    console.log('\n✓ Reset complete.');
    console.log(`  Admin(s) preserved: ${admins.map(a => a.username).join(', ')}`);
    console.log('  Stores, product categories, and offer categories reseeded.');
    console.log('  All other data wiped.');
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
