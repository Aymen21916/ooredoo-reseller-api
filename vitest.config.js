'use strict';

/**
 * Vitest configuration for the pos-financial-tracking-extensions integration
 * suite. Existing unit tests under `__tests__/` continue to run on Jest via
 * `npm test`; this config governs the DB-backed property and integration tests
 * that live under `tests/integration/`.
 *
 * Run with: `npm run test:integration`
 *
 * Requirements: testing infrastructure for Requirements 1, 2, 3, 4.
 */

const { defineConfig } = require('vitest/config');

module.exports = defineConfig({
  test: {
    // Inject describe / it / expect / beforeEach / beforeAll / afterAll as
    // globals. This lets our CommonJS setup and test files avoid `require('vitest')`,
    // which is impossible because Vitest 4.x ships ESM-only.
    globals: true,

    // Only the new DB-backed suite. Jest still owns __tests__/.
    include: ['tests/integration/**/*.test.js'],
    exclude: ['node_modules/**', 'ooredoo-pos-client/**'],

    // The shared setup connects to the test DB, registers the beforeEach
    // truncate hook, and prints the fast-check seed for CI reproducibility.
    setupFiles: ['./tests/integration/setup.js'],

    // Property tests with a shared, mutable database cannot run in parallel
    // without invalidating each iteration's `beforeEach` truncate. Force a
    // single fork (the Vitest equivalent of `jest --runInBand`).
    pool: 'forks',
    fileParallelism: false,

    // Property tests can be slower than typical unit tests; give them headroom.
    testTimeout: 30_000,
    hookTimeout: 30_000,

    // Print individual test names + console.log output (where the seed banner
    // lives) in CI so the seed shows up in GitHub Actions logs.
    reporters: process.env.CI ? ['default', 'github-actions'] : ['default'],
  },
});
