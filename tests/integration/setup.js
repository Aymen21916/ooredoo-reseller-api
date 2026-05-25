'use strict';

/**
 * Integration test scaffolding for the pos-financial-tracking-extensions feature.
 *
 * Responsibilities:
 *   1. Connect to a dedicated PostgreSQL test database. The container itself
 *      is the Postgres instance from the project's existing `docker-compose.yml`,
 *      reachable on `localhost:5432` (or whatever the env vars override). The
 *      database NAME defaults to `ooredoo_test` so it is impossible to truncate
 *      a developer's working schema by accident.
 *   2. Expose `truncateFinancialTables()`, the canonical reset for every PBT
 *      iteration, covering the new and existing tables that financial properties
 *      will mutate.
 *   3. Register a Vitest `beforeEach` hook so every test (and every fast-check
 *      iteration that uses `beforeEach.concurrent: false`) starts from a clean slate.
 *   4. Seed and log the fast-check global seed so CI runs are reproducible.
 *
 * This file is wired in via `vitest.config.js -> test.setupFiles`.
 *
 * Requirements: testing infrastructure for Requirements 1, 2, 3, 4.
 */

const { Pool } = require('pg');
const fc       = require('fast-check');

// Vitest 4.x is ESM-only. We cannot `require('vitest')` from this CJS file, so
// we rely on `globals: true` in `vitest.config.js` which injects beforeAll /
// beforeEach / afterAll as globals at test-runtime.
/* global beforeAll, beforeEach, afterAll */

// ── 1. Pool ─────────────────────────────────────────────────────────────────
//
// Use a dedicated env var (TEST_DB_NAME / TEST_DB_HOST / …) when present, then
// fall back to the standard DB_* values, then to a hardcoded `ooredoo_test`
// default. We REFUSE to connect to a database whose name is the production-
// oriented `ooredoo_reseller`: integration tests truncate tables, so pointing
// them at the dev DB would be destructive.

const dbName = process.env.TEST_DB_NAME || process.env.DB_NAME || 'ooredoo_test';

if (dbName === 'ooredoo_reseller') {
  throw new Error(
    `Refusing to run integration tests against database "${dbName}" — ` +
    `set TEST_DB_NAME (or DB_NAME) to a dedicated test database such as ooredoo_test.`,
  );
}

const pool = new Pool({
  host:     process.env.TEST_DB_HOST     || process.env.DB_HOST     || 'localhost',
  port:     parseInt(process.env.TEST_DB_PORT || process.env.DB_PORT || '5432', 10),
  database: dbName,
  user:     process.env.TEST_DB_USER     || process.env.DB_USER     || 'postgres',
  password: process.env.TEST_DB_PASSWORD || process.env.DB_PASSWORD || 'postgres',
  max: 5,
  idleTimeoutMillis: 5_000,
  connectionTimeoutMillis: 5_000,
});

// ── 2. Truncate helper ──────────────────────────────────────────────────────
//
// The list intentionally covers:
//   - session_debts             (Requirement 1, debt rows)
//   - cashier_advances          (Requirement 2, advances/repayments — created by migration 1.1)
//   - register_expenses         (Requirement 3, expenses — created by migration 1.1)
//   - store_register_state      (Requirement 3, running register cash — needs reset
//                                because each expense appends a row)
//   - audit_logs                (Requirement 1.14/2.13/3.15/4.15 — every mutation writes here)
//
// `TRUNCATE ... RESTART IDENTITY CASCADE` resets sequences so generated ids are
// reproducible across iterations. Tables that may not yet exist (when this file
// is loaded against a database where migration 1.1 has not run) are silently
// skipped — that lets task 1.3 land before migration task 1.1.

const FINANCIAL_TABLES = [
  'audit_logs',
  'session_debts',
  'cashier_advances',
  'register_expenses',
  'store_register_state',
];

let availableTables = null;

const resolveAvailableTables = async () => {
  if (availableTables !== null) return availableTables;

  const { rows } = await pool.query(
    `SELECT tablename
       FROM pg_tables
      WHERE schemaname = 'public'
        AND tablename = ANY($1::text[])`,
    [FINANCIAL_TABLES],
  );
  availableTables = rows.map((r) => r.tablename);
  return availableTables;
};

const truncateFinancialTables = async () => {
  const tables = await resolveAvailableTables();
  if (tables.length === 0) return;

  // One statement keeps the operation atomic and lets PG resolve dependencies.
  const sql =
    `TRUNCATE TABLE ${tables.map((t) => `"${t}"`).join(', ')} ` +
    `RESTART IDENTITY CASCADE`;
  await pool.query(sql);
};

// ── 3. fast-check seed ──────────────────────────────────────────────────────
//
// fast-check picks a seed per run unless one is configured globally. We pin one
// here (from FAST_CHECK_SEED, or a fresh `Date.now()` value) and log it once at
// startup so any failing example printed by fast-check can be reproduced by
// re-running with the same `FAST_CHECK_SEED` env var.
//
// The log format is intentionally a single grep-friendly line so it shows up
// cleanly in GitHub Actions logs.

const fastCheckSeed = process.env.FAST_CHECK_SEED
  ? parseInt(process.env.FAST_CHECK_SEED, 10)
  : Date.now();

fc.configureGlobal({
  seed: fastCheckSeed,
  numRuns: parseInt(process.env.FAST_CHECK_NUM_RUNS || '100', 10),
});

// One-time banner. `console.log` (not pino) so the line appears verbatim in CI.
// Wrapped so multiple test files in the same run only print once.
if (!global.__POS_FIN_TEST_SEED_LOGGED__) {
  global.__POS_FIN_TEST_SEED_LOGGED__ = true;
  // eslint-disable-next-line no-console
  console.log(
    `[pos-financial-tracking-extensions] fast-check seed=${fastCheckSeed} ` +
    `db=${dbName} (set FAST_CHECK_SEED=${fastCheckSeed} to reproduce)`,
  );
}

// ── 4. Vitest hooks ─────────────────────────────────────────────────────────

beforeAll(async () => {
  // Probe the connection up-front so a misconfigured DB fails fast with a clear
  // message instead of after dozens of fast-check iterations.
  await pool.query('SELECT 1');
  await resolveAvailableTables();
});

beforeEach(async () => {
  await truncateFinancialTables();
});

afterAll(async () => {
  await pool.end();
});

// ── 5. Exports ──────────────────────────────────────────────────────────────

module.exports = {
  pool,
  truncateFinancialTables,
  fastCheckSeed,
  FINANCIAL_TABLES,
};
