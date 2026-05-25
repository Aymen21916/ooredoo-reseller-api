'use strict';

/**
 * Smoke test for the integration-test scaffolding itself.
 *
 * Verifies that `tests/integration/setup.js`:
 *   - exposes the documented exports,
 *   - configures fast-check with a deterministic seed,
 *   - truncates the financial tables that already exist (the helper is a
 *     no-op for any table that has not been migrated yet, which is fine until
 *     task 1.1 lands).
 *
 * The `pool.query('SELECT 1')` call inside `beforeAll` already provides the
 * "we can reach the test DB" assertion; this file documents the contract.
 *
 * Vitest globals are injected via `globals: true` in vitest.config.js — Vitest 4.x
 * ships ESM-only and cannot be required() from these CJS files.
 *
 * Requirements: testing infrastructure for Requirements 1, 2, 3, 4.
 */

/* global describe, it, expect */

const fc = require('fast-check');
const {
  pool,
  truncateFinancialTables,
  fastCheckSeed,
  FINANCIAL_TABLES,
} = require('./setup');

describe('integration test scaffolding', () => {
  it('exports a connected pg pool', async () => {
    const { rows } = await pool.query('SELECT 1 AS one');
    expect(rows[0].one).toBe(1);
  });

  it('exposes the canonical financial table list', () => {
    expect(FINANCIAL_TABLES).toEqual([
      'audit_logs',
      'session_debts',
      'cashier_advances',
      'register_expenses',
      'store_register_state',
    ]);
  });

  it('truncateFinancialTables() runs without error against the live test DB', async () => {
    await expect(truncateFinancialTables()).resolves.toBeUndefined();
  });

  it('fast-check global config picks up the captured seed', () => {
    const cfg = fc.readConfigureGlobal();
    expect(cfg.seed).toBe(fastCheckSeed);
  });
});
