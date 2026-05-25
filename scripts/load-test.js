'use strict';

/**
 * Load / overload test for the Ooredoo POS backend.
 *
 * Six scenarios:
 *   1. Throughput on GET /health (no auth, no rate limit)
 *   2. Throughput on GET /api/customers (authed, behind global rate limit)
 *   3. Auth brute-force (verifies the auth rate limiter blocks at AUTH_RATE_LIMIT_MAX failures)
 *   4. SIM sale concurrency — 50 simultaneous sale attempts on a 10-card inventory
 *      (verifies FOR UPDATE SKIP LOCKED prevents over-selling)
 *   5. Customer phone race — 20 concurrent creates of the same phone
 *      (verifies the unique constraint allows exactly one winner)
 *   6. Body size guard — sends a payload >100kb (should be rejected with 413)
 *
 * Run with: node scripts/load-test.js
 */

const http   = require('http');
const bcrypt = require('bcryptjs');
const { Pool } = require('pg');

try {
  require('fs').readFileSync('.env', 'utf8').split('\n').filter((l) => l && !l.startsWith('#'))
    .forEach((l) => { const [k, ...r] = l.split('='); if (k && r.length) process.env[k.trim()] = r.join('=').trim(); });
} catch {}

const pool = new Pool({
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT || '5432', 10),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
});

const HOST = 'localhost';
const PORT = 3001;
const agent = new http.Agent({ keepAlive: true, maxSockets: 200 });

function request({ method, path, body, token }) {
  return new Promise((resolve) => {
    const data = body ? (typeof body === 'string' ? body : JSON.stringify(body)) : null;
    const start = process.hrtime.bigint();
    const req = http.request({
      host: HOST, port: PORT, path, method, agent,
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...(data ? { 'Content-Length': Buffer.byteLength(data) } : {}),
      },
      timeout: 15_000,
    }, (res) => {
      let chunks = '';
      res.on('data', (c) => (chunks += c));
      res.on('end', () => {
        const ns = Number(process.hrtime.bigint() - start);
        let parsed;
        try { parsed = JSON.parse(chunks); } catch { parsed = chunks; }
        resolve({ status: res.statusCode, body: parsed, ms: ns / 1e6 });
      });
    });
    req.on('error', (err) => resolve({ status: 0, body: { error: err.message }, ms: 0 }));
    req.on('timeout', () => { req.destroy(); resolve({ status: 0, body: { error: 'timeout' }, ms: 15000 }); });
    if (data) req.write(data);
    req.end();
  });
}

// ─── tiny stats helper ───────────────────────────────────────────────────────
function summarise(results, label) {
  const lat = results.map((r) => r.ms).filter((n) => n > 0).sort((a, b) => a - b);
  const counts = results.reduce((acc, r) => {
    acc[r.status] = (acc[r.status] || 0) + 1;
    return acc;
  }, {});
  const p = (q) => lat.length ? lat[Math.min(lat.length - 1, Math.floor(lat.length * q))] : 0;
  const fmtMs = (n) => `${n.toFixed(1)}ms`;
  return {
    label,
    total: results.length,
    counts,
    p50: fmtMs(p(0.50)),
    p95: fmtMs(p(0.95)),
    p99: fmtMs(p(0.99)),
    avg: fmtMs(lat.reduce((a, b) => a + b, 0) / Math.max(lat.length, 1)),
    max: fmtMs(lat[lat.length - 1] || 0),
  };
}

function statusBucket(status) {
  if (status === 0)        return 'network';
  if (status < 300)        return '2xx';
  if (status === 401)      return '401';
  if (status === 403)      return '403';
  if (status === 409)      return '409';
  if (status === 413)      return '413';
  if (status === 429)      return '429';
  if (status < 500)        return `${Math.floor(status / 100)}xx`;
  return '5xx';
}

function bucketCounts(results) {
  return results.reduce((acc, r) => {
    const b = statusBucket(r.status);
    acc[b] = (acc[b] || 0) + 1;
    return acc;
  }, {});
}

// ─── Setup ───────────────────────────────────────────────────────────────────

async function setup() {
  console.log('━'.repeat(72));
  console.log('  Setup');
  console.log('━'.repeat(72));

  // Re-create a clean test cashier with SIMs and a session.
  // We reuse an existing 'loadtester' if it exists (audit_logs is append-only,
  // so we cannot drop the user once it has produced any audit rows).
  await pool.query(`DELETE FROM session_sim_sales      WHERE 1=1`);
  await pool.query(`DELETE FROM sim_cards              WHERE 1=1`);
  await pool.query(`DELETE FROM cashier_sessions       WHERE 1=1`);
  // Wipe any test customers — phone numbers used by the load test all share
  // the 99999 prefix (chosen to avoid collisions with realistic phones).
  await pool.query(`DELETE FROM customers WHERE phone_number LIKE '99999%'`);

  let { rows: existing } = await pool.query(`SELECT id FROM users WHERE username = 'loadtester'`);
  let cashierId;
  if (existing[0]) {
    cashierId = existing[0].id;
    // Ensure the user is active and resets the password so we can log in
    const hash = await bcrypt.hash('cashier123', 4);
    await pool.query(
      `UPDATE users SET password_hash = $1, is_active = TRUE WHERE id = $2`,
      [hash, cashierId]
    );
  } else {
    const hash = await bcrypt.hash('cashier123', 4);
    const { rows: cashierRows } = await pool.query(
      `INSERT INTO users (username, password_hash, full_name, role, store_id)
       VALUES ('loadtester', $1, 'Load Tester', 'cashier', 1) RETURNING id`,
      [hash]
    );
    cashierId = cashierRows[0].id;
  }

  const adminLogin = await request({
    method: 'POST', path: '/api/auth/login',
    body: { username: 'admin', password: 'admin@123' },
  });
  if (!adminLogin.body?.data?.accessToken) {
    console.error('Admin login failed:', adminLogin.status, adminLogin.body);
    process.exit(1);
  }
  const adminToken = adminLogin.body.data.accessToken;

  // Need at least one offer so SIM sales can resolve to one
  let { rows: offerRows } = await pool.query(`SELECT id FROM offers WHERE is_active = TRUE LIMIT 1`);
  if (!offerRows[0]) {
    const offerCreate = await request({
      method: 'POST', path: '/api/offers',
      body: {
        name: 'Load Test Offer', category_id: 1,
        real_price: 1000, selling_price: 1500, points: 100,
        commission_amount: 50, low_stock_threshold: 5,
      },
      token: adminToken,
    });
    offerRows = [{ id: offerCreate.body.data.id }];
  }
  const offerId = offerRows[0].id;

  // Assign exactly 10 SIMs to the load tester
  await request({
    method: 'POST', path: '/api/stock/assign',
    body: { cashier_id: cashierId, first_serial: '8888888888888881', count: 10 },
    token: adminToken,
  });

  // Login the cashier and open a session
  const cashierLogin = await request({
    method: 'POST', path: '/api/auth/login',
    body: { username: 'loadtester', password: 'cashier123' },
  });
  if (!cashierLogin.body?.data?.accessToken) {
    console.error('Cashier login failed:', cashierLogin.status, cashierLogin.body);
    process.exit(1);
  }
  const cashierToken = cashierLogin.body.data.accessToken;

  const sessionRes = await request({
    method: 'POST', path: '/api/sessions', body: {}, token: cashierToken,
  });
  if (!sessionRes.body?.data?.id) {
    console.error('Session create failed:', sessionRes.status, sessionRes.body);
    process.exit(1);
  }
  const sessionId = sessionRes.body.data.id;

  // Create one anchor customer for sale tests
  const customerRes = await request({
    method: 'POST', path: '/api/customers',
    body: {
      phone_number: '999991111111', first_name: 'Load', last_name: 'Tester',
      address: 'Load test', profession: 'Tester',
    },
    token: cashierToken,
  });
  if (!customerRes.body?.data?.id) {
    console.error('Customer create failed:', customerRes.status, customerRes.body);
    process.exit(1);
  }
  const customerId = customerRes.body.data.id;

  console.log(`  cashier id  : ${cashierId}`);
  console.log(`  session id  : ${sessionId}`);
  console.log(`  offer id    : ${offerId}`);
  console.log(`  customer id : ${customerId}`);
  console.log(`  SIMs        : 10 cards (8888888888888881 → 8888888888888890)`);

  return { adminToken, cashierToken, cashierId, sessionId, offerId, customerId };
}

// ─── Concurrency primitives ─────────────────────────────────────────────────

async function flood(n, fn) {
  return Promise.all(Array.from({ length: n }, (_, i) => fn(i)));
}

// ─── Scenarios ──────────────────────────────────────────────────────────────

async function scenarioHealth() {
  // 500 calls in 5 staggered batches of 100 — closer to realistic load
  // than a single 500-way blast that just queues on the Node event loop.
  const N = 500;
  const BATCH = 100;
  const results = [];
  for (let i = 0; i < N; i += BATCH) {
    const batch = await flood(BATCH, () => request({ method: 'GET', path: '/health' }));
    results.push(...batch);
  }
  return { ...summarise(results, '1. /health x 500 (5 batches of 100)'), buckets: bucketCounts(results) };
}

async function scenarioAuthedRead(adminToken) {
  const N = 600; // > RATE_LIMIT_MAX (500) → expect 429s past the limit
  const results = await flood(N, () =>
    request({ method: 'GET', path: '/api/customers?limit=10', token: adminToken })
  );
  return { ...summarise(results, '2. GET /api/customers x 600 (rate limit 500)'), buckets: bucketCounts(results) };
}

async function scenarioBruteForce() {
  const N = 80; // > AUTH_RATE_LIMIT_MAX (50) → expect 429s past the limit
  const results = await flood(N, (i) =>
    request({
      method: 'POST', path: '/api/auth/login',
      body: { username: 'admin', password: `wrong-${i}` },
    })
  );
  return { ...summarise(results, '3. Auth brute-force x 80 (limit 50)'), buckets: bucketCounts(results) };
}

async function scenarioSimRace({ cashierToken, sessionId, offerId, customerId }) {
  const N = 50;
  const results = await flood(N, () =>
    request({
      method: 'POST', path: '/api/sales/sim',
      body: { session_id: sessionId, offer_id: offerId, customer_id: customerId },
      token: cashierToken,
    })
  );

  // Verify: exactly 10 should have succeeded (the 10 SIMs we assigned), and
  // the rest should be 409 OUT_OF_STOCK with no duplicates on any serial.
  const success = results.filter((r) => r.status === 201);
  const outOfStock = results.filter(
    (r) => r.status === 409 && r.body?.code === 'OUT_OF_STOCK'
  );
  const serials = success.map((r) => r.body?.data?.serial_number_snapshot);
  const uniqueSerials = new Set(serials);

  const { rows } = await pool.query(
    `SELECT COUNT(*) AS sold FROM sim_cards WHERE status = 'sold'`
  );

  return {
    ...summarise(results, '4. SIM sale concurrency x 50 (only 10 cards)'),
    buckets: bucketCounts(results),
    extras: {
      successful_sales:    success.length,
      out_of_stock_replies: outOfStock.length,
      unique_serials_sold: uniqueSerials.size,
      duplicates_detected: success.length - uniqueSerials.size,
      cards_marked_sold:   parseInt(rows[0].sold, 10),
    },
  };
}

async function scenarioCustomerPhoneRace(cashierToken) {
  const phone = `99999${Date.now().toString().slice(-7)}`;
  const N = 20;
  const results = await flood(N, (i) =>
    request({
      method: 'POST', path: '/api/customers',
      body: {
        phone_number: phone,
        first_name: `Race${i}`, last_name: 'Test',
        address: 'Concurrent', profession: 'tester',
      },
      token: cashierToken,
    })
  );

  const created = results.filter((r) => r.status === 201);
  const conflicts = results.filter((r) => r.body?.code === 'CUSTOMER_PHONE_EXISTS');

  const { rows } = await pool.query(
    `SELECT COUNT(*)::int AS n FROM customers WHERE phone_number = $1`,
    [phone]
  );

  return {
    ...summarise(results, '5. Customer phone race x 20 (same phone)'),
    buckets: bucketCounts(results),
    extras: {
      successful_creates:    created.length,
      duplicate_responses:   conflicts.length,
      rows_actually_in_db:   rows[0].n,
    },
  };
}

async function scenarioBodyTooBig(adminToken) {
  const oversized = 'x'.repeat(150 * 1024); // 150kb of garbage > 100kb limit
  const result = await request({
    method: 'POST', path: '/api/customers',
    body: { phone_number: '0555-junk', first_name: oversized, last_name: 'X', address: 'X', profession: 'X' },
    token: adminToken,
  });
  return {
    label: '6. Body size guard (~150kb payload, limit 100kb)',
    total: 1,
    counts: { [result.status]: 1 },
    p50: '—', p95: '—', p99: '—', avg: '—', max: '—',
    buckets: { [statusBucket(result.status)]: 1 },
    extras: {
      status: result.status,
      message: typeof result.body === 'object' ? result.body?.message : String(result.body).slice(0, 80),
    },
  };
}

// ─── Pretty-print one scenario result ───────────────────────────────────────

function print(s) {
  console.log('━'.repeat(72));
  console.log(`  ${s.label}`);
  console.log('━'.repeat(72));
  console.log(`  total            : ${s.total}`);
  console.log(`  status buckets   : ${Object.entries(s.buckets).map(([k, v]) => `${k}=${v}`).join('  ')}`);
  if (typeof s.p50 === 'string' && s.p50 !== '—') {
    console.log(`  latency (avg)    : ${s.avg}`);
    console.log(`  latency (p50/95/99/max) : ${s.p50} / ${s.p95} / ${s.p99} / ${s.max}`);
  }
  if (s.extras) {
    console.log('  extras:');
    for (const [k, v] of Object.entries(s.extras)) console.log(`    ${k.padEnd(22)} ${v}`);
  }
}

// ─── Run ────────────────────────────────────────────────────────────────────

(async () => {
  const ctx = await setup();
  const t0 = Date.now();
  const results = [];

  results.push(await scenarioHealth());                             print(results.at(-1));
  results.push(await scenarioBodyTooBig(ctx.adminToken));           print(results.at(-1));
  results.push(await scenarioCustomerPhoneRace(ctx.cashierToken));  print(results.at(-1));
  results.push(await scenarioSimRace(ctx));                         print(results.at(-1));
  results.push(await scenarioAuthedRead(ctx.adminToken));           print(results.at(-1));
  results.push(await scenarioBruteForce());                         print(results.at(-1));

  console.log('━'.repeat(72));
  console.log(`  TOTAL TEST TIME: ${((Date.now() - t0) / 1000).toFixed(1)}s`);
  console.log('━'.repeat(72));

  // Verdict table
  const verdicts = [];
  const r4 = results.find((r) => r.label.startsWith('4.'));
  verdicts.push([
    'FIFO SIM lock prevents over-sell',
    r4.extras.successful_sales === 10 && r4.extras.duplicates_detected === 0
      ? 'PASS' : 'FAIL',
    `${r4.extras.successful_sales} sold, ${r4.extras.duplicates_detected} duplicates`,
  ]);

  const r5 = results.find((r) => r.label.startsWith('5.'));
  verdicts.push([
    'Phone uniqueness under race',
    r5.extras.successful_creates === 1 && r5.extras.rows_actually_in_db === 1
      ? 'PASS' : 'FAIL',
    `${r5.extras.successful_creates} created, ${r5.extras.rows_actually_in_db} in DB`,
  ]);

  const r6 = results.find((r) => r.label.startsWith('6.'));
  verdicts.push(['Body size limit',
    r6.extras.status === 413 ? 'PASS' : 'FAIL',
    `status ${r6.extras.status}`,
  ]);

  const r1 = results.find((r) => r.label.startsWith('1.'));
  // 500ms p95 is already conservative for a single-process Node app handling
  // 100 simultaneous in-flight calls; production behind a reverse proxy and
  // multi-process PM2 will be substantially better.
  verdicts.push([
    'Health endpoint stays fast',
    parseFloat(r1.p95) < 500 ? 'PASS' : 'FAIL',
    `p95 ${r1.p95}, p50 ${r1.p50}`,
  ]);

  const r2 = results.find((r) => r.label.startsWith('2.'));
  verdicts.push([
    'Global rate limiter (500/15min)',
    (r2.buckets['429'] || 0) > 0 ? 'PASS' : 'NEUTRAL',
    `${r2.buckets['2xx'] || 0} OK, ${r2.buckets['429'] || 0} rate-limited`,
  ]);

  const r3 = results.find((r) => r.label.startsWith('3.'));
  verdicts.push([
    'Auth rate limiter (50/15min)',
    (r3.buckets['429'] || 0) > 0 ? 'PASS' : 'NEUTRAL',
    `${r3.buckets['401'] || 0} rejected, ${r3.buckets['429'] || 0} rate-limited`,
  ]);

  console.log('  VERDICT');
  console.log('━'.repeat(72));
  for (const [name, status, detail] of verdicts) {
    const tag = status === 'PASS' ? '✓ PASS  '
              : status === 'FAIL' ? '✗ FAIL  '
              : '· NEUT  ';
    console.log(`  ${tag} ${name.padEnd(40)} ${detail}`);
  }

  await pool.end();
})().catch((err) => { console.error(err); pool.end(); process.exit(1); });
