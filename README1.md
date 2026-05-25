# Ooredoo Reseller API — Deployment Readiness Checklist

This document lists everything that needs to be done, added, or changed before this project can be safely deployed to production.

---

## 1. Critical Issues (Must Fix)

### 1.1 `.env` file is committed with real secrets

Your `.env` file contains actual JWT secrets and database credentials. This should **never** be in the repo.

**Fix:**
- Add a `.gitignore` at the repo root with at least:
  ```
  node_modules/
  .env
  coverage/
  ```
- Remove `.env` from git history (`git rm --cached .env`)
- Populate `.env.example` with placeholder values so new developers know what to fill in

---

### 1.2 `reportsController.js` has SQL bugs

The `generateDailyReport` function queries columns that don't exist in your schema:

- `SELECT balance, bonus, points FROM global_pool_state` — the actual columns are `available_balance`, `available_bonus`, `available_points`
- `SELECT current_cash FROM stores WHERE id = $1` — `stores` has no `current_cash` column; you need to query `store_register_state`

**Fix:** Rewrite those queries to match the actual schema:
```js
// Global pool
const { rows: poolRows } = await client.query(
  `SELECT available_balance, available_bonus, available_points 
   FROM global_pool_state ORDER BY id DESC LIMIT 1`
);

// Store register
const { rows: registerRows } = await client.query(
  `SELECT cash_amount FROM store_register_state 
   WHERE store_id = $1 ORDER BY id DESC LIMIT 1`, [storeId]
);
```

---

### 1.3 `voidTransaction` has SQL injection vulnerability

The `voidTransaction` function in `salesController.js` interpolates `type` into a table name without proper validation:

```js
await db.query(`UPDATE ${table} SET is_voided = TRUE WHERE id = $1`, [id]);
```

While there's a basic check, it also:
- Doesn't verify the transaction belongs to the cashier's session
- Doesn't set `voided_at`, `voided_by`, or `void_reason`
- Doesn't audit the void action

**Fix:** Add ownership check, set all void columns, and log the audit:
```js
const voidTransaction = asyncHandler(async (req, res) => {
  const { type, id } = req.params;
  const tableMap = {
    sim: 'session_sim_sales',
    storm: 'session_storm_entries',
    accessory: 'session_accessory_sales',
    debt: 'session_debts',
  };
  const table = tableMap[type];
  if (!table) throw AppError.badRequest('Invalid transaction type.');

  const reason = req.body.reason || null;

  // Verify ownership via session
  const { rows } = await db.query(
    `SELECT t.id, t.session_id, cs.cashier_id
     FROM ${table} t
     JOIN cashier_sessions cs ON cs.id = t.session_id
     WHERE t.id = $1 AND t.is_voided = FALSE`, [id]
  );
  if (!rows[0]) throw AppError.notFound('Transaction not found or already voided.');
  if (rows[0].cashier_id !== req.user.id) throw AppError.forbidden('Not your transaction.');

  await db.query(
    `UPDATE ${table} SET is_voided = TRUE, voided_at = NOW(), voided_by = $1, void_reason = $2
     WHERE id = $3`, [req.user.id, reason, id]
  );

  audit({ userId: req.user.id, action: 'VOID', table, recordId: parseInt(id), ip: req.clientIp });
  sendSuccess(res, null, 200, 'Transaction voided.');
});
```

---

### 1.4 `getLiveSessions` has SQL injection

In `sessionsController.js`:
```js
const storeFilter = req.query.store_id
  ? `AND cs.store_id = ${parseInt(req.query.store_id, 10)}`
  : '';
```

Even though `parseInt` is used, string interpolation into SQL is a bad pattern. Use parameterized queries.

---

### 1.5 Frontend API base URL is hardcoded

`ooredoo-pos-client/src/api/axios.js` has:
```js
baseURL: 'http://localhost:3001/api',
```

And the refresh interceptor also hardcodes `http://localhost:3001/api/auth/refresh`.

**Fix:** Use a Vite environment variable:
```js
baseURL: import.meta.env.VITE_API_URL || 'http://localhost:3001/api',
```

Create `ooredoo-pos-client/.env.production`:
```
VITE_API_URL=https://your-production-domain.com/api
```

---

## 2. Missing Infrastructure (Must Add)

### 2.1 No `.gitignore` at the repo root

You have no root `.gitignore`. Add one:
```
node_modules/
.env
coverage/
dist/
*.log
```

---

### 2.2 No process manager or Dockerfile

The server runs with `node src/server.js` — if it crashes, nothing restarts it.

**Options (pick one):**
- **PM2** (simplest for VPS): `pm2 start src/server.js --name ooredoo-api -i 2`
- **Docker** (recommended for cloud):
  ```dockerfile
  FROM node:18-alpine
  WORKDIR /app
  COPY package*.json ./
  RUN npm ci --omit=dev
  COPY src/ ./src/
  EXPOSE 3001
  CMD ["node", "src/server.js"]
  ```
- **systemd** service file if deploying on a bare Linux server

---

### 2.3 No production logging

The project uses `console.log` / `console.error` everywhere. In production you need structured, leveled logging.

**Recommendation:** Add `pino` (fast, JSON-structured):
```bash
npm install pino
```
Replace `console.log/error` with a logger instance. This gives you:
- JSON output for log aggregation (CloudWatch, Datadog, etc.)
- Log levels (info, warn, error)
- Request ID correlation

---

### 2.4 No graceful shutdown

If the server receives SIGTERM (container stop, deploy), it currently drops all in-flight requests and doesn't drain the DB pool.

**Fix:** Add to `server.js`:
```js
process.on('SIGTERM', async () => {
  console.log('[SERVER] SIGTERM received. Shutting down gracefully...');
  server.close(() => {
    pool.end().then(() => process.exit(0));
  });
  setTimeout(() => process.exit(1), 10_000); // force kill after 10s
});
```

---

### 2.5 No database migration strategy

You have a single `schema.sql` file. When you need to change the schema in production (add a column, alter a type), you can't just re-run the whole file.

**Recommendation:** Use a migration tool:
- `node-pg-migrate` (lightweight, SQL-based)
- `knex` migrations
- `dbmate` (language-agnostic)

---

### 2.6 No admin seed script

There's no way to create the first admin user without manually running SQL. You need a seed script:
```bash
node scripts/seed-admin.js
```
That hashes a password and inserts the admin row.

---

### 2.7 No HTTPS / TLS

The Express server only listens on HTTP. In production, you need TLS.

**Options:**
- Put a reverse proxy in front (Nginx, Caddy, or a cloud load balancer) that terminates TLS
- If using a PaaS (Railway, Render, Fly.io), they handle TLS for you

Also set `app.set('trust proxy', 1)` in `server.js` so `express-rate-limit` and `req.ip` work correctly behind a proxy.

---

### 2.8 No frontend build/deploy pipeline

The React app needs to be built (`npm run build`) and the resulting `dist/` folder served by a static host (Nginx, Vercel, Netlify, S3+CloudFront, etc.).

There's no CI/CD config (GitHub Actions, GitLab CI, etc.) to automate this.

---

## 3. Security Hardening (Should Fix)

### 3.1 No request body size limit

Express `json()` has no explicit limit. A malicious client could send a huge payload and exhaust memory.

**Fix:**
```js
app.use(express.json({ limit: '100kb' }));
```

---

### 3.2 No auth-specific rate limiter

`env.js` defines `AUTH_RATE_LIMIT_MAX` but it's never used in `server.js` or `authRoutes.js`. The login endpoint uses the same global 200-req/15min limit as everything else.

**Fix:** Add a stricter limiter to auth routes:
```js
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: env.AUTH_RATE_LIMIT_MAX, // 10
  message: 'Too many login attempts.',
});
app.use('/api/auth', authLimiter);
```

---

### 3.3 No expired refresh token cleanup

`refresh_tokens` rows accumulate forever. Expired/revoked tokens are never deleted.

**Fix:** Add a scheduled job (cron or `setInterval`) that runs:
```sql
DELETE FROM refresh_tokens WHERE expires_at < NOW() - INTERVAL '7 days';
```

---

### 3.4 No input sanitization on `note` / `description` fields

Free-text fields like `session_storm_entries.note` and `session_debts.description` are stored as-is. While parameterized queries prevent SQL injection, you should still trim and limit length to prevent abuse.

---

### 3.5 `helmet()` defaults are good but consider adding CSP

If you ever serve the frontend from the same origin, add a Content-Security-Policy header. For an API-only server, the defaults are fine.

---

## 4. Reliability & Observability (Should Add)

### 4.1 No health check for the frontend

The backend has `GET /health`. The frontend has nothing. Add a simple health route or rely on the hosting platform's built-in checks.

---

### 4.2 No request logging middleware

You have no visibility into what requests hit the server, response times, or status codes.

**Recommendation:** Add `pino-http` or `morgan`:
```js
const pino = require('pino-http')();
app.use(pino);
```

---

### 4.3 No error alerting

When the server throws a 500, nobody is notified. Consider integrating Sentry, Datadog, or at minimum sending errors to a log file that's monitored.

---

### 4.4 No database connection retry on startup

If PostgreSQL is slow to start (common in containers), the server crashes immediately. Add a retry loop:
```js
const startServer = async (retries = 5) => {
  for (let i = 0; i < retries; i++) {
    try {
      await pool.query('SELECT 1');
      break;
    } catch (err) {
      if (i === retries - 1) throw err;
      await new Promise(r => setTimeout(r, 2000));
    }
  }
  // ...start listening
};
```

---

## 5. Frontend Production Concerns

### 5.1 No loading/error states on some pages

Verify that all pages handle:
- Network errors (API down)
- Empty states (no data yet)
- Loading spinners during fetches

---

### 5.2 No `<title>` or meta tags per page

The SPA has a single `index.html` title. For a POS system this is minor, but good practice.

---

### 5.3 No service worker or offline handling

If the network drops mid-shift, the cashier loses everything. Consider:
- Queuing failed requests in localStorage and retrying
- Showing a clear "offline" banner

---

## 6. Deployment Checklist Summary

| # | Item | Priority | Status |
|---|------|----------|--------|
| 1 | Remove `.env` from repo, add `.gitignore` | 🔴 Critical | ❌ |
| 2 | Fix `reportsController` SQL bugs | 🔴 Critical | ❌ |
| 3 | Fix `voidTransaction` security + completeness | 🔴 Critical | ❌ |
| 4 | Fix `getLiveSessions` SQL interpolation | 🔴 Critical | ❌ |
| 5 | Make frontend API URL configurable | 🔴 Critical | ❌ |
| 6 | Add process manager or Docker | 🟠 High | ❌ |
| 7 | Add structured logging (pino) | 🟠 High | ❌ |
| 8 | Add graceful shutdown | 🟠 High | ❌ |
| 9 | Add DB migration tool | 🟠 High | ❌ |
| 10 | Add admin seed script | 🟠 High | ❌ |
| 11 | Set up TLS (reverse proxy) | 🟠 High | ❌ |
| 12 | Add `trust proxy` setting | 🟠 High | ❌ |
| 13 | Add CI/CD pipeline | 🟠 High | ❌ |
| 14 | Limit `express.json()` body size | 🟡 Medium | ❌ |
| 15 | Wire up `AUTH_RATE_LIMIT_MAX` on auth routes | 🟡 Medium | ❌ |
| 16 | Add refresh token cleanup job | 🟡 Medium | ❌ |
| 17 | Add request logging middleware | 🟡 Medium | ❌ |
| 18 | Add DB connection retry on startup | 🟡 Medium | ❌ |
| 19 | Add error alerting (Sentry, etc.) | 🟡 Medium | ❌ |
| 20 | Validate/limit free-text input lengths | 🟢 Low | ❌ |
| 21 | Add offline handling for frontend | 🟢 Low | ❌ |

---

## Quick Start (Current State — Development Only)

```bash
# Backend
npm install
cp .env.example .env  # fill in values
psql -d your_db -f database/schema.sql
npm run dev

# Frontend
cd ooredoo-pos-client
npm install
npm run dev
```

---

## Recommended Production Architecture

```
┌─────────────┐       ┌──────────────┐       ┌────────────────┐
│   Browser   │──TLS──│  Nginx/Caddy │──HTTP──│  Node.js API   │
│  (React SPA)│       │  (reverse    │       │  (PM2 or Docker)│
└─────────────┘       │   proxy)     │       └───────┬────────┘
                      └──────────────┘               │
                             │                       │
                      Serves static                  │
                      dist/ files              ┌─────▼─────┐
                                               │ PostgreSQL │
                                               │   15+      │
                                               └────────────┘
```

The reverse proxy handles TLS termination, serves the built React app as static files, and forwards `/api/*` requests to the Node.js backend.
