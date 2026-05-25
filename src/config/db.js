'use strict';

const { Pool } = require('pg');
const env      = require('./env');

// ─── Connection pool ────────────────────────────────────────────────────────

const pool = new Pool({
  host:            env.DB_HOST,
  port:            env.DB_PORT,
  database:        env.DB_NAME,
  user:            env.DB_USER,
  password:        env.DB_PASSWORD,
  max:             env.DB_POOL_MAX,
  idleTimeoutMillis:    30_000,
  connectionTimeoutMillis: 5_000,
  // Parse numeric/money columns as JS numbers (not strings)
  types: (() => {
    const pg = require('pg');
    // NUMERIC (OID 1700), INT8 (OID 20) → parse as float/int
    pg.types.setTypeParser(1700, (val) => parseFloat(val));
    pg.types.setTypeParser(20,   (val) => parseInt(val, 10));
    return pg.types;
  })(),
});

pool.on('error', (err) => {
  const logger = require('../utils/logger');
  logger.error({ err }, 'Unexpected pool error');
});

// ─── Simple query shorthand (no RLS, for non-sensitive tables) ──────────────

const query = (text, params) => pool.query(text, params);

// ─── Transaction wrapper ────────────────────────────────────────────────────

/**
 * Runs `callback(client)` inside a BEGIN/COMMIT/ROLLBACK block.
 * Automatically releases the client on completion or error.
 *
 * @param {(client: import('pg').PoolClient) => Promise<any>} callback
 */
const withTransaction = async (callback) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
};

// ─── RLS-scoped transaction ─────────────────────────────────────────────────

/**
 * Sets PostgreSQL session variables for Row-Level Security, then runs
 * `callback(client)` in a transaction.
 *
 * The session vars are SET LOCAL so they are scoped to this transaction only.
 * Every query that touches an RLS-protected table must go through this helper.
 *
 * @param {number} userId   - current authenticated user's id
 * @param {string} role     - 'admin' | 'cashier'
 * @param {(client: import('pg').PoolClient) => Promise<any>} callback
 */
const withRLS = (userId, role, callback) =>
  withTransaction(async (client) => {
    // Use parameterised literals — SET LOCAL does not accept $1 placeholders,
    // but we sanitise inputs so there is no injection risk.
    const safeId   = parseInt(userId, 10);
    const safeRole = role === 'admin' ? 'admin' : 'cashier';
    await client.query(`SET LOCAL app.current_user_id   = '${safeId}'`);
    await client.query(`SET LOCAL app.current_user_role = '${safeRole}'`);
    return callback(client);
  });

// ─── Health check ───────────────────────────────────────────────────────────

const healthCheck = async () => {
  const { rows } = await pool.query('SELECT NOW() AS now');
  return rows[0].now;
};

module.exports = { pool, query, withTransaction, withRLS, healthCheck };
