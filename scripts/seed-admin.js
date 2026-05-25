'use strict';

/**
 * Seed script — creates the first admin user.
 *
 * Usage:
 *   node scripts/seed-admin.js
 *
 * Environment variables (from .env) must be set before running.
 */

const bcrypt = require('bcryptjs');
const { Pool } = require('pg');

// Load env manually (same logic as src/config/env.js)
try {
  require('fs').readFileSync('.env', 'utf8')
    .split('\n')
    .filter(line => line && !line.startsWith('#'))
    .forEach(line => {
      const [key, ...rest] = line.split('=');
      if (key && rest.length && !process.env[key.trim()]) {
        process.env[key.trim()] = rest.join('=').trim();
      }
    });
} catch { /* .env optional */ }

const ADMIN_USERNAME  = process.env.ADMIN_USERNAME  || 'admin';
const ADMIN_PASSWORD  = process.env.ADMIN_PASSWORD  || 'admin123';
const ADMIN_FULL_NAME = process.env.ADMIN_FULL_NAME || 'System Administrator';
const BCRYPT_ROUNDS   = parseInt(process.env.BCRYPT_ROUNDS || '12', 10);

const pool = new Pool({
  host:     process.env.DB_HOST,
  port:     parseInt(process.env.DB_PORT || '5432', 10),
  database: process.env.DB_NAME,
  user:     process.env.DB_USER,
  password: process.env.DB_PASSWORD,
});

async function seed() {
  console.log(`Seeding admin user: "${ADMIN_USERNAME}"...`);

  const passwordHash = await bcrypt.hash(ADMIN_PASSWORD, BCRYPT_ROUNDS);

  const { rows } = await pool.query(
    `INSERT INTO users (username, password_hash, full_name, role, store_id)
     VALUES ($1, $2, $3, 'admin', NULL)
     ON CONFLICT (username) DO NOTHING
     RETURNING id, username, role`,
    [ADMIN_USERNAME.toLowerCase(), passwordHash, ADMIN_FULL_NAME]
  );

  if (rows.length === 0) {
    console.log(`Admin user "${ADMIN_USERNAME}" already exists. Skipping.`);
  } else {
    console.log(`Admin user created:`, rows[0]);
  }

  await pool.end();
  console.log('Done.');
}

seed().catch((err) => {
  console.error('Seed failed:', err.message);
  process.exit(1);
});
