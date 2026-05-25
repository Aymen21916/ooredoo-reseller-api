'use strict';

const db       = require('../config/db');
const AppError = require('../utils/AppError');
const { asyncHandler, sendSuccess, sendCreated } = require('../utils/asyncHandler');
const { audit }  = require('../utils/audit');
const { parseId, parsePositiveInt, parseDate } = require('../utils/validators');

// ─── Helpers ─────────────────────────────────────────────────────────────────

/** Resolve session and assert cashier ownership (or admin access). */
const resolveSession = async (sessionId, req, client) => {
  const db_ = client || db;
  const { rows } = await db_.query(
    `SELECT cs.*, u.role AS cashier_role
     FROM cashier_sessions cs
     JOIN users u ON u.id = cs.cashier_id
     WHERE cs.id = $1`,
    [sessionId]
  );
  if (!rows[0]) throw AppError.notFound('Session not found.');

  const session = rows[0];
  if (req.user.role !== 'admin' && session.cashier_id !== req.user.id) {
    throw AppError.forbidden('Access denied to this session.', 'INSUFFICIENT_OWNERSHIP');
  }
  return session;
};

// ─── POST /api/sessions  — open a new session ───────────────────────────────

const openSession = asyncHandler(async (req, res) => {
  // Cashiers open their own; admin may open on behalf of a cashier
  const cashierId = req.user.role === 'admin'
    ? parseInt(req.body.cashier_id, 10)
    : req.user.id;

  if (!cashierId) throw AppError.badRequest('cashier_id is required.', 'VALIDATION_ERROR');

  // Verify cashier exists and belongs to a store
  const { rows: userRows } = await db.query(
    `SELECT id, store_id, role FROM users WHERE id = $1 AND is_active = TRUE`,
    [cashierId]
  );
  if (!userRows[0]) throw AppError.notFound('Cashier not found.');
  if (userRows[0].role !== 'cashier') throw AppError.badRequest('Only cashier accounts can have sessions.', 'VALIDATION_ERROR');

  const storeId = userRows[0].store_id;

  // Fetch current register cash for the opening_cash snapshot
  const { rows: regRows } = await db.query(
    `SELECT cash_amount FROM store_register_state
     WHERE store_id = $1 ORDER BY id DESC LIMIT 1`,
    [storeId]
  );
  const openingCash = regRows[0]?.cash_amount ?? 0;

  const { rows } = await db.query(
    `INSERT INTO cashier_sessions (cashier_id, store_id, opening_cash)
     VALUES ($1, $2, $3)
     ON CONFLICT (cashier_id, session_date) DO NOTHING
     RETURNING *`,
    [cashierId, storeId, openingCash]
  );

  if (!rows[0]) {
    // Conflict — session already exists today
    const { rows: existing } = await db.query(
      `SELECT * FROM cashier_sessions
       WHERE cashier_id = $1 AND session_date = CURRENT_DATE`,
      [cashierId]
    );
    throw AppError.conflict(
      `A session already exists for this cashier today (id: ${existing[0]?.id}).`,
      'SESSION_ALREADY_EXISTS'
    );
  }

  audit({
    userId:    req.user.id,
    action:    'SESSION_OPEN',
    table:     'cashier_sessions',
    recordId:  rows[0].id,
    newValues: { cashier_id: cashierId, store_id: storeId, opening_cash: openingCash },
    ip:        req.clientIp,
  });

  sendCreated(res, rows[0], 'Session opened.');
});

// ─── GET /api/sessions  ──────────────────────────────────────────────────────
// Admin: all sessions (filterable). Cashier: own sessions only.

const listSessions = asyncHandler(async (req, res) => {
  const params = [];
  const conditions = [];

  if (req.user.role !== 'admin') {
    params.push(req.user.id);
    conditions.push(`cs.cashier_id = $${params.length}`);
  }

  if (req.query.date) {
    const date = parseDate(req.query.date, 'date');
    params.push(date);
    conditions.push(`cs.session_date = $${params.length}`);
  }

  if (req.query.store_id && req.user.role === 'admin') {
    const storeId = parseId(req.query.store_id, 'store_id');
    params.push(storeId);
    conditions.push(`cs.store_id = $${params.length}`);
  }

  if (req.query.status) {
    params.push(req.query.status);
    conditions.push(`cs.status = $${params.length}`);
  }

  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

  const { rows } = await db.query(
    `SELECT cs.id, cs.cashier_id, cs.store_id, cs.session_date,
            cs.status, cs.opening_cash, cs.closed_at, cs.created_at,
            u.full_name AS cashier_name, s.name AS store_name
     FROM cashier_sessions cs
     JOIN users  u ON u.id = cs.cashier_id
     JOIN stores s ON s.id = cs.store_id
     ${where}
     ORDER BY cs.session_date DESC, cs.created_at DESC`,
    params
  );
  sendSuccess(res, rows);
});

// ─── GET /api/sessions/:id  ──────────────────────────────────────────────────

const getSession = asyncHandler(async (req, res) => {
  const id      = parseId(req.params.id);
  const session = await resolveSession(id, req);
  sendSuccess(res, session);
});

// ─── GET /api/sessions/:id/totals  — live calculated totals ─────────────────

const getSessionTotals = asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);
  await resolveSession(id, req); // ownership check

  const { rows } = await db.withRLS(req.user.id, req.user.role, (client) =>
    client.query(
      'SELECT * FROM v_session_live_totals WHERE session_id = $1', [id]
    )
  );
  if (!rows[0]) throw AppError.notFound('Session totals not found.');
  sendSuccess(res, rows[0]);
});

// ─── GET /api/sessions/live  — all open sessions (admin dashboard) ──────────

const getLiveSessions = asyncHandler(async (req, res) => {
  // Admin only — returns live totals for all open sessions across both stores
  const params = [];
  let storeFilter = '';

  if (req.query.store_id) {
    const storeId = parseId(req.query.store_id, 'store_id');
    params.push(storeId);
    storeFilter = `AND cs.store_id = $${params.length}`;
  }

  const { rows } = await db.query(
    `SELECT t.*
     FROM v_session_live_totals t
     JOIN cashier_sessions cs ON cs.id = t.session_id
     WHERE cs.status = 'open' ${storeFilter}
     ORDER BY t.store_id, t.cashier_name`,
    params
  );
  sendSuccess(res, rows);
});

// ─── POST /api/sessions/:id/close  ──────────────────────────────────────────

const closeSession = asyncHandler(async (req, res) => {
  const id      = parseId(req.params.id);
  const session = await resolveSession(id, req);

  if (session.status === 'closed') {
    throw AppError.conflict('Session is already closed.', 'SESSION_ALREADY_CLOSED');
  }

  const { rows } = await db.query(
    `UPDATE cashier_sessions
     SET status = 'closed', closed_at = NOW()
     WHERE id = $1
     RETURNING *`,
    [id]
  );

  audit({
    userId:    req.user.id,
    action:    'SESSION_CLOSE',
    table:     'cashier_sessions',
    recordId:  id,
    ip:        req.clientIp,
  });

  sendSuccess(res, rows[0], 200, 'Session closed.');
});

// ─── POST /api/sessions/:id/stock-assign  (DEPRECATED) ──────────────────────
// Stock is now assigned per-cashier via POST /api/stock/assign — kept here as
// a stub returning 410 Gone so existing clients fail fast with a clear message.

const assignStock = asyncHandler(async (req, res) => {
  throw AppError.unprocessable(
    'Stock is now assigned per cashier (not per session). Use POST /api/stock/assign.',
    'STOCK_ASSIGNMENT_MOVED'
  );
});

// ─── GET /api/sessions/:id/stock  — cashier inventory for the session owner ─

const getSessionStock = asyncHandler(async (req, res) => {
  const id      = parseId(req.params.id);
  const session = await resolveSession(id, req);

  const { rows } = await db.query(
    `SELECT * FROM v_cashier_sim_inventory WHERE cashier_id = $1`,
    [session.cashier_id]
  );

  const r = rows[0];
  if (!r) {
    return sendSuccess(res, {
      available_count: 0,
      sold_count:      0,
      next_serial:     null,
      last_serial:     null,
      is_low_stock:    true,
    });
  }

  sendSuccess(res, {
    available_count: parseInt(r.available_count, 10),
    sold_count:      parseInt(r.sold_count, 10),
    voided_count:    parseInt(r.voided_count, 10),
    next_serial:     r.next_serial,
    last_serial:     r.last_serial,
    is_low_stock:    r.is_low_stock,
  });
});

module.exports = {
  openSession, listSessions, getSession,
  getSessionTotals, getLiveSessions,
  closeSession, assignStock, getSessionStock,
};
