/* eslint-disable camelcase */

'use strict';

const fs   = require('fs');
const path = require('path');

/**
 * Baseline migration — applies the full initial schema from database/schema.sql.
 *
 * This is intended to be run exactly once on a fresh database. On existing
 * databases that already have the schema applied, mark this migration as
 * executed manually in the `pgmigrations` table instead of running it.
 */

exports.shorthands = undefined;

exports.up = (pgm) => {
  const sql = fs.readFileSync(
    path.join(__dirname, '..', 'database', 'schema.sql'),
    'utf8'
  );
  pgm.sql(sql);
};

exports.down = (pgm) => {
  // Drop everything in reverse dependency order.
  pgm.sql(`
    DROP VIEW IF EXISTS v_monthly_summary;
    DROP VIEW IF EXISTS v_current_register;
    DROP VIEW IF EXISTS v_current_pool;
    DROP VIEW IF EXISTS v_sim_stock_remaining;
    DROP VIEW IF EXISTS v_session_live_totals;

    DROP TABLE IF EXISTS audit_logs CASCADE;
    DROP TABLE IF EXISTS daily_reports CASCADE;
    DROP TABLE IF EXISTS store_register_state CASCADE;
    DROP TABLE IF EXISTS global_pool_state CASCADE;
    DROP TABLE IF EXISTS session_debts CASCADE;
    DROP TABLE IF EXISTS session_accessory_sales CASCADE;
    DROP TABLE IF EXISTS session_storm_entries CASCADE;
    DROP TABLE IF EXISTS session_sim_sales CASCADE;
    DROP TABLE IF EXISTS sim_stock_assignments CASCADE;
    DROP TABLE IF EXISTS cashier_sessions CASCADE;
    DROP TABLE IF EXISTS products CASCADE;
    DROP TABLE IF EXISTS product_categories CASCADE;
    DROP TABLE IF EXISTS offers CASCADE;
    DROP TABLE IF EXISTS refresh_tokens CASCADE;
    DROP TABLE IF EXISTS users CASCADE;
    DROP TABLE IF EXISTS stores CASCADE;

    DROP TYPE IF EXISTS audit_action;
    DROP TYPE IF EXISTS session_status;
    DROP TYPE IF EXISTS user_role;
  `);
};
